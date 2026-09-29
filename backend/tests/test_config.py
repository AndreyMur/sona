from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth


def test_get_config(client: TestClient, device_token: str) -> None:
    response = client.get("/v1/config", headers=auth(device_token))
    assert response.status_code == 200
    body = response.json()
    assert body["prompt_version"] == "1.0.0"
    assert "Продукты" in body["categories"]
    assert body["models"]["nlu_primary"] == "google/gemini-3.8-flash"


def test_get_config_requires_auth(client: TestClient) -> None:
    assert client.get("/v1/config").status_code == 401


def test_admin_update_bumps_version(client: TestClient, device_token: str) -> None:
    response = client.post(
        "/v1/admin/config",
        json={"system_prompt": "Новый промпт"},
        headers={"X-Admin-Token": "admin-secret"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["prompt_version"] == "1.0.1"
    assert body["system_prompt"] == "Новый промпт"

    fetched = client.get("/v1/config", headers=auth(device_token)).json()
    assert fetched["prompt_version"] == "1.0.1"
    assert fetched["system_prompt"] == "Новый промпт"


def test_admin_requires_token(client: TestClient) -> None:
    assert client.post("/v1/admin/config", json={"system_prompt": "x"}).status_code == 401


def test_admin_disabled_without_token(tmp_path) -> None:
    from fastapi.testclient import TestClient as TC

    from app.config import Settings
    from app.main import create_app

    app = create_app(Settings(data_dir=tmp_path / "data", admin_token=""))
    with TC(app) as c:
        response = c.post(
            "/v1/admin/config",
            json={"system_prompt": "x"},
            headers={"X-Admin-Token": "anything"},
        )
        assert response.status_code == 403
