# Sona — self-hosted OdiRouter proxy

Backend-прокси для приложения Sona: распознавание речи (STT) и разбор текста в
структуру операций (NLU) через [OdiRouter](https://api.odirouter.ai). Ключ
OdiRouter хранится только на сервере и никогда не попадает в мобильное
приложение.

Стек: Python 3.11+ / FastAPI / httpx / aiosqlite. Деплой: Docker + docker-compose
+ Caddy (автоматический HTTPS).

## Эндпоинты

| Метод | Путь | Назначение |
|---|---|---|
| GET | `/healthz` | Проверка живости |
| POST | `/v1/devices/register` | Анонимная регистрация устройства, выдаёт `device_token` |
| GET | `/v1/me` | Тариф, расход операций и денег за месяц |
| GET | `/v1/config` | Remote config: версия промпта, модели, лимиты |
| POST | `/v1/audio/transcriptions` | STT: аудио `.m4a` → текст |
| POST | `/v1/parse` | NLU: текст → JSON-схема операций |
| POST | `/v1/admin/config` | Обновление промпта/моделей/лимитов (admin token) |
| POST | `/v1/admin/devices/{id}/tier` | Переключение тарифа `free`/`pro` (admin token) |

Все `/v1/*` эндпоинты, кроме регистрации, требуют заголовок
`Authorization: Bearer <device_token>`.

### STT

`POST /v1/audio/transcriptions` (multipart/form-data)

- `file` — аудио `.m4a` (16 kHz, mono), до `MAX_AUDIO_BYTES`
- `quality` — `standard` (по умолчанию) или `max` (для тарифа Pro)
- `duration_seconds` — необязательно; если не передано, длительность
  вычисляется из MP4-контейнера
- `language` — `ru` по умолчанию

Модели: `openai/gpt-4o-mini-transcribe` → `openai/gpt-4o-transcribe` (Pro) →
`openai/whisper-large-v3` (fallback при ошибке upstream).

### NLU

`POST /v1/parse`

```json
{ "text": "потратил 2300 на продукты и 600 на такси" }
```

Ответ строится по строгой JSON-схеме (`response_format: json_schema`):

```json
{
  "operations": [
    {"type": "expense", "amount": 2300, "category": "Продукты",
     "subcategory": "Супермаркет", "date": "2026-09-29", "confidence": 0.95}
  ],
  "overall_confidence": 0.95,
  "model": "google/gemini-3.8-flash",
  "fallback_used": false,
  "prompt_version": "1.0.0",
  "latency_ms": 640,
  "cost_usd": 0.00021
}
```

Модели: `google/gemini-3.8-flash` (основная) → `openai/gpt-4o` (fallback при
`overall_confidence < NLU_CONFIDENCE_THRESHOLD` или ошибке).

## Версионируемый промпт и remote config

Конфиг хранится в `DATA_DIR/config.json`. При старте он инициализируется
значениями из `app/default_config.py`. Обновление без релиза приложения:

```bash
curl -X POST https://aidailyplanner.ru/v1/admin/config \
  -H "X-Admin-Token: $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"system_prompt": "Новый системный промпт", "models": {"nlu_primary": "openai/gpt-4o"}}'
```

Каждое обновление увеличивает `prompt_version`; приложение получает её через
`GET /v1/config`.

## Аутентификация, лимиты и логирование

- Анонимная регистрация: сервер генерирует `device_token`, в БД хранится только
  его SHA-256.
- Rate limiting: `RATE_LIMIT_PER_MINUTE` и `RATE_LIMIT_PER_DAY` на устройство.
- Лимиты расходов: `FREE_MONTHLY_OPERATIONS` (бесплатный тариф) и
  `MONTHLY_COST_LIMIT_USD` (для всех). Превышение → HTTP 402.
- Retry-политика: экспоненциальный backoff на 408/409/425/429/5xx и сетевые
  ошибки (`MAX_RETRIES`, `RETRY_BACKOFF_SECONDS`).
- Каждый запрос логируется в SQLite (`request_log`) и в stdout в формате JSON:
  `request_id`, `device_id`, `endpoint`, `model`, `latency_ms`, `cost_usd`,
  `status`, `fallback_used`.
- Ошибки отдаются единообразно: `{"error": "...", "message": "...", "request_id": "..."}`.

## Локальная разработка

```bash
python -m venv .venv
.venv/Scripts/activate          # Windows
# source .venv/bin/activate     # Linux/macOS
pip install -r requirements-dev.txt

cp .env.example .env            # заполнить ODIROUTER_API_KEY и ADMIN_TOKEN
uvicorn app.main:app --reload
```

Проверки:

```bash
python -m pytest
python -m ruff check app tests scripts
```

## Деплой на aidailyplanner.ru

1. Скопируйте каталог `backend/` на сервер.
2. Создайте `.env` на основе `.env.example` и заполните `ODIROUTER_API_KEY`,
   `ADMIN_TOKEN`, `ACME_EMAIL`.
3. Убедитесь, что DNS-запись `aidailyplanner.ru` указывает на сервер, а порты
   80/443 открыты.
4. Запустите:

```bash
bash scripts/deploy.sh
bash scripts/smoke.sh https://aidailyplanner.ru
```

Caddy автоматически выпустит сертификат Let's Encrypt и проксирует трафик на
`app:8000`. Данные (БД и remote config) сохраняются в томе `app_data`.

## Прогон тестового набора из 50 фраз

Набор: `data/test_phrases.json` (50 русскоязычных фраз с ожидаемой структурой).
Скрипт считает WER для STT, точность категоризации для NLU, среднюю задержку и
стоимость, и пишет отчёт в `reports/`.

```bash
# через развёрнутый прокси
python scripts/benchmark.py --mode proxy --base-url https://aidailyplanner.ru

# напрямую в OdiRouter для сравнения моделей
ODIRUTER_API_KEY=sk-... python scripts/benchmark.py --mode direct \
  --nlu-primary google/gemini-3.8-flash --nlu-fallback openai/gpt-4o

# для WER положите аудио p01.m4a … p50.m4a и укажите каталог
python scripts/benchmark.py --mode proxy --base-url http://localhost:8000 \
  --audio-dir data/audio
```

Результат: `reports/metrics.json` и `reports/report.md`.

## Переменные окружения

См. `.env.example`. Ключевые: `ODIROUTER_API_KEY`, `ADMIN_TOKEN`,
`DATA_DIR`, `STT_MODEL_*`, `NLU_MODEL_*`, `NLU_CONFIDENCE_THRESHOLD`,
`RATE_LIMIT_*`, `FREE_MONTHLY_OPERATIONS`, `MONTHLY_COST_LIMIT_USD`,
`MAX_AUDIO_BYTES`, `ACME_EMAIL`.
