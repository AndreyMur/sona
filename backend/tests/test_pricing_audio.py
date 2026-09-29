from __future__ import annotations

import struct

from app.audio import mp4_duration_seconds, resolve_duration
from app.pricing import estimate_tokens, nlu_cost_usd, stt_cost_usd

PRICING = {
    "stt": {
        "openai/gpt-4o-mini-transcribe": {"unit": "minute", "price_usd": 0.003},
        "openai/gpt-4o-transcribe": {"unit": "minute", "price_usd": 0.006},
    },
    "nlu": {
        "google/gemini-3.8-flash": {"input_per_1m": 0.75, "output_per_1m": 3.0},
    },
}


def _box(box_type: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", 8 + len(payload)) + box_type + payload


def _mvhd(timescale: int, duration: int) -> bytes:
    payload = b"\x00\x00\x00\x00" + b"\x00" * 8
    payload += struct.pack(">I", timescale) + struct.pack(">I", duration)
    return _box(b"mvhd", payload)


def _mp4(seconds: float) -> bytes:
    timescale = 1000
    ftyp = _box(b"ftyp", b"mp42" + b"\x00" * 4)
    moov = _box(b"moov", _mvhd(timescale, int(seconds * timescale)))
    return ftyp + moov


def test_mp4_duration() -> None:
    assert mp4_duration_seconds(_mp4(12.5)) == 12.5


def test_mp4_duration_invalid() -> None:
    assert mp4_duration_seconds(b"not an mp4") is None


def test_resolve_duration_prefers_provided() -> None:
    assert resolve_duration(_mp4(5), 10.0) == 10.0
    assert resolve_duration(_mp4(5), None) == 5.0
    assert resolve_duration(b"junk", None) == 0.0


def test_stt_cost() -> None:
    assert stt_cost_usd("openai/gpt-4o-mini-transcribe", 60, PRICING) == 0.003
    assert stt_cost_usd("openai/gpt-4o-transcribe", 30, PRICING) == 0.003
    assert stt_cost_usd("unknown", 60, PRICING) == 0.0


def test_nlu_cost() -> None:
    cost = nlu_cost_usd("google/gemini-3.8-flash", 1_000_000, 1_000_000, PRICING)
    assert cost == 3.75


def test_estimate_tokens() -> None:
    assert estimate_tokens("") == 0
    assert estimate_tokens("abcd" * 10) == 10
