from __future__ import annotations

import copy
import json
import threading
from pathlib import Path
from typing import Any

from .default_config import default_config


def _bump_version(version: str) -> str:
    parts = version.split(".")
    try:
        numbers = [int(p) for p in parts]
    except ValueError:
        return version + ".1"
    numbers[-1] += 1
    return ".".join(str(n) for n in numbers)


def _deep_merge(base: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(base)
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = _deep_merge(result[key], value)
        else:
            result[key] = value
    return result


class ConfigStore:
    """Versioned remote config persisted to a JSON file.

    The system prompt and model/limit settings live here so they can be
    updated without shipping a new app release.
    """

    def __init__(self, path: Path) -> None:
        self._path = path
        self._lock = threading.Lock()
        self._config: dict[str, Any] = {}
        self._load()

    def _load(self) -> None:
        with self._lock:
            if self._path.exists():
                self._config = json.loads(self._path.read_text(encoding="utf-8"))
            else:
                self._config = default_config()
                self._persist()
        # backfill any missing keys introduced by newer versions
        merged = _deep_merge(default_config(), self._config)
        if merged != self._config:
            with self._lock:
                self._config = merged
                self._persist()

    def _persist(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self._path.with_suffix(".tmp")
        tmp.write_text(
            json.dumps(self._config, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        tmp.replace(self._path)

    def get(self) -> dict[str, Any]:
        with self._lock:
            return copy.deepcopy(self._config)

    def update(self, patch: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            clean = {k: v for k, v in patch.items() if v is not None}
            self._config = _deep_merge(self._config, clean)
            self._config["prompt_version"] = _bump_version(
                str(self._config.get("prompt_version", "1.0.0"))
            )
            self._persist()
            return copy.deepcopy(self._config)
