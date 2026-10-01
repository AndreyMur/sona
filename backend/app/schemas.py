from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


class RegisterResponse(BaseModel):
    device_id: str
    device_token: str
    tier: Literal["free", "pro"]
    created_at: datetime


class DeviceInfo(BaseModel):
    device_id: str
    tier: Literal["free", "pro"]
    created_at: datetime
    last_seen_at: datetime | None = None
    operations_this_month: int
    cost_this_month_usd: float
    free_monthly_operations: int
    monthly_cost_limit_usd: float


class Operation(BaseModel):
    type: Literal["expense", "income"]
    amount: float
    category: str
    subcategory: str | None = None
    date: date
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)


class TranscriptionResponse(BaseModel):
    request_id: str
    text: str
    model: str
    fallback_used: bool
    duration_seconds: float
    latency_ms: int
    cost_usd: float


class ParseResponse(BaseModel):
    request_id: str
    operations: list[Operation]
    overall_confidence: float
    model: str
    fallback_used: bool
    prompt_version: str
    latency_ms: int
    cost_usd: float


class ParseRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    request_id: str | None = None


class SubscriptionRequest(BaseModel):
    plan: Literal["monthly", "annual"] = "monthly"
    platform: str | None = None
    purchase_token: str | None = None
    trial: bool = False
    expires_at: datetime | None = None


class SubscriptionResponse(BaseModel):
    device_id: str
    tier: Literal["free", "pro"]
    plan: str | None = None
    status: str
    trial: bool = False
    expires_at: datetime | None = None


class ConfigResponse(BaseModel):
    prompt_version: str
    system_prompt: str
    categories: dict[str, list[str]]
    models: dict[str, Any]
    limits: dict[str, Any]


class AdminConfigUpdate(BaseModel):
    system_prompt: str | None = None
    models: dict[str, Any] | None = None
    limits: dict[str, Any] | None = None
    categories: dict[str, list[str]] | None = None


class ErrorResponse(BaseModel):
    error: str
    message: str
    request_id: str | None = None
