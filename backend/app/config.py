from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    app_name: str = "sona-odirouter-proxy"
    environment: str = "production"

    odirouter_base_url: str = "https://api.odirouter.ai/v1"
    odirouter_api_key: str = ""

    stt_model_standard: str = "openai/gpt-4o-mini-transcribe"
    stt_model_pro: str = "openai/gpt-4o-transcribe"
    stt_model_fallback: str = "openai/whisper-large-v3"

    nlu_model_primary: str = "google/gemini-3.8-flash"
    nlu_model_fallback: str = "openai/gpt-4o"
    nlu_confidence_threshold: float = 0.7

    data_dir: Path = Path("data")
    admin_token: str = ""

    request_timeout_seconds: float = 60.0
    max_retries: int = 3
    retry_backoff_seconds: float = 0.5

    rate_limit_per_minute: int = 30
    rate_limit_per_day: int = 300

    free_monthly_operations: int = 30
    monthly_cost_limit_usd: float = 2.0

    max_audio_bytes: int = 10 * 1024 * 1024
    log_level: str = "INFO"
    trust_proxy_headers: bool = True

    @property
    def config_path(self) -> Path:
        return self.data_dir / "config.json"

    @property
    def db_path(self) -> Path:
        return self.data_dir / "sona.db"


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    return settings
