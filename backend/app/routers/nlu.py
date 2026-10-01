from __future__ import annotations

import time

from fastapi import APIRouter, Depends, Request

from ..deps import (
    authenticate,
    check_quota,
    check_rate_limit,
    get_config_store,
    get_nlu,
    record_request,
)
from ..errors import ApiError
from ..odirouter import OdiRouterError
from ..schemas import ParseRequest, ParseResponse

router = APIRouter(tags=["nlu"])


@router.post("/v1/parse", response_model=ParseResponse)
async def parse(
    request: Request,
    body: ParseRequest,
    device: dict = Depends(authenticate),
) -> ParseResponse:
    config = get_config_store(request).get()
    await check_rate_limit(request, device, config)
    await check_quota(request, device, config)

    nlu = get_nlu(request)
    priority = device.get("tier") == "pro"
    started = time.perf_counter()
    try:
        result = await nlu.parse(body.text, config)
    except (OdiRouterError, ValueError) as exc:
        latency_ms = int((time.perf_counter() - started) * 1000)
        await record_request(
            request,
            device_id=device["id"],
            endpoint="/v1/parse",
            status="error",
            latency_ms=latency_ms,
            detail=str(exc),
            priority=priority,
        )
        raise ApiError(502, "upstream_error", "Text parsing service is unavailable") from exc

    latency_ms = int((time.perf_counter() - started) * 1000)
    await record_request(
        request,
        device_id=device["id"],
        endpoint="/v1/parse",
        status="ok",
        model=result.model,
        latency_ms=latency_ms,
        cost_usd=result.cost_usd,
        fallback_used=result.fallback_used,
        priority=priority,
    )
    return ParseResponse(
        request_id=getattr(request.state, "request_id", ""),
        operations=result.operations,
        overall_confidence=result.overall_confidence,
        model=result.model,
        fallback_used=result.fallback_used,
        prompt_version=result.prompt_version,
        latency_ms=latency_ms,
        cost_usd=result.cost_usd,
    )
