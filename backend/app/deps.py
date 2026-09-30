from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import Header, Request

from .config import Settings
from .config_store import ConfigStore
from .errors import ApiError
from .nlu import NluService
from .odirouter import OdiRouterClient
from .security import extract_bearer, hash_token
from .storage import Database, month_start
from .stt import SttService

logger = logging.getLogger("sona.request")


def get_settings(request: Request) -> Settings:
    return request.app.state.settings


def get_db(request: Request) -> Database:
    return request.app.state.db


def get_config_store(request: Request) -> ConfigStore:
    return request.app.state.config_store


def get_odirouter(request: Request) -> OdiRouterClient:
    return request.app.state.odirouter


def get_stt(request: Request) -> SttService:
    return request.app.state.stt


def get_nlu(request: Request) -> NluService:
    return request.app.state.nlu


def effective_limits(settings: Settings, config: dict[str, Any]) -> dict[str, float]:
    limits = config.get("limits", {}) if isinstance(config, dict) else {}
    return {
        "rate_limit_per_minute": limits.get(
            "rate_limit_per_minute", settings.rate_limit_per_minute
        ),
        "rate_limit_per_day": limits.get("rate_limit_per_day", settings.rate_limit_per_day),
        "free_monthly_operations": limits.get(
            "free_monthly_operations", settings.free_monthly_operations
        ),
        "monthly_cost_limit_usd": limits.get(
            "monthly_cost_limit_usd", settings.monthly_cost_limit_usd
        ),
    }


async def authenticate(
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    token = extract_bearer(authorization)
    if not token:
        raise ApiError(401, "unauthorized", "Missing device token")
    db = get_db(request)
    device = await db.get_device_by_token_hash(hash_token(token))
    if not device:
        raise ApiError(401, "unauthorized", "Unknown or revoked device token")
    await db.touch_device(device["id"])
    return device


async def check_rate_limit(
    request: Request, device: dict[str, Any], config: dict[str, Any]
) -> None:
    db = get_db(request)
    limits = effective_limits(get_settings(request), config)
    now = datetime.now(UTC)
    per_minute = int(limits["rate_limit_per_minute"])
    per_day = int(limits["rate_limit_per_day"])

    minute_count = await db.count_requests_since(device["id"], now - timedelta(minutes=1))
    if minute_count >= per_minute:
        raise ApiError(
            429,
            "rate_limited",
            "Too many requests per minute",
            headers={"Retry-After": "60"},
        )
    day_count = await db.count_requests_since(device["id"], now - timedelta(days=1))
    if day_count >= per_day:
        raise ApiError(
            429,
            "rate_limited",
            "Daily request limit reached",
            headers={"Retry-After": "3600"},
        )


async def check_quota(
    request: Request, device: dict[str, Any], config: dict[str, Any]
) -> None:
    db = get_db(request)
    limits = effective_limits(get_settings(request), config)
    start = month_start()

    if device.get("tier") != "pro":
        ops = await db.count_billable_ops_since(device["id"], start)
        if ops >= int(limits["free_monthly_operations"]):
            raise ApiError(
                402,
                "free_limit_reached",
                "Free monthly operation limit reached. Upgrade to Sona Pro.",
            )

    cost = await db.sum_cost_since(device["id"], start)
    if cost >= float(limits["monthly_cost_limit_usd"]):
        raise ApiError(
            402,
            "cost_limit_reached",
            "Monthly AI cost limit reached for this device.",
        )


async def record_request(
    request: Request,
    *,
    device_id: str,
    endpoint: str,
    status: str,
    model: str | None = None,
    latency_ms: int = 0,
    cost_usd: float = 0.0,
    detail: str | None = None,
    fallback_used: bool = False,
) -> None:
    db = get_db(request)
    await db.log_request(
        device_id=device_id,
        endpoint=endpoint,
        status=status,
        model=model,
        latency_ms=latency_ms,
        cost_usd=cost_usd,
        detail=detail,
    )
    logger.info(
        "request",
        extra={
            "request_id": getattr(request.state, "request_id", None),
            "device_id": device_id,
            "endpoint": endpoint,
            "model": model,
            "latency_ms": latency_ms,
            "cost_usd": cost_usd,
            "status": status,
            "fallback_used": fallback_used,
        },
    )
