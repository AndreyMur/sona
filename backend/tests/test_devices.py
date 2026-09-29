from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth


def test_register_and_me(client: TestClient) -> None:
    register = client.post("/v1/devices/register")
    assert register.status_code == 200
    body = register.json()
    assert body["tier"] == "free"
    assert body["device_token"]
    assert body["device_id"]

    me = client.get("/v1/me", headers=auth(body["device_token"]))
    assert me.status_code == 200
    data = me.json()
    assert data["device_id"] == body["device_id"]
    assert data["operations_this_month"] == 0
    assert data["free_monthly_operations"] == 30


def test_missing_token_rejected(client: TestClient) -> None:
    response = client.get("/v1/me")
    assert response.status_code == 401
    assert response.json()["error"] == "unauthorized"


def test_unknown_token_rejected(client: TestClient) -> None:
    response = client.get("/v1/me", headers=auth("nope"))
    assert response.status_code == 401
