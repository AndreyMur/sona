from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from datetime import date
from typing import Any

from .default_config import render_system_prompt
from .odirouter import OdiRouterClient, OdiRouterError
from .pricing import estimate_tokens, nlu_cost_usd
from .schemas import Operation

logger = logging.getLogger("sona.nlu")

OPERATIONS_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "operations": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "type": {"type": "string", "enum": ["expense", "income"]},
                    "amount": {"type": "number"},
                    "category": {"type": "string"},
                    "subcategory": {"type": ["string", "null"]},
                    "date": {"type": "string"},
                    "confidence": {"type": "number"},
                },
                "required": [
                    "type",
                    "amount",
                    "category",
                    "subcategory",
                    "date",
                    "confidence",
                ],
                "additionalProperties": False,
            },
        },
        "overall_confidence": {"type": "number"},
    },
    "required": ["operations", "overall_confidence"],
    "additionalProperties": False,
}


@dataclass
class ParseResult:
    operations: list[Operation] = field(default_factory=list)
    overall_confidence: float = 0.0
    model: str = ""
    fallback_used: bool = False
    prompt_version: str = ""
    prompt_tokens: int = 0
    completion_tokens: int = 0
    cost_usd: float = 0.0


def _loads_json(content: str | None) -> dict[str, Any]:
    if not content:
        raise ValueError("empty content")
    text = content.strip()
    if text.startswith("```"):
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:]
        text = text.strip()
    return json.loads(text)


def _validate(payload: dict[str, Any]) -> tuple[list[Operation], float]:
    operations: list[Operation] = []
    for item in payload.get("operations") or []:
        try:
            operations.append(Operation.model_validate(item))
        except Exception:  # noqa: BLE001 - skip malformed operation
            logger.warning("Dropping malformed operation: %s", item)
    confidence = payload.get("overall_confidence")
    if confidence is None:
        confidence = (
            sum(op.confidence for op in operations) / len(operations) if operations else 0.0
        )
    return operations, float(confidence)


class NluService:
    def __init__(self, client: OdiRouterClient) -> None:
        self._client = client

    async def _run_model(
        self, model: str, system_prompt: str, text: str, today: str
    ) -> tuple[list[Operation], float, dict[str, Any]]:
        messages = [
            {"role": "system", "content": render_system_prompt(today)},
            {"role": "user", "content": text},
        ]
        result = await self._client.chat_json(
            model=model, messages=messages, schema=OPERATIONS_SCHEMA
        )
        payload = _loads_json(result.get("content"))
        operations, confidence = _validate(payload)
        return operations, confidence, result.get("usage", {}) or {}

    async def parse(self, text: str, config: dict[str, Any]) -> ParseResult:
        models = config.get("models", {})
        pricing = config.get("pricing", {})
        primary = models.get("nlu_primary", "google/gemini-3.8-flash")
        fallback = models.get("nlu_fallback", "openai/gpt-4o")
        threshold = float(models.get("nlu_confidence_threshold", 0.7))
        prompt_version = str(config.get("prompt_version", "1.0.0"))
        today = date.today().isoformat()

        result = ParseResult(model=primary, prompt_version=prompt_version)
        used_model = primary
        try:
            operations, confidence, usage = await self._run_model(
                primary, config.get("system_prompt", ""), text, today
            )
        except (OdiRouterError, ValueError, json.JSONDecodeError) as exc:
            logger.warning("Primary NLU model %s failed: %s; trying fallback", primary, exc)
            operations, confidence, usage = await self._run_model(
                fallback, config.get("system_prompt", ""), text, today
            )
            used_model = fallback
            result.fallback_used = True
        else:
            if confidence < threshold:
                logger.info(
                    "Confidence %.2f < %.2f; falling back to %s",
                    confidence,
                    threshold,
                    fallback,
                )
                try:
                    operations, confidence, usage = await self._run_model(
                        fallback, config.get("system_prompt", ""), text, today
                    )
                    used_model = fallback
                    result.fallback_used = True
                except (OdiRouterError, ValueError, json.JSONDecodeError) as exc:
                    logger.warning("Fallback NLU model failed, keeping primary: %s", exc)

        prompt_tokens = int(usage.get("prompt_tokens") or estimate_tokens(text))
        completion_tokens = int(
            usage.get("completion_tokens")
            or estimate_tokens(json.dumps([op.model_dump(mode="json") for op in operations]))
        )
        result.operations = operations
        result.overall_confidence = confidence
        result.model = used_model
        result.prompt_tokens = prompt_tokens
        result.completion_tokens = completion_tokens
        result.cost_usd = nlu_cost_usd(
            used_model, prompt_tokens, completion_tokens, pricing
        )
        return result
