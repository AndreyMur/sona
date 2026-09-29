from __future__ import annotations

import json
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import benchmark  # noqa: E402

DATASET = Path(__file__).resolve().parents[1] / "data" / "test_phrases.json"


def test_dataset_has_50_phrases() -> None:
    data = json.loads(DATASET.read_text(encoding="utf-8"))
    phrases = data["phrases"]
    assert len(phrases) == 50
    ids = [p["id"] for p in phrases]
    assert len(set(ids)) == 50
    for phrase in phrases:
        assert phrase["expected"], phrase["id"]
        assert phrase["text"]


def test_wer() -> None:
    assert benchmark.wer("такси 400", "такси 400") == 0.0
    assert benchmark.wer("такси 400", "такси 500") == 1 / 2
    assert benchmark.wer("", "") == 0.0


def test_perfect_predictions_score_full() -> None:
    data = json.loads(DATASET.read_text(encoding="utf-8"))
    today = date.today()
    for phrase in data["phrases"]:
        predicted = benchmark.expected_operations(phrase, today)
        assert benchmark.evaluate(phrase, predicted, today).exact, phrase["id"]


def test_missing_operation_fails_exact() -> None:
    data = json.loads(DATASET.read_text(encoding="utf-8"))
    phrase = next(p for p in data["phrases"] if p["id"] == "p49")
    today = date.today()
    predicted = benchmark.expected_operations(phrase, today)[:1]
    result = benchmark.evaluate(phrase, predicted, today)
    assert result.exact is False
    assert result.matched == 1
