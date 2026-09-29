from __future__ import annotations

import json
import re
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.odirouter import OdiRouterClient

PRIMARY = "google/gemini-3.8-flash"
FALLBACK = "openai/gpt-4o"


def _form_field(request: httpx.Request, name: str) -> str | None:
    body = request.content.decode("latin-1")
    match = re.search(rf'name="{name}"\r\n\r\n([^\r\n]+)', body)
    return match.group(1) if match else None


def _chat_payload(content: dict, model: str) -> dict:
    return {
        "id": "chatcmpl-test",
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": json.dumps(content)},
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 120, "completion_tokens": 40},
    }


class MockRouter:
    def __init__(self) -> None:
        self.chat_calls: list[dict] = []
        self.transcribe_calls: list[httpx.Request] = []
        self.chat_by_model: dict[str, dict] = {
            PRIMARY: {
                "operations": [
                    {
                        "type": "expense",
                        "amount": 400,
                        "category": "Транспорт",
                        "subcategory": "Такси",
                        "date": "2026-09-29",
                        "confidence": 0.95,
                    }
                ],
                "overall_confidence": 0.95,
            },
            FALLBACK: {
                "operations": [
                    {
                        "type": "expense",
                        "amount": 400,
                        "category": "Транспорт",
                        "subcategory": "Такси",
                        "date": "2026-09-29",
                        "confidence": 0.99,
                    }
                ],
                "overall_confidence": 0.99,
            },
        }
        self.transcribe_response = {"text": "такси 400", "usage": {}}
        self.fail_primary_chat = False
        self.transcribe_fail_first = 0
        self.fail_transcribe_models: set[str] = set()
        self._transcribe_attempts = 0

    def __call__(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path.endswith("/chat/completions"):
            body = json.loads(request.content)
            model = body["model"]
            self.chat_calls.append(body)
            if self.fail_primary_chat and model == PRIMARY:
                return httpx.Response(503, json={"error": "unavailable"})
            payload = self.chat_by_model.get(model, self.chat_by_model[PRIMARY])
            return httpx.Response(200, json=_chat_payload(payload, model))
        if path.endswith("/audio/transcriptions"):
            self.transcribe_calls.append(request)
            self._transcribe_attempts += 1
            model = _form_field(request, "model")
            if model in self.fail_transcribe_models:
                return httpx.Response(503, json={"error": "unavailable"})
            if self._transcribe_attempts <= self.transcribe_fail_first:
                return httpx.Response(503, json={"error": "unavailable"})
            return httpx.Response(200, json=self.transcribe_response)
        return httpx.Response(404, json={"error": "not found"})


@pytest.fixture
def mock_router() -> MockRouter:
    return MockRouter()


@pytest.fixture
def client(tmp_path: Path, mock_router: MockRouter):
    settings = Settings(
        data_dir=tmp_path / "data",
        odirouter_api_key="test-key",
        admin_token="admin-secret",
        free_monthly_operations=30,
        monthly_cost_limit_usd=2.0,
    )
    transport = httpx.MockTransport(mock_router)
    http_client = httpx.AsyncClient(transport=transport)
    odirouter = OdiRouterClient(
        base_url="https://api.odirouter.ai/v1",
        api_key="test-key",
        client=http_client,
    )
    app = create_app(settings, odirouter)
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def device_token(client: TestClient) -> str:
    response = client.post("/v1/devices/register")
    assert response.status_code == 200, response.text
    return response.json()["device_token"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}
