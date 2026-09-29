from __future__ import annotations

import asyncio
import uuid
from datetime import UTC, datetime
from pathlib import Path

import aiosqlite

SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL UNIQUE,
    tier TEXT NOT NULL DEFAULT 'free',
    created_at TEXT NOT NULL,
    last_seen_at TEXT,
    revoked INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS request_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    model TEXT,
    latency_ms INTEGER NOT NULL DEFAULT 0,
    cost_usd REAL NOT NULL DEFAULT 0,
    status TEXT NOT NULL,
    created_at TEXT NOT NULL,
    detail TEXT
);

CREATE INDEX IF NOT EXISTS idx_request_log_device_created
    ON request_log (device_id, created_at);
"""


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _iso(dt: datetime) -> str:
    return dt.astimezone(UTC).isoformat()


def month_start(now: datetime | None = None) -> datetime:
    now = now or _utcnow()
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


class Database:
    def __init__(self, path: Path) -> None:
        self._path = path
        self._conn: aiosqlite.Connection | None = None
        self._lock = asyncio.Lock()

    async def connect(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = await aiosqlite.connect(self._path)
        self._conn.row_factory = aiosqlite.Row
        await self._conn.executescript(SCHEMA)
        await self._conn.commit()

    async def close(self) -> None:
        if self._conn is not None:
            await self._conn.close()
            self._conn = None

    @property
    def conn(self) -> aiosqlite.Connection:
        if self._conn is None:
            raise RuntimeError("Database is not connected")
        return self._conn

    async def create_device(self, token_hash: str, tier: str = "free") -> dict:
        device_id = uuid.uuid4().hex
        created = _iso(_utcnow())
        async with self._lock:
            await self.conn.execute(
                "INSERT INTO devices (id, token_hash, tier, created_at) VALUES (?, ?, ?, ?)",
                (device_id, token_hash, tier, created),
            )
            await self.conn.commit()
        return {
            "id": device_id,
            "token_hash": token_hash,
            "tier": tier,
            "created_at": created,
            "last_seen_at": None,
            "revoked": 0,
        }

    async def get_device_by_token_hash(self, token_hash: str) -> dict | None:
        async with self.conn.execute(
            "SELECT * FROM devices WHERE token_hash = ? AND revoked = 0",
            (token_hash,),
        ) as cursor:
            row = await cursor.fetchone()
        return dict(row) if row else None

    async def touch_device(self, device_id: str) -> None:
        async with self._lock:
            await self.conn.execute(
                "UPDATE devices SET last_seen_at = ? WHERE id = ?",
                (_iso(_utcnow()), device_id),
            )
            await self.conn.commit()

    async def set_tier(self, device_id: str, tier: str) -> None:
        async with self._lock:
            await self.conn.execute(
                "UPDATE devices SET tier = ? WHERE id = ?", (tier, device_id)
            )
            await self.conn.commit()

    async def log_request(
        self,
        *,
        device_id: str,
        endpoint: str,
        status: str,
        model: str | None = None,
        latency_ms: int = 0,
        cost_usd: float = 0.0,
        detail: str | None = None,
    ) -> None:
        async with self._lock:
            await self.conn.execute(
                """INSERT INTO request_log
                   (device_id, endpoint, model, latency_ms, cost_usd, status, created_at, detail)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    device_id,
                    endpoint,
                    model,
                    latency_ms,
                    cost_usd,
                    status,
                    _iso(_utcnow()),
                    detail,
                ),
            )
            await self.conn.commit()

    async def count_requests_since(self, device_id: str, since: datetime) -> int:
        async with self.conn.execute(
            "SELECT COUNT(*) AS c FROM request_log WHERE device_id = ? AND created_at >= ?",
            (device_id, _iso(since)),
        ) as cursor:
            row = await cursor.fetchone()
        return int(row["c"]) if row else 0

    async def count_billable_ops_since(self, device_id: str, since: datetime) -> int:
        async with self.conn.execute(
            """SELECT COUNT(*) AS c FROM request_log
               WHERE device_id = ? AND created_at >= ? AND status = 'ok'
                 AND endpoint IN ('/v1/audio/transcriptions', '/v1/parse')""",
            (device_id, _iso(since)),
        ) as cursor:
            row = await cursor.fetchone()
        return int(row["c"]) if row else 0

    async def sum_cost_since(self, device_id: str, since: datetime) -> float:
        async with self.conn.execute(
            "SELECT COALESCE(SUM(cost_usd), 0) AS s FROM request_log "
            "WHERE device_id = ? AND created_at >= ?",
            (device_id, _iso(since)),
        ) as cursor:
            row = await cursor.fetchone()
        return float(row["s"]) if row else 0.0
