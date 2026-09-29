from __future__ import annotations

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.conftest import MockRouter, auth


def _audio() -> tuple[str, bytes, str]:
    return ("note.m4a", b"\x00\x00\x00\x18ftypmp42fake-audio-bytes", "audio/m4a")


def test_transcribe_standard(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    response = client.post(
        "/v1/audio/transcriptions",
        files={"file": _audio()},
        data={"duration_seconds": "12.5", "quality": "standard"},
        headers=auth(device_token),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["text"] == "такси 400"
    assert body["model"] == "openai/gpt-4o-mini-transcribe"
    assert body["fallback_used"] is False
    assert body["duration_seconds"] == 12.5
    assert body["cost_usd"] > 0


def test_transcribe_pro_quality(client: TestClient, device_token: str) -> None:
    me = client.get("/v1/me", headers=auth(device_token)).json()
    tier_response = client.post(
        f"/v1/admin/devices/{me['device_id']}/tier",
        json={"tier": "pro"},
        headers={"X-Admin-Token": "admin-secret"},
    )
    assert tier_response.status_code == 200, tier_response.text

    response = client.post(
        "/v1/audio/transcriptions",
        files={"file": _audio()},
        data={"duration_seconds": "10", "quality": "max"},
        headers=auth(device_token),
    )
    assert response.status_code == 200, response.text
    assert response.json()["model"] == "openai/gpt-4o-transcribe"


def test_transcribe_retries_same_model(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    mock_router.transcribe_fail_first = 1
    response = client.post(
        "/v1/audio/transcriptions",
        files={"file": _audio()},
        data={"duration_seconds": "10"},
        headers=auth(device_token),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["fallback_used"] is False
    assert body["model"] == "openai/gpt-4o-mini-transcribe"


def test_transcribe_model_fallback(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    mock_router.fail_transcribe_models = {"openai/gpt-4o-mini-transcribe"}
    response = client.post(
        "/v1/audio/transcriptions",
        files={"file": _audio()},
        data={"duration_seconds": "10"},
        headers=auth(device_token),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["fallback_used"] is True
    assert body["model"] == "openai/whisper-large-v3"


def test_reject_unsupported_format(client: TestClient, device_token: str) -> None:
    response = client.post(
        "/v1/audio/transcriptions",
        files={"file": ("note.txt", b"hello", "text/plain")},
        headers=auth(device_token),
    )
    assert response.status_code == 415


def test_reject_empty_audio(client: TestClient, device_token: str) -> None:
    response = client.post(
        "/v1/audio/transcriptions",
        files={"file": ("note.m4a", b"", "audio/m4a")},
        headers=auth(device_token),
    )
    assert response.status_code == 400


def test_audio_too_large(tmp_path) -> None:
    settings = Settings(data_dir=tmp_path / "data", max_audio_bytes=4, admin_token="x")
    app = create_app(settings)
    with TestClient(app) as c:
        token = c.post("/v1/devices/register").json()["device_token"]
        response = c.post(
            "/v1/audio/transcriptions",
            files={"file": _audio()},
            headers=auth(token),
        )
        assert response.status_code == 413
