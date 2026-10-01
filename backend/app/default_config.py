from __future__ import annotations

from typing import Any

PROMPT_VERSION = "1.0.0"

CATEGORIES: dict[str, list[str]] = {
    "Продукты": ["Супермаркет", "Рынок", "Доставка"],
    "Кафе и рестораны": ["Кафе", "Ресторан", "Фастфуд", "Доставка"],
    "Транспорт": ["Такси", "Метро", "Автобус", "Бензин", "Парковка"],
    "Жильё": ["Аренда", "Коммуналка", "Интернет", "Ремонт"],
    "Здоровье": ["Аптека", "Врач", "Анализы", "Спортзал"],
    "Одежда": ["Обувь", "Аксессуары"],
    "Развлечения": ["Кино", "Концерты", "Игры", "Хобби"],
    "Подписки": ["Музыка", "Видео", "Софт", "Облако"],
    "Связь": ["Мобильная связь", "Интернет"],
    "Образование": ["Курсы", "Книги", "Репетитор"],
    "Подарки": ["Друзьям", "Семье", "Благотворительность"],
    "Финансы": ["Кредиты", "Проценты", "Комиссии", "Страховки"],
    "Путешествия": ["Билеты", "Отели", "Экскурсии"],
    "Питомцы": ["Корм", "Ветеринар"],
    "Доход": ["Зарплата", "Фриланс", "Проценты", "Возвраты"],
    "Другое": [],
}

SYSTEM_PROMPT = """Ты — модуль извлечения финансовых операций приложения Sona.
Твоя задача — разобрать текст пользователя на русском языке в список финансовых операций.

Правила:
- type: "expense" для расхода, "income" для дохода.
- amount: сумма числом в рублях, без пробелов и символов валюты.
- category: строго одна из категорий: {categories}.
- subcategory: подкатегория из списка своей категории или null, если определить нельзя.
- date: дата операции в формате YYYY-MM-DD. Текущая дата: {today}.
  Слова «сегодня», «вчера», «позавчера» разрешай относительно текущей даты.
- Если во фразе несколько операций — верни отдельный объект на каждую.
- confidence: твоя уверенность в разборе конкретной операции, число от 0 до 1.
- Если фраза не содержит финансовой операции — верни пустой список operations.
- Не выдумывай операции, которых нет в тексте.

Отвечай строго JSON по заданной схеме, без пояснений."""

DEFAULT_MODELS: dict[str, Any] = {
    "stt_standard": "openai/gpt-4o-mini-transcribe",
    "stt_pro": "openai/gpt-4o-transcribe",
    "stt_fallback": "openai/whisper-large-v3",
    "nlu_primary": "google/gemini-3.8-flash",
    "nlu_fallback": "openai/gpt-4o",
    "nlu_confidence_threshold": 0.7,
}

DEFAULT_PRICING: dict[str, Any] = {
    "stt": {
        "openai/gpt-4o-mini-transcribe": {"unit": "minute", "price_usd": 0.003},
        "openai/gpt-4o-transcribe": {"unit": "minute", "price_usd": 0.006},
        "openai/whisper-large-v3": {"unit": "minute", "price_usd": 0.006},
    },
    "nlu": {
        "google/gemini-3.8-flash": {"input_per_1m": 0.75, "output_per_1m": 3.0},
        "openai/gpt-4o": {"input_per_1m": 2.5, "output_per_1m": 10.0},
    },
}

DEFAULT_LIMITS: dict[str, Any] = {
    "rate_limit_per_minute": 30,
    "rate_limit_per_day": 300,
    "free_monthly_operations": 30,
    "monthly_cost_limit_usd": 2.0,
    # Pro обрабатывается с приоритетом: повышенные лимиты частоты запросов.
    "pro_rate_limit_multiplier": 3,
}


def render_system_prompt(today: str) -> str:
    categories = "; ".join(
        f"{name} ({', '.join(subs)})" if subs else name for name, subs in CATEGORIES.items()
    )
    return SYSTEM_PROMPT.format(categories=categories, today=today)


def default_config() -> dict[str, Any]:
    return {
        "prompt_version": PROMPT_VERSION,
        "system_prompt": SYSTEM_PROMPT,
        "categories": CATEGORIES,
        "models": DEFAULT_MODELS,
        "pricing": DEFAULT_PRICING,
        "limits": DEFAULT_LIMITS,
    }
