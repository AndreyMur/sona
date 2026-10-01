from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import auth

ADMIN = {"X-Admin-Token": "admin-secret"}


def _set_limits(client: TestClient, **limits) -> None:
    response = client.post("/v1/admin/config", json={"limits": limits}, headers=ADMIN)
    assert response.status_code == 200, response.text


def test_free_operation_quota(client: TestClient, device_token: str) -> None:
    _set_limits(client, free_monthly_operations=1, monthly_cost_limit_usd=100)
    first = client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(device_token))
    assert first.status_code == 200, first.text
    second = client.post("/v1/parse", json={"text": "такси 500"}, headers=auth(device_token))
    assert second.status_code == 402
    assert second.json()["error"] == "free_limit_reached"


def test_pro_tier_removes_operation_quota(client: TestClient) -> None:
    register = client.post("/v1/devices/register").json()
    token = register["device_token"]
    _set_limits(client, free_monthly_operations=0, monthly_cost_limit_usd=100)
    client.post(
        f"/v1/admin/devices/{register['device_id']}/tier",
        json={"tier": "pro"},
        headers=ADMIN,
    )
    response = client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(token))
    assert response.status_code == 200, response.text


def test_rate_limit_per_minute(client: TestClient, device_token: str) -> None:
    _set_limits(
        client,
        rate_limit_per_minute=2,
        rate_limit_per_day=100,
        free_monthly_operations=100,
    )
    first = client.post("/v1/parse", json={"text": "a"}, headers=auth(device_token))
    second = client.post("/v1/parse", json={"text": "b"}, headers=auth(device_token))
    assert first.status_code == 200
    assert second.status_code == 200
    third = client.post("/v1/parse", json={"text": "c"}, headers=auth(device_token))
    assert third.status_code == 429
    assert third.json()["error"] == "rate_limited"


def test_cost_limit(client: TestClient, device_token: str) -> None:
    _set_limits(client, monthly_cost_limit_usd=0.0)
    response = client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(device_token))
    assert response.status_code == 402
    assert response.json()["error"] == "cost_limit_reached"


def test_pro_tier_gets_priority_rate_limit(client: TestClient, device_token: str) -> None:
    _set_limits(
        client,
        rate_limit_per_minute=1,
        rate_limit_per_day=100,
        free_monthly_operations=100,
        pro_rate_limit_multiplier=5,
    )
    first = client.post("/v1/parse", json={"text": "a"}, headers=auth(device_token))
    assert first.status_code == 200
    second = client.post("/v1/parse", json={"text": "b"}, headers=auth(device_token))
    assert second.status_code == 429

    me = client.get("/v1/me", headers=auth(device_token)).json()
    client.post(
        f"/v1/admin/devices/{me['device_id']}/tier",
        json={"tier": "pro"},
        headers=ADMIN,
    )
    third = client.post("/v1/parse", json={"text": "c"}, headers=auth(device_token))
    assert third.status_code == 200, third.text


def test_usage_logged(client: TestClient, device_token: str) -> None:
    client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(device_token))
    me = client.get("/v1/me", headers=auth(device_token)).json()
    assert me["operations_this_month"] == 1
    assert me["cost_this_month_usd"] > 0
