from __future__ import annotations

from fastapi.testclient import TestClient

from tests.conftest import FALLBACK, PRIMARY, MockRouter, auth


def test_parse_primary_model(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    response = client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(device_token))
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["model"] == PRIMARY
    assert body["fallback_used"] is False
    assert body["prompt_version"] == "1.0.0"
    assert len(body["operations"]) == 1
    op = body["operations"][0]
    assert op["type"] == "expense"
    assert op["amount"] == 400
    assert op["category"] == "Транспорт"
    assert op["subcategory"] == "Такси"
    assert body["cost_usd"] > 0


def test_parse_multiple_operations(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    mock_router.chat_by_model[PRIMARY] = {
        "operations": [
            {
                "type": "expense",
                "amount": 2300,
                "category": "Продукты",
                "subcategory": "Супермаркет",
                "date": "2026-09-29",
                "confidence": 0.9,
            },
            {
                "type": "expense",
                "amount": 600,
                "category": "Транспорт",
                "subcategory": "Такси",
                "date": "2026-09-29",
                "confidence": 0.9,
            },
        ],
        "overall_confidence": 0.9,
    }
    response = client.post(
        "/v1/parse",
        json={"text": "потратил 2300 на продукты и 600 на такси"},
        headers=auth(device_token),
    )
    assert response.status_code == 200
    assert len(response.json()["operations"]) == 2


def test_low_confidence_triggers_fallback(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    mock_router.chat_by_model[PRIMARY] = {
        "operations": [],
        "overall_confidence": 0.3,
    }
    response = client.post("/v1/parse", json={"text": "что-то"}, headers=auth(device_token))
    assert response.status_code == 200
    body = response.json()
    assert body["fallback_used"] is True
    assert body["model"] == FALLBACK
    assert len(mock_router.chat_calls) == 2
    assert mock_router.chat_calls[0]["model"] == PRIMARY
    assert mock_router.chat_calls[1]["model"] == FALLBACK


def test_primary_failure_triggers_fallback(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    mock_router.fail_primary_chat = True
    response = client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(device_token))
    assert response.status_code == 200
    body = response.json()
    assert body["fallback_used"] is True
    assert body["model"] == FALLBACK


def test_json_schema_is_sent(
    client: TestClient, mock_router: MockRouter, device_token: str
) -> None:
    client.post("/v1/parse", json={"text": "такси 400"}, headers=auth(device_token))
    request_body = mock_router.chat_calls[0]
    response_format = request_body["response_format"]
    assert response_format["type"] == "json_schema"
    assert response_format["json_schema"]["strict"] is True
    assert response_format["json_schema"]["schema"]["required"] == [
        "operations",
        "overall_confidence",
    ]
