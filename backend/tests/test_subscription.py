from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from tests.conftest import auth

ADMIN = {"X-Admin-Token": "admin-secret"}


def _set_limits(client: TestClient, **limits) -> None:
    response = client.post("/v1/admin/config", json={"limits": limits}, headers=ADMIN)
    assert response.status_code == 200, response.text


def test_subscription_activates_pro_and_removes_free_limit(
    client: TestClient,
) -> None:
    register = client.post("/v1/devices/register").json()
    token = register["device_token"]
    _set_limits(client, free_monthly_operations=0, monthly_cost_limit_usd=100)

    blocked = client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(token))
    assert blocked.status_code == 402
    assert blocked.json()["error"] == "free_limit_reached"

    activated = client.post(
        "/v1/subscription",
        json={"plan": "monthly", "platform": "android", "purchase_token": "tok-1"},
        headers=auth(token),
    )
    assert activated.status_code == 200, activated.text
    body = activated.json()
    assert body["tier"] == "pro"
    assert body["plan"] == "monthly"
    assert body["status"] == "active"
    assert body["trial"] is False

    ok = client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(token))
    assert ok.status_code == 200, ok.text

    me = client.get("/v1/me", headers=auth(token)).json()
    assert me["tier"] == "pro"


def test_trial_subscription_expires_in_seven_days(client: TestClient) -> None:
    register = client.post("/v1/devices/register").json()
    token = register["device_token"]

    response = client.post(
        "/v1/subscription",
        json={"plan": "monthly", "trial": True},
        headers=auth(token),
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["tier"] == "pro"
    assert body["trial"] is True

    expires = datetime.fromisoformat(body["expires_at"])
    remaining = expires - datetime.now(UTC)
    assert timedelta(days=6, hours=23) < remaining <= timedelta(days=7, minutes=1)


def test_cancel_subscription_returns_free(client: TestClient) -> None:
    register = client.post("/v1/devices/register").json()
    token = register["device_token"]
    client.post(
        "/v1/subscription",
        json={"plan": "annual", "purchase_token": "tok-2"},
        headers=auth(token),
    )
    assert client.get("/v1/me", headers=auth(token)).json()["tier"] == "pro"

    canceled = client.delete("/v1/subscription", headers=auth(token))
    assert canceled.status_code == 200, canceled.text
    assert canceled.json()["tier"] == "free"
    assert client.get("/v1/me", headers=auth(token)).json()["tier"] == "free"


def test_expired_subscription_downgrades_to_free(client: TestClient) -> None:
    register = client.post("/v1/devices/register").json()
    token = register["device_token"]
    past = (datetime.now(UTC) - timedelta(days=1)).isoformat()

    client.post(
        "/v1/subscription",
        json={"plan": "monthly", "purchase_token": "tok-3", "expires_at": past},
        headers=auth(token),
    )

    # Любой авторизованный запрос снимает истёкший Pro.
    me = client.get("/v1/me", headers=auth(token)).json()
    assert me["tier"] == "free"

    subscription = client.get("/v1/subscription", headers=auth(token)).json()
    assert subscription["tier"] == "free"
    assert subscription["status"] == "expired"


def test_auto_approve_off_requires_purchase_token(client: TestClient) -> None:
    register = client.post("/v1/devices/register").json()
    token = register["device_token"]
    # Отключаем авто-подтверждение и пробуем активировать без токена покупки.
    settings = client.app.state.settings
    settings.subscription_auto_approve = False
    try:
        response = client.post(
            "/v1/subscription",
            json={"plan": "monthly"},
            headers=auth(token),
        )
        assert response.status_code == 402
        assert response.json()["error"] == "purchase_required"
    finally:
        settings.subscription_auto_approve = True
