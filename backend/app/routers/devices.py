from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Request

from ..deps import authenticate, effective_limits, get_config_store, get_db, get_settings
from ..schemas import DeviceInfo, RegisterResponse
from ..security import generate_device_token, hash_token
from ..storage import month_start

router = APIRouter(tags=["devices"])


@router.post("/v1/devices/register", response_model=RegisterResponse)
async def register_device(request: Request) -> RegisterResponse:
    db = get_db(request)
    token = generate_device_token()
    device = await db.create_device(hash_token(token), tier="free")
    return RegisterResponse(
        device_id=device["id"],
        device_token=token,
        tier=device["tier"],
        created_at=datetime.fromisoformat(device["created_at"]),
    )


@router.get("/v1/me", response_model=DeviceInfo)
async def me(request: Request, device: dict = Depends(authenticate)) -> DeviceInfo:
    db = get_db(request)
    settings = get_settings(request)
    config = get_config_store(request).get()
    limits = effective_limits(settings, config)
    start = month_start()
    ops = await db.count_billable_ops_since(device["id"], start)
    cost = await db.sum_cost_since(device["id"], start)
    last_seen = device.get("last_seen_at")
    return DeviceInfo(
        device_id=device["id"],
        tier=device["tier"],
        created_at=datetime.fromisoformat(device["created_at"]),
        last_seen_at=datetime.fromisoformat(last_seen) if last_seen else None,
        operations_this_month=ops,
        cost_this_month_usd=round(cost, 6),
        free_monthly_operations=int(limits["free_monthly_operations"]),
        monthly_cost_limit_usd=float(limits["monthly_cost_limit_usd"]),
    )
