from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, Request

from ..deps import authenticate, get_db, get_settings
from ..errors import ApiError
from ..schemas import SubscriptionRequest, SubscriptionResponse

router = APIRouter(tags=["subscription"])


def _period_days(settings, plan: str, trial: bool) -> int:
    if trial:
        return settings.subscription_trial_days
    if plan == "annual":
        return settings.subscription_annual_days
    return settings.subscription_monthly_days


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def _to_response(device: dict, subscription: dict) -> SubscriptionResponse:
    expires = subscription.get("expires_at")
    return SubscriptionResponse(
        device_id=device["id"],
        tier=device["tier"],
        plan=subscription.get("plan"),
        status=subscription.get("status", "active"),
        trial=bool(subscription.get("trial")),
        expires_at=datetime.fromisoformat(expires) if expires else None,
    )


@router.get("/v1/subscription", response_model=SubscriptionResponse)
async def get_subscription(
    request: Request, device: dict = Depends(authenticate)
) -> SubscriptionResponse:
    subscription = await get_db(request).get_subscription(device["id"])
    if subscription is None:
        return SubscriptionResponse(
            device_id=device["id"], tier=device["tier"], status="none"
        )
    return _to_response(device, subscription)


@router.post("/v1/subscription", response_model=SubscriptionResponse)
async def activate_subscription(
    request: Request,
    body: SubscriptionRequest,
    device: dict = Depends(authenticate),
) -> SubscriptionResponse:
    """Активирует Sona Pro после покупки или запуска пробного периода.

    В продакшене `purchase_token` должен проверяться в App Store / Google Play;
    при `subscription_auto_approve = false` запрос без токена отклоняется.
    """
    settings = get_settings(request)
    if not settings.subscription_auto_approve and not body.purchase_token:
        raise ApiError(402, "purchase_required", "Purchase verification is required")

    now = datetime.now(UTC)
    expires = (
        _as_utc(body.expires_at)
        if body.expires_at is not None
        else now + timedelta(days=_period_days(settings, body.plan, body.trial))
    )

    db = get_db(request)
    subscription = await db.upsert_subscription(
        device_id=device["id"],
        plan=body.plan,
        platform=body.platform,
        purchase_token=body.purchase_token,
        status="active",
        trial=body.trial,
        started_at=now,
        expires_at=expires,
    )
    await db.set_tier(device["id"], "pro")
    return _to_response({**device, "tier": "pro"}, subscription)


@router.delete("/v1/subscription", response_model=SubscriptionResponse)
async def cancel_subscription(
    request: Request, device: dict = Depends(authenticate)
) -> SubscriptionResponse:
    db = get_db(request)
    await db.clear_subscription(device["id"])
    await db.set_tier(device["id"], "free")
    return SubscriptionResponse(
        device_id=device["id"], tier="free", status="canceled"
    )
