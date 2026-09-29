#!/usr/bin/env python
"""Run the 50-phrase Sona benchmark against the proxy or directly against OdiRouter.

Metrics: STT WER, NLU categorization accuracy, mean latency, mean cost.

Examples:
    python scripts/benchmark.py --mode proxy --base-url https://aidailyplanner.ru
    python scripts/benchmark.py --mode direct --nlu-primary google/gemini-3.8-flash
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import statistics
import sys
import time
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx  # noqa: E402

from app.default_config import default_config  # noqa: E402
from app.nlu import NluService  # noqa: E402
from app.odirouter import OdiRouterClient  # noqa: E402
from app.stt import SttService  # noqa: E402

PUNCT = ".,!?;:\"'«»()—–-"


def normalize(text: str) -> str:
    for ch in PUNCT:
        text = text.replace(ch, " ")
    return " ".join(text.lower().split())


def wer(reference: str, hypothesis: str) -> float:
    ref = normalize(reference).split()
    hyp = normalize(hypothesis).split()
    if not ref:
        return 0.0 if not hyp else 1.0
    previous = list(range(len(hyp) + 1))
    for i, ref_word in enumerate(ref, start=1):
        current = [i]
        for j, hyp_word in enumerate(hyp, start=1):
            cost = 0 if ref_word == hyp_word else 1
            current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost))
        previous = current
    return previous[-1] / len(ref)


@dataclass
class PhraseEval:
    matched: int = 0
    category_correct: int = 0
    subcategory_correct: int = 0
    date_correct: int = 0
    exact: bool = False


@dataclass
class Report:
    mode: str
    model: str = ""
    phrases: int = 0
    expected_ops: int = 0
    predicted_ops: int = 0
    matched: int = 0
    category_correct: int = 0
    subcategory_correct: int = 0
    date_correct: int = 0
    exact_phrases: int = 0
    latencies_ms: list[int] = field(default_factory=list)
    costs_usd: list[float] = field(default_factory=list)
    fallbacks: int = 0
    stt_wer: list[float] = field(default_factory=list)
    stt_latencies_ms: list[int] = field(default_factory=list)
    stt_costs_usd: list[float] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    def metrics(self) -> dict[str, Any]:
        lat = self.latencies_ms
        return {
            "mode": self.mode,
            "model": self.model,
            "phrases": self.phrases,
            "expected_operations": self.expected_ops,
            "predicted_operations": self.predicted_ops,
            "matched_operations": self.matched,
            "precision": round(self.matched / self.predicted_ops, 4)
            if self.predicted_ops
            else 0.0,
            "recall": round(self.matched / self.expected_ops, 4) if self.expected_ops else 0.0,
            "category_accuracy": round(self.category_correct / self.expected_ops, 4)
            if self.expected_ops
            else 0.0,
            "subcategory_accuracy": round(self.subcategory_correct / self.expected_ops, 4)
            if self.expected_ops
            else 0.0,
            "date_accuracy": round(self.date_correct / self.expected_ops, 4)
            if self.expected_ops
            else 0.0,
            "exact_match_rate": round(self.exact_phrases / self.phrases, 4)
            if self.phrases
            else 0.0,
            "fallback_rate": round(self.fallbacks / self.phrases, 4) if self.phrases else 0.0,
            "latency_ms_mean": round(statistics.mean(lat), 1) if lat else None,
            "latency_ms_median": round(statistics.median(lat), 1) if lat else None,
            "latency_ms_p95": round(_percentile(lat, 95), 1) if lat else None,
            "cost_usd_total": round(sum(self.costs_usd), 6),
            "cost_usd_mean": round(statistics.mean(self.costs_usd), 6) if self.costs_usd else None,
            "stt_wer_mean": round(statistics.mean(self.stt_wer), 4) if self.stt_wer else None,
            "stt_phrases": len(self.stt_wer),
            "stt_latency_ms_mean": round(statistics.mean(self.stt_latencies_ms), 1)
            if self.stt_latencies_ms
            else None,
            "stt_cost_usd_mean": round(statistics.mean(self.stt_costs_usd), 6)
            if self.stt_costs_usd
            else None,
            "errors": self.errors,
        }


def _percentile(values: list[int], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, int(round((pct / 100) * (len(ordered) - 1))))
    return float(ordered[index])


def expected_operations(phrase: dict, today: date) -> list[dict[str, Any]]:
    ops = []
    for item in phrase["expected"]:
        op = dict(item)
        op["date"] = (today + timedelta(days=int(item.get("date_offset", 0)))).isoformat()
        ops.append(op)
    return ops


def evaluate(phrase: dict, predicted: list[dict], today: date) -> PhraseEval:
    expected = expected_operations(phrase, today)
    used = [False] * len(predicted)
    result = PhraseEval()
    for exp in expected:
        best = -1
        for i, pred in enumerate(predicted):
            if used[i]:
                continue
            if pred.get("type") != exp["type"]:
                continue
            if abs(float(pred.get("amount", -1)) - float(exp["amount"])) > 0.01:
                continue
            best = i
            break
        if best < 0:
            continue
        used[best] = True
        pred = predicted[best]
        result.matched += 1
        if pred.get("category") == exp["category"]:
            result.category_correct += 1
        if (pred.get("subcategory") or None) == (exp.get("subcategory") or None):
            result.subcategory_correct += 1
        if pred.get("date") == exp["date"]:
            result.date_correct += 1
    result.exact = (
        result.matched == len(expected)
        and len(predicted) == len(expected)
        and result.category_correct == len(expected)
        and result.subcategory_correct == len(expected)
        and result.date_correct == len(expected)
    )
    return result


def _accumulate(report: Report, phrase: dict, predicted: list[dict], today: date) -> None:
    ev = evaluate(phrase, predicted, today)
    report.expected_ops += len(phrase["expected"])
    report.predicted_ops += len(predicted)
    report.matched += ev.matched
    report.category_correct += ev.category_correct
    report.subcategory_correct += ev.subcategory_correct
    report.date_correct += ev.date_correct
    report.exact_phrases += 1 if ev.exact else 0


async def run_direct(phrases: list[dict], args: argparse.Namespace, report: Report) -> None:
    config = default_config()
    if args.nlu_primary:
        config["models"]["nlu_primary"] = args.nlu_primary
    if args.nlu_fallback:
        config["models"]["nlu_fallback"] = args.nlu_fallback
    if args.stt_model:
        config["models"]["stt_standard"] = args.stt_model

    api_key = args.api_key or os.environ.get("ODIRUTER_API_KEY", "")
    if not api_key:
        raise SystemExit("Direct mode requires --api-key or ODIRUTER_API_KEY")

    client = OdiRouterClient(
        base_url=args.odirouter_base_url,
        api_key=api_key,
        max_retries=args.retries,
    )
    nlu = NluService(client)
    stt = SttService(client)
    report.model = config["models"]["nlu_primary"]
    today = date.today()

    for phrase in phrases:
        started = time.perf_counter()
        try:
            result = await nlu.parse(phrase["text"], config)
        except Exception as exc:  # noqa: BLE001
            report.errors.append(f"{phrase['id']}: {exc}")
            continue
        report.latencies_ms.append(int((time.perf_counter() - started) * 1000))
        report.costs_usd.append(result.cost_usd)
        report.fallbacks += 1 if result.fallback_used else 0
        predicted = [op.model_dump(mode="json") for op in result.operations]
        _accumulate(report, phrase, predicted, today)

        audio = _audio_path(args.audio_dir, phrase["id"])
        if audio:
            content = audio.read_bytes()
            started = time.perf_counter()
            tr = await stt.transcribe(
                content=content,
                filename=audio.name,
                content_type="audio/m4a",
                duration_seconds=0.0,
                config=config,
            )
            report.stt_latencies_ms.append(int((time.perf_counter() - started) * 1000))
            report.stt_costs_usd.append(tr.cost_usd)
            report.stt_wer.append(wer(phrase.get("reference_text", phrase["text"]), tr.text))

    await client.aclose()


def run_proxy(phrases: list[dict], args: argparse.Namespace, report: Report) -> None:
    base_url = args.base_url.rstrip("/")
    with httpx.Client(base_url=base_url, timeout=args.timeout) as client:
        token = args.token
        if not token:
            response = client.post("/v1/devices/register")
            response.raise_for_status()
            token = response.json()["device_token"]
        headers = {"Authorization": f"Bearer {token}"}
        today = date.today()

        for phrase in phrases:
            started = time.perf_counter()
            response = client.post(
                "/v1/parse", json={"text": phrase["text"]}, headers=headers
            )
            latency = int((time.perf_counter() - started) * 1000)
            if response.status_code != 200:
                report.errors.append(f"{phrase['id']}: HTTP {response.status_code}")
                continue
            body = response.json()
            report.model = body.get("model", report.model)
            report.latencies_ms.append(latency)
            report.costs_usd.append(float(body.get("cost_usd", 0.0)))
            report.fallbacks += 1 if body.get("fallback_used") else 0
            _accumulate(report, phrase, body.get("operations", []), today)

            audio = _audio_path(args.audio_dir, phrase["id"])
            if audio:
                started = time.perf_counter()
                response = client.post(
                    "/v1/audio/transcriptions",
                    files={"file": (audio.name, audio.read_bytes(), "audio/m4a")},
                    data={"duration_seconds": "0", "quality": "standard"},
                    headers=headers,
                )
                report.stt_latencies_ms.append(int((time.perf_counter() - started) * 1000))
                if response.status_code == 200:
                    body = response.json()
                    report.stt_costs_usd.append(float(body.get("cost_usd", 0.0)))
                    report.stt_wer.append(
                        wer(phrase.get("reference_text", phrase["text"]), body.get("text", ""))
                    )


def _audio_path(audio_dir: str | None, phrase_id: str) -> Path | None:
    if not audio_dir:
        return None
    directory = Path(audio_dir)
    for ext in (".m4a", ".mp4", ".wav", ".mp3"):
        candidate = directory / f"{phrase_id}{ext}"
        if candidate.exists():
            return candidate
    return None


def write_report(report: Report, metrics: dict[str, Any], out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "metrics.json").write_text(
        json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    lines = [
        "# Sona benchmark report",
        "",
        f"- Mode: `{metrics['mode']}`",
        f"- NLU model: `{metrics['model']}`",
        f"- Phrases: {metrics['phrases']}",
        f"- Category accuracy: {metrics['category_accuracy']}",
        f"- Subcategory accuracy: {metrics['subcategory_accuracy']}",
        f"- Date accuracy: {metrics['date_accuracy']}",
        f"- Exact match rate: {metrics['exact_match_rate']}",
        f"- Precision / recall: {metrics['precision']} / {metrics['recall']}",
        f"- Mean latency: {metrics['latency_ms_mean']} ms "
        f"(median {metrics['latency_ms_median']}, p95 {metrics['latency_ms_p95']})",
        f"- Mean cost: ${metrics['cost_usd_mean']} (total ${metrics['cost_usd_total']})",
        f"- Fallback rate: {metrics['fallback_rate']}",
        "",
        "## STT",
        "",
        f"- Phrases with audio: {metrics['stt_phrases']}",
        f"- Mean WER: {metrics['stt_wer_mean']}",
        f"- Mean latency: {metrics['stt_latency_ms_mean']} ms",
        f"- Mean cost: ${metrics['stt_cost_usd_mean']}",
        "",
    ]
    if metrics["errors"]:
        lines.append("## Errors")
        lines.append("")
        lines.extend(f"- {err}" for err in metrics["errors"])
        lines.append("")
    report_path = out_dir / "report.md"
    report_path.write_text("\n".join(lines), encoding="utf-8")
    return report_path


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["proxy", "direct"], default="proxy")
    parser.add_argument("--base-url", default="http://localhost:8000")
    parser.add_argument("--odirouter-base-url", default="https://api.odirouter.ai/v1")
    parser.add_argument("--token", default=None, help="Device token (proxy mode)")
    parser.add_argument("--api-key", default=None, help="OdiRouter key (direct mode)")
    parser.add_argument("--nlu-primary", default=None)
    parser.add_argument("--nlu-fallback", default=None)
    parser.add_argument("--stt-model", default=None)
    parser.add_argument("--dataset", default="data/test_phrases.json")
    parser.add_argument("--audio-dir", default=None)
    parser.add_argument("--out", default="reports")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--timeout", type=float, default=60.0)
    parser.add_argument("--retries", type=int, default=3)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    dataset = json.loads(Path(args.dataset).read_text(encoding="utf-8"))
    phrases = dataset["phrases"]
    if args.limit:
        phrases = phrases[: args.limit]

    report = Report(mode=args.mode, phrases=len(phrases))
    if args.mode == "direct":
        asyncio.run(run_direct(phrases, args, report))
    else:
        run_proxy(phrases, args, report)

    metrics = report.metrics()
    path = write_report(report, metrics, Path(args.out))
    print(json.dumps(metrics, ensure_ascii=False, indent=2))
    print(f"\nReport written to {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
