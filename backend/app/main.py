from __future__ import annotations

import logging
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .config import Settings, get_settings
from .config_store import ConfigStore
from .errors import ApiError
from .logging_config import configure_logging
from .nlu import NluService
from .odirouter import OdiRouterClient
from .routers import config_router, devices, health, nlu, stt
from .storage import Database
from .stt import SttService

logger = logging.getLogger("sona")


def create_app(
    settings: Settings | None = None,
    odirouter: OdiRouterClient | None = None,
) -> FastAPI:
    settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        configure_logging(settings.log_level)
        app.state.settings = settings
        app.state.db = Database(settings.db_path)
        await app.state.db.connect()
        app.state.config_store = ConfigStore(settings.config_path)
        app.state.odirouter = odirouter or OdiRouterClient(
            base_url=settings.odirouter_base_url,
            api_key=settings.odirouter_api_key,
            timeout=settings.request_timeout_seconds,
            max_retries=settings.max_retries,
            backoff_seconds=settings.retry_backoff_seconds,
        )
        app.state.stt = SttService(app.state.odirouter)
        app.state.nlu = NluService(app.state.odirouter)
        logger.info("service started", extra={"endpoint": "startup"})
        try:
            yield
        finally:
            await app.state.odirouter.aclose()
            await app.state.db.close()
            logger.info("service stopped", extra={"endpoint": "shutdown"})

    app = FastAPI(
        title="Sona OdiRouter proxy",
        version="1.0.0",
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url=None,
    )

    @app.middleware("http")
    async def add_request_id(request: Request, call_next):
        request.state.request_id = request.headers.get("X-Request-Id") or uuid.uuid4().hex
        response = await call_next(request)
        response.headers["X-Request-Id"] = request.state.request_id
        return response

    @app.exception_handler(ApiError)
    async def handle_api_error(request: Request, exc: ApiError):
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "error": exc.error,
                "message": exc.message,
                "request_id": getattr(request.state, "request_id", None),
            },
            headers=exc.headers,
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(request: Request, exc: RequestValidationError):
        return JSONResponse(
            status_code=422,
            content={
                "error": "validation_error",
                "message": "Request validation failed",
                "request_id": getattr(request.state, "request_id", None),
            },
        )

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception):
        logger.exception("unhandled error")
        return JSONResponse(
            status_code=500,
            content={
                "error": "internal_error",
                "message": "Internal server error",
                "request_id": getattr(request.state, "request_id", None),
            },
        )

    app.include_router(health.router)
    app.include_router(devices.router)
    app.include_router(config_router.router)
    app.include_router(stt.router)
    app.include_router(nlu.router)

    @app.get("/", include_in_schema=False)
    async def root():
        return {"service": settings.app_name, "status": "ok"}

    return app


app = create_app()
