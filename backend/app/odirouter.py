from __future__ import annotations

import asyncio
import logging
from typing import Any

import httpx

logger = logging.getLogger("sona.odirouter")

RETRYABLE_STATUS = {408, 409, 425, 429, 500, 502, 503, 504}


class OdiRouterError(Exception):
    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


class OdiRouterClient:
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        timeout: float = 60.0,
        max_retries: int = 3,
        backoff_seconds: float = 0.5,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._max_retries = max(1, max_retries)
        self._backoff = backoff_seconds
        self._client = client or httpx.AsyncClient(timeout=timeout)
        self._owns_client = client is None

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    @property
    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self._api_key}"}

    async def _request(self, method: str, path: str, **kwargs: Any) -> httpx.Response:
        url = f"{self._base_url}{path}"
        last_exc: Exception | None = None
        for attempt in range(self._max_retries):
            try:
                response = await self._client.request(
                    method, url, headers=self._headers, **kwargs
                )
            except (httpx.TimeoutException, httpx.TransportError) as exc:
                last_exc = exc
                logger.warning("OdiRouter transport error (attempt %s): %s", attempt + 1, exc)
            else:
                if response.status_code in RETRYABLE_STATUS:
                    last_exc = OdiRouterError(
                        f"OdiRouter retryable status {response.status_code}",
                        status_code=response.status_code,
                    )
                    logger.warning(
                        "OdiRouter status %s (attempt %s)", response.status_code, attempt + 1
                    )
                else:
                    return response
            if attempt < self._max_retries - 1:
                await asyncio.sleep(self._backoff * (2**attempt))
        if isinstance(last_exc, OdiRouterError):
            raise last_exc
        raise OdiRouterError(f"OdiRouter request failed: {last_exc}")

    async def transcribe(
        self,
        *,
        content: bytes,
        filename: str,
        content_type: str,
        model: str,
        language: str = "ru",
    ) -> dict[str, Any]:
        files = {"file": (filename, content, content_type or "audio/m4a")}
        data = {"model": model, "language": language, "response_format": "json"}
        response = await self._request(
            "POST", "/audio/transcriptions", files=files, data=data
        )
        if response.status_code >= 400:
            raise OdiRouterError(
                f"OdiRouter transcription failed: {response.status_code} {response.text[:300]}",
                status_code=response.status_code,
            )
        payload = response.json()
        return {
            "text": payload.get("text", ""),
            "model": model,
            "usage": payload.get("usage", {}) or {},
        }

    async def chat_json(
        self,
        *,
        model: str,
        messages: list[dict[str, Any]],
        schema: dict[str, Any],
        temperature: float = 0.0,
    ) -> dict[str, Any]:
        body = {
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "operations",
                    "strict": True,
                    "schema": schema,
                },
            },
        }
        response = await self._request("POST", "/chat/completions", json=body)
        if response.status_code >= 400:
            raise OdiRouterError(
                f"OdiRouter chat failed: {response.status_code} {response.text[:300]}",
                status_code=response.status_code,
            )
        payload = response.json()
        choices = payload.get("choices") or []
        if not choices:
            raise OdiRouterError("OdiRouter chat returned no choices")
        message = choices[0].get("message", {})
        content = message.get("content")
        if isinstance(content, list):
            content = "".join(part.get("text", "") for part in content if isinstance(part, dict))
        return {
            "content": content,
            "model": payload.get("model", model),
            "usage": payload.get("usage", {}) or {},
        }
