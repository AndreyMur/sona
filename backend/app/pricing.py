from __future__ import annotations

from typing import Any


def stt_cost_usd(model: str, duration_seconds: float, pricing: dict[str, Any]) -> float:
    table = pricing.get("stt", {})
    entry = table.get(model)
    if not entry:
        return 0.0
    minutes = max(duration_seconds, 0.0) / 60.0
    return round(minutes * float(entry.get("price_usd", 0.0)), 6)


def nlu_cost_usd(
    model: str,
    prompt_tokens: int,
    completion_tokens: int,
    pricing: dict[str, Any],
) -> float:
    table = pricing.get("nlu", {})
    entry = table.get(model)
    if not entry:
        return 0.0
    cost = (prompt_tokens / 1_000_000) * float(entry.get("input_per_1m", 0.0))
    cost += (completion_tokens / 1_000_000) * float(entry.get("output_per_1m", 0.0))
    return round(cost, 6)


def estimate_tokens(text: str) -> int:
    if not text:
        return 0
    return max(1, len(text) // 4)
