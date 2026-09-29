from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from .odirouter import OdiRouterClient, OdiRouterError
from .pricing import stt_cost_usd

logger = logging.getLogger("sona.stt")


@dataclass
class TranscriptionResult:
    text: str = ""
    model: str = ""
    fallback_used: bool = False
    duration_seconds: float = 0.0
    cost_usd: float = 0.0


class SttService:
    def __init__(self, client: OdiRouterClient) -> None:
        self._client = client

    def select_model(self, config: dict[str, Any], quality: str, tier: str) -> str:
        models = config.get("models", {})
        if quality == "max" and tier == "pro":
            return models.get("stt_pro", "openai/gpt-4o-transcribe")
        return models.get("stt_standard", "openai/gpt-4o-mini-transcribe")

    async def transcribe(
        self,
        *,
        content: bytes,
        filename: str,
        content_type: str,
        duration_seconds: float,
        config: dict[str, Any],
        quality: str = "standard",
        tier: str = "free",
        language: str = "ru",
    ) -> TranscriptionResult:
        models = config.get("models", {})
        pricing = config.get("pricing", {})
        primary = self.select_model(config, quality, tier)
        fallback = models.get("stt_fallback", "openai/whisper-large-v3")

        result = TranscriptionResult(model=primary, duration_seconds=duration_seconds)
        try:
            payload = await self._client.transcribe(
                content=content,
                filename=filename,
                content_type=content_type,
                model=primary,
                language=language,
            )
        except OdiRouterError as exc:
            logger.warning("Primary STT model %s failed: %s; trying fallback", primary, exc)
            payload = await self._client.transcribe(
                content=content,
                filename=filename,
                content_type=content_type,
                model=fallback,
                language=language,
            )
            result.model = fallback
            result.fallback_used = True

        result.text = payload.get("text", "")
        result.cost_usd = stt_cost_usd(result.model, duration_seconds, pricing)
        return result
