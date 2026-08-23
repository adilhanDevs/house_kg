"""Нагрузочный сценарий каталога.

Распределение повторяет реальное поведение приложения: люди листают ленту
намного чаще, чем открывают карточки, и почти никогда не смотрят счётчик
отдельно.

    70 %  GET /api/v1/listings/         — лента со случайными фильтрами
    20 %  GET /api/v1/listings/{slug}/  — карточка объекта
    10 %  GET /api/v1/listings/count/   — счётчик под фильтром

Целевые показатели: p95 < 300 мс при 100 RPS (см. README).

Запуск:
    make loadtest HOST=http://localhost:8000 USERS=100 RATE=10
"""

import random

from locust import HttpUser, between, events, task

# Значения из сидера: фильтры должны попадать в реальные данные, иначе
# нагрузочный тест меряет скорость пустой выдачи.
KINDS = ["apartment", "house", "plot", "new_building", "room", "commercial"]
SELLER_KINDS = ["owner", "realtor", "agency"]
ORDERINGS = ["-published_at", "price", "-price", "-views_count"]
SEARCH_WORDS = ["квартира", "дом", "технопарк", "элитка", "участок", "новостройка"]

# Слаги подтягиваются с сервера на старте: хардкодить их нельзя, база у всех
# своя.
LISTING_SLUGS: list[str] = []


@events.test_start.add_listener
def fetch_slugs(environment, **kwargs) -> None:  # noqa: ANN001, ANN003
    """Забирает пачку слагов до начала прогона."""
    import requests

    host = environment.host or "http://localhost:8000"
    try:
        response = requests.get(f"{host}/api/v1/listings/?page_size=100", timeout=10)
        response.raise_for_status()
    except Exception as exc:  # noqa: BLE001 - прогон без слагов бессмысленен
        raise RuntimeError(f"Не удалось получить объявления с {host}: {exc}") from exc

    LISTING_SLUGS.extend(item["slug"] for item in response.json().get("results", []))
    if not LISTING_SLUGS:
        raise RuntimeError("В каталоге нет активных объявлений: запустите generate_load_data")

    print(f"Загружено слагов для прогона: {len(LISTING_SLUGS)}")


def random_filters() -> dict[str, str]:
    """Случайный, но правдоподобный набор фильтров.

    Пустой набор тоже возможен: открытие ленты без фильтров — самый частый
    запрос, и он обязан попадать в замер.
    """
    filters: dict[str, str] = {}

    if random.random() < 0.6:
        filters["kind"] = random.choice(KINDS)
    if random.random() < 0.3:
        filters["seller_kind"] = random.choice(SELLER_KINDS)
    if random.random() < 0.4:
        low = random.choice([30_000, 50_000, 80_000])
        filters["price_min"] = str(low)
        filters["price_max"] = str(low + random.choice([50_000, 100_000, 200_000]))
    if random.random() < 0.25:
        filters["rooms"] = str(random.randint(1, 4))
    if random.random() < 0.2:
        filters["search"] = random.choice(SEARCH_WORDS)
    if random.random() < 0.3:
        filters["ordering"] = random.choice(ORDERINGS)

    filters["page_size"] = str(random.choice([20, 20, 20, 50]))
    return filters


class CatalogUser(HttpUser):
    """Посетитель каталога. Анонимный: большая часть трафика именно такая."""

    # Пауза между запросами: человек смотрит выдачу, а не долбит API.
    wait_time = between(1, 3)

    @task(70)
    def browse_catalog(self) -> None:
        self.client.get(
            "/api/v1/listings/",
            params=random_filters(),
            name="/api/v1/listings/",
        )

    @task(20)
    def open_listing(self) -> None:
        slug = random.choice(LISTING_SLUGS)
        self.client.get(
            f"/api/v1/listings/{slug}/",
            name="/api/v1/listings/{slug}/",
        )

    @task(10)
    def count_listings(self) -> None:
        self.client.get(
            "/api/v1/listings/count/",
            params=random_filters(),
            name="/api/v1/listings/count/",
        )
