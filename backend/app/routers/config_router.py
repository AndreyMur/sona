from __future__ import annotations

import hmac

from fastapi import APIRouter, Body, Depends, Header, Request

from ..deps import authenticate, get_config_store, get_db, get_settings
from ..errors import ApiError
from ..schemas import AdminConfigUpdate, ConfigResponse

router = APIRouter(tags=["config"])


@router.get("/v1/config", response_model=ConfigResponse)
async def get_config(
    request: Request, device: dict = Depends(authenticate)
) -> ConfigResponse:
    config = get_config_store(request).get()
    return ConfigResponse(
        prompt_version=str(config.get("prompt_version", "1.0.0")),
        system_prompt=str(config.get("system_prompt", "")),
        categories=config.get("categories", {}),
        models=config.get("models", {}),
        limits=config.get("limits", {}),
    )


def _require_admin(request: Request, token: str | None) -> None:
    expected = get_settings(request).admin_token
    if not expected:
        raise ApiError(403, "admin_disabled", "Admin API is disabled")
    if not token or not hmac.compare_digest(token, expected):
        raise ApiError(401, "unauthorized", "Invalid admin token")


@router.post("/v1/admin/config", response_model=ConfigResponse)
async def update_config(
    request: Request,
    patch: AdminConfigUpdate,
    x_admin_token: str | None = Header(default=None),
) -> ConfigResponse:
    _require_admin(request, x_admin_token)
    store = get_config_store(request)
    updated = store.update(patch.model_dump(exclude_none=True))
    return ConfigResponse(
        prompt_version=str(updated.get("prompt_version", "1.0.0")),
        system_prompt=str(updated.get("system_prompt", "")),
        categories=updated.get("categories", {}),
        models=updated.get("models", {}),
        limits=updated.get("limits", {}),
    )


@router.post("/v1/admin/devices/{device_id}/tier")
async def set_device_tier(
    request: Request,
    device_id: str,
    tier: str = Body(..., embed=True),
    x_admin_token: str | None = Header(default=None),
) -> dict[str, str]:
    _require_admin(request, x_admin_token)
    if tier not in ("free", "pro"):
        raise ApiError(400, "invalid_tier", "tier must be 'free' or 'pro'")
    await get_db(request).set_tier(device_id, tier)
    return {"device_id": device_id, "tier": tier}
