from __future__ import annotations

import time

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile

from ..audio import resolve_duration
from ..deps import (
    authenticate,
    check_quota,
    check_rate_limit,
    get_config_store,
    get_settings,
    get_stt,
    record_request,
)
from ..errors import ApiError
from ..odirouter import OdiRouterError
from ..schemas import TranscriptionResponse

router = APIRouter(tags=["stt"])

ALLOWED_EXTENSIONS = {".m4a", ".mp4", ".wav", ".mp3", ".ogg", ".oga", ".webm", ".flac"}


@router.post("/v1/audio/transcriptions", response_model=TranscriptionResponse)
async def transcribe(
    request: Request,
    file: UploadFile = File(...),
    quality: str = Form("standard"),
    language: str = Form("ru"),
    duration_seconds: float | None = Form(default=None),
    device: dict = Depends(authenticate),
) -> TranscriptionResponse:
    settings = get_settings(request)
    config = get_config_store(request).get()

    filename = file.filename or "audio.m4a"
    ext = ("." + filename.rsplit(".", 1)[-1].lower()) if "." in filename else ""
    if ext and ext not in ALLOWED_EXTENSIONS:
        raise ApiError(415, "unsupported_media", f"Unsupported audio format: {ext}")

    content = await file.read()
    if not content:
        raise ApiError(400, "empty_audio", "Audio file is empty")
    if len(content) > settings.max_audio_bytes:
        raise ApiError(413, "audio_too_large", "Audio file exceeds the size limit")

    await check_rate_limit(request, device, config)
    await check_quota(request, device, config)

    duration = resolve_duration(content, duration_seconds)
    stt = get_stt(request)
    started = time.perf_counter()
    try:
        result = await stt.transcribe(
            content=content,
            filename=filename,
            content_type=file.content_type or "audio/m4a",
            duration_seconds=duration,
            config=config,
            quality=quality,
            tier=device.get("tier", "free"),
            language=language,
        )
    except OdiRouterError as exc:
        latency_ms = int((time.perf_counter() - started) * 1000)
        await record_request(
            request,
            device_id=device["id"],
            endpoint="/v1/audio/transcriptions",
            status="error",
            latency_ms=latency_ms,
            detail=str(exc),
        )
        raise ApiError(502, "upstream_error", "Speech recognition service is unavailable") from exc

    latency_ms = int((time.perf_counter() - started) * 1000)
    await record_request(
        request,
        device_id=device["id"],
        endpoint="/v1/audio/transcriptions",
        status="ok",
        model=result.model,
        latency_ms=latency_ms,
        cost_usd=result.cost_usd,
        fallback_used=result.fallback_used,
    )
    return TranscriptionResponse(
        request_id=getattr(request.state, "request_id", ""),
        text=result.text,
        model=result.model,
        fallback_used=result.fallback_used,
        duration_seconds=result.duration_seconds,
        latency_ms=latency_ms,
        cost_usd=result.cost_usd,
    )
