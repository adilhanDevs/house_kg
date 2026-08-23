"""Кошелёк во внутренней валюте («кирпичи») и неизменяемый леджер операций."""

from typing import Any

from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.db import models
from django.utils import timezone

from apps.common.enums import WalletEntryKind
from apps.common.models import TimeStampedModel, UUIDModel

# Разделитель разрядов в макете — точка: 16700 -> «16.700».
THOUSANDS_SEPARATOR = "."


class Wallet(TimeStampedModel):
    """Кошелёк пользователя. Баланс — целое число кирпичей.

    Менять баланс напрямую нельзя: единственный способ — `apply_transaction`,
    он держит блокировку строки и пишет операцию в леджер.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="wallet",
    )
    balance = models.BigIntegerField("Баланс, кирпичей", default=0)

    class Meta:
        verbose_name = "Кошелёк"
        verbose_name_plural = "Кошельки"
        constraints = [
            # Уйти в минус нельзя даже при гонке: последний рубеж — сама БД.
            models.CheckConstraint(
                condition=models.Q(balance__gte=0),
                name="wallet_balance_non_negative",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.user.phone}: {self.balance_display} кирпичей"

    @property
    def balance_display(self) -> str:
        """16700 -> «16.700», как на экране кошелька."""
        return format_bricks(self.balance)


def format_bricks(amount: int) -> str:
    """Разряды тысяч через точку, знак сохраняется."""
    sign = "-" if amount < 0 else ""
    return f"{sign}{abs(int(amount)):,}".replace(",", THOUSANDS_SEPARATOR)


class WalletTransaction(models.Model):
    """Операция по кошельку. Append-only: записи не меняются и не удаляются.

    Ошибочная операция компенсируется обратной, а не правкой: леджер должен
    оставаться историей того, что действительно произошло.
    """

    wallet = models.ForeignKey(
        Wallet,
        verbose_name="Кошелёк",
        on_delete=models.CASCADE,
        related_name="transactions",
    )
    amount = models.BigIntegerField("Сумма, кирпичей")
    kind = models.CharField("Тип операции", max_length=16, choices=WalletEntryKind.choices)
    label = models.CharField("Описание", max_length=200)
    balance_after = models.BigIntegerField("Баланс после операции")

    # На что ссылается операция: пополнение, продвижение, подписка.
    related_content_type = models.ForeignKey(
        ContentType,
        verbose_name="Тип объекта",
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
    )
    # Строкой, а не числом: операции ссылаются и на объявления (int-ключи),
    # и на платежи (UUID).
    related_object_id = models.CharField(  # noqa: DJ001
        "ID объекта", max_length=64, blank=True, null=True, db_index=True
    )
    related = GenericForeignKey("related_content_type", "related_object_id")

    # Ключ идемпотентности: повторный запрос не создаёт вторую операцию.
    idempotency_key = models.CharField(
        "Ключ идемпотентности", max_length=64, unique=True, blank=True, null=True
    )
    created_at = models.DateTimeField("Создана", auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = "Операция по кошельку"
        verbose_name_plural = "Операции по кошельку"
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=["wallet", "-created_at"], name="wallet_tx_recent_idx"),
            models.Index(fields=["wallet", "kind", "-created_at"], name="wallet_tx_kind_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.amount:+d} · {self.get_kind_display()}"

    def save(self, *args: Any, **kwargs: Any) -> None:
        if self.pk is not None:
            raise RuntimeError(
                "Операции по кошельку неизменяемы: заведите компенсирующую операцию."
            )
        super().save(*args, **kwargs)

    def delete(self, *args: Any, **kwargs: Any) -> None:
        raise RuntimeError("Операции по кошельку не удаляются: заведите компенсирующую операцию.")

    @property
    def amount_display(self) -> str:
        """«+12.000» / «-500» — со знаком, как в истории операций."""
        return f"{'+' if self.amount >= 0 else '-'}{format_bricks(abs(self.amount))}"


class PaymentProviderConfig(TimeStampedModel):
    """Банк на экране выбора способа пополнения."""

    code = models.SlugField("Код", max_length=32, unique=True)
    name = models.CharField("Название", max_length=100)
    logo = models.ImageField("Логотип", upload_to="payments/%Y/%m/", blank=True, null=True)
    deeplink_template = models.CharField(
        "Шаблон диплинка",
        max_length=255,
        blank=True,
        help_text=(
            "Подстановки: {payment_url}, {provider_ref}, {amount}. "
            "Например: mbank://pay?target={provider_ref}&amount={amount}"
        ),
    )
    is_active = models.BooleanField("Активен", default=True)
    order = models.PositiveSmallIntegerField("Порядок", default=0, db_index=True)

    class Meta:
        verbose_name = "Способ оплаты"
        verbose_name_plural = "Способы оплаты"
        ordering = ["order", "name"]

    def __str__(self) -> str:
        return self.name

    def build_deeplink(self, payment_url: str, provider_ref: str, amount: Any) -> str:
        """Диплинк в приложение банка. Кривой шаблон не должен ронять ответ."""
        if not self.deeplink_template:
            return ""
        try:
            return self.deeplink_template.format(
                payment_url=payment_url,
                provider_ref=provider_ref or "",
                amount=amount,
            )
        except (KeyError, IndexError, ValueError):
            return ""


class PaymentStatus(models.TextChoices):
    PENDING = "pending", "Ожидает оплаты"
    SUCCEEDED = "succeeded", "Оплачен"
    FAILED = "failed", "Не прошёл"
    EXPIRED = "expired", "Просрочен"
    REFUNDED = "refunded", "Возвращён"


class Payment(UUIDModel, TimeStampedModel):
    """Счёт на пополнение кошелька.

    Кирпичи начисляются не здесь, а вебхуком через `apply_transaction`:
    единственный источник изменения баланса — леджер.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="payments",
    )
    amount_kgs = models.DecimalField("Сумма, сом", max_digits=12, decimal_places=2)
    bricks = models.BigIntegerField("Кирпичей", default=0)
    bonus_bricks = models.BigIntegerField("Бонусных кирпичей", default=0)

    provider = models.CharField("Провайдер", max_length=32)
    # null=True по требованию ТЗ: до ответа провайдера ссылки ещё нет,
    # и «нет значения» здесь честнее пустой строки.
    provider_ref = models.CharField(  # noqa: DJ001
        "ID платежа у провайдера", max_length=128, blank=True, null=True, db_index=True
    )
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
        db_index=True,
    )
    idempotency_key = models.CharField("Ключ идемпотентности", max_length=64, unique=True)

    paid_at = models.DateTimeField("Оплачен", blank=True, null=True)
    expires_at = models.DateTimeField("Действителен до", blank=True, null=True)
    raw_response = models.JSONField("Ответ провайдера", default=dict, blank=True)

    class Meta:
        verbose_name = "Пополнение"
        verbose_name_plural = "Пополнения"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "-created_at"], name="payment_user_recent_idx"),
            models.Index(fields=["status", "expires_at"], name="payment_status_expiry_idx"),
        ]

    def __str__(self) -> str:
        return f"Пополнение на {self.amount_kgs} сом ({self.get_status_display()})"

    @property
    def total_bricks(self) -> int:
        return self.bricks + self.bonus_bricks

    @property
    def is_expired(self) -> bool:
        return bool(self.expires_at and self.expires_at <= timezone.now())


class PaymentLogDirection(models.TextChoices):
    IN = "in", "Входящий"
    OUT = "out", "Исходящий"


class PaymentLog(models.Model):
    """Сырой обмен с провайдером — для разбора спорных платежей.

    Чувствительные поля (карта, CVV, токены, подписи) маскируются до записи:
    в логах платёжных данных быть не должно.
    """

    payment = models.ForeignKey(
        Payment,
        verbose_name="Платёж",
        on_delete=models.SET_NULL,
        related_name="logs",
        blank=True,
        null=True,
    )
    direction = models.CharField("Направление", max_length=8, choices=PaymentLogDirection.choices)
    endpoint = models.CharField("Эндпоинт", max_length=255, blank=True)
    payload = models.JSONField("Тело", default=dict, blank=True)
    status_code = models.PositiveSmallIntegerField("Код ответа", blank=True, null=True)
    created_at = models.DateTimeField("Создан", auto_now_add=True, db_index=True)

    class Meta:
        verbose_name = "Лог платежа"
        verbose_name_plural = "Логи платежей"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["payment", "-created_at"], name="payment_log_recent_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.get_direction_display()} {self.endpoint} ({self.status_code})"


class PromotionStatus(models.TextChoices):
    """Состояние продвижения."""

    ACTIVE = "active", "Действует"
    FINISHED = "finished", "Завершено"
    REFUNDED = "refunded", "Возвращено"


class PromotionPackage(TimeStampedModel):
    """Тариф продвижения. Базовый — 780 кирпичей за день (`AppState.promoCost`)."""

    code = models.SlugField("Код", max_length=32, unique=True)
    name = models.CharField("Название", max_length=100)
    price_per_day_bricks = models.BigIntegerField("Цена за день, кирпичей")
    description = models.TextField("Описание", blank=True)
    is_active = models.BooleanField("Активен", default=True)
    order = models.PositiveSmallIntegerField("Порядок", default=0, db_index=True)

    class Meta:
        verbose_name = "Пакет продвижения"
        verbose_name_plural = "Пакеты продвижения"
        ordering = ["order", "code"]

    def __str__(self) -> str:
        return f"{self.name} ({self.price_per_day_bricks} кирпичей/день)"

    def cost_for(self, days: int) -> int:
        return self.price_per_day_bricks * days


class PromotionOption(TimeStampedModel):
    """Дополнительная опция продвижения — тумблеры на экране `ad_promo_page`."""

    code = models.SlugField("Код", max_length=32, unique=True)
    name = models.CharField("Название", max_length=100)
    price_per_day_bricks = models.BigIntegerField("Цена за день, кирпичей")
    description = models.TextField("Описание", blank=True)
    is_active = models.BooleanField("Активна", default=True)
    order = models.PositiveSmallIntegerField("Порядок", default=0, db_index=True)

    class Meta:
        verbose_name = "Опция продвижения"
        verbose_name_plural = "Опции продвижения"
        ordering = ["order", "code"]

    def __str__(self) -> str:
        return f"{self.name} (+{self.price_per_day_bricks} кирпичей/день)"

    def cost_for(self, days: int) -> int:
        return self.price_per_day_bricks * days


class Promotion(TimeStampedModel):
    """Оплаченное продвижение объявления.

    Ссылка на объявление строкой (`catalog.Listing`), а не импортом: каталог
    ничего не должен знать о биллинге, и обратная зависимость не нужна.
    """

    listing = models.ForeignKey(
        "catalog.Listing",
        verbose_name="Объявление",
        on_delete=models.CASCADE,
        related_name="promotions",
    )
    package = models.ForeignKey(
        PromotionPackage,
        verbose_name="Пакет",
        on_delete=models.PROTECT,
        related_name="promotions",
    )
    days = models.PositiveSmallIntegerField("Дней")
    # Коды выбранных опций. Список, а не M2M: цена уже зафиксирована в
    # cost_bricks, а состав опций нужен только как история покупки.
    options = models.JSONField("Опции", default=list, blank=True)
    cost_bricks = models.BigIntegerField("Стоимость, кирпичей")

    starts_at = models.DateTimeField("Начало")
    ends_at = models.DateTimeField("Окончание", db_index=True)

    transaction = models.ForeignKey(
        WalletTransaction,
        verbose_name="Операция списания",
        # Леджер неизменяем: удаление операции вместе с продвижением
        # рассинхронизировало бы баланс с историей.
        on_delete=models.PROTECT,
        related_name="promotions",
        blank=True,
        null=True,
    )
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=PromotionStatus.choices,
        default=PromotionStatus.ACTIVE,
        db_index=True,
    )
    # Чтобы почасовая задача не слала «заканчивается завтра» каждый час.
    expiry_notified_at = models.DateTimeField("Уведомление отправлено", blank=True, null=True)

    class Meta:
        verbose_name = "Продвижение"
        verbose_name_plural = "Продвижения"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "ends_at"], name="promotion_status_ends_idx"),
            models.Index(fields=["listing", "-created_at"], name="promotion_listing_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.listing_id}: {self.days} дн. за {self.cost_bricks}"

    @property
    def is_running(self) -> bool:
        return self.status == PromotionStatus.ACTIVE and self.ends_at > timezone.now()


def default_tariff_features() -> dict[str, bool]:
    """Полный набор фич — чтобы у всех тарифов был одинаковый набор ключей."""
    return {
        "priority_in_search": False,
        "advanced_stats": False,
        "verified_badge": False,
        "auto_bump_daily": False,
        "support_priority": False,
    }


class SubscriptionStatus(models.TextChoices):
    """Состояние подписки."""

    ACTIVE = "active", "Действует"
    EXPIRED = "expired", "Истекла"
    CANCELLED = "cancelled", "Отменена"


class Tariff(TimeStampedModel):
    """Тариф риелтора или агентства — экран «Тарифы».

    Бесплатный тариф тоже лежит здесь: иначе лимит бесплатных объявлений
    пришлось бы держать в двух местах — в настройках и в справочнике.
    """

    code = models.SlugField("Код", max_length=32, unique=True)
    name = models.CharField("Название", max_length=100)
    description = models.TextField("Описание", blank=True)
    price_bricks_per_month = models.BigIntegerField("Цена, кирпичей в месяц", default=0)
    listings_limit = models.PositiveIntegerField(
        "Лимит активных объявлений",
        default=0,
        help_text="0 — без ограничений.",
    )
    features = models.JSONField("Возможности", default=default_tariff_features, blank=True)
    is_active = models.BooleanField("Активен", default=True)
    order = models.PositiveSmallIntegerField("Порядок", default=0, db_index=True)

    class Meta:
        verbose_name = "Тариф"
        verbose_name_plural = "Тарифы"
        ordering = ["order", "code"]

    def __str__(self) -> str:
        return self.name

    @property
    def is_free(self) -> bool:
        return self.price_bricks_per_month == 0

    @property
    def is_unlimited(self) -> bool:
        return self.listings_limit == 0

    def has_feature(self, code: str) -> bool:
        return bool((self.features or {}).get(code))

    def cost_for(self, months: int) -> int:
        return self.price_bricks_per_month * months


class Subscription(TimeStampedModel):
    """Оплаченный период на тарифе."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        verbose_name="Пользователь",
        on_delete=models.CASCADE,
        related_name="subscriptions",
    )
    tariff = models.ForeignKey(
        Tariff,
        verbose_name="Тариф",
        # Тариф с историей подписок удалять нельзя: пропадёт, за что платили.
        on_delete=models.PROTECT,
        related_name="subscriptions",
    )
    starts_at = models.DateTimeField("Начало")
    ends_at = models.DateTimeField("Окончание", db_index=True)
    is_auto_renew = models.BooleanField("Автопродление", default=True)
    status = models.CharField(
        "Статус",
        max_length=16,
        choices=SubscriptionStatus.choices,
        default=SubscriptionStatus.ACTIVE,
        db_index=True,
    )
    transaction = models.ForeignKey(
        WalletTransaction,
        verbose_name="Операция списания",
        on_delete=models.PROTECT,
        related_name="subscriptions",
        blank=True,
        null=True,
    )
    # Чтобы суточная задача не пыталась продлить одну подписку дважды.
    renewal_attempted_at = models.DateTimeField("Попытка продления", blank=True, null=True)
    # Отметка последнего автоподъёма: фича auto_bump_daily срабатывает раз в сутки.
    auto_bumped_at = models.DateTimeField("Автоподъём", blank=True, null=True)

    class Meta:
        verbose_name = "Подписка"
        verbose_name_plural = "Подписки"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "status", "-ends_at"], name="subscription_user_idx"),
            models.Index(fields=["status", "ends_at"], name="subscription_status_ends_idx"),
        ]
        # Уникального ограничения «одна активная подписка» здесь нет намеренно:
        # переход на более дешёвый тариф создаёт запись, которая начнётся
        # только после окончания текущей, и обе какое-то время активны.
        # Действующей считается та, у которой starts_at уже наступил.

    def __str__(self) -> str:
        return f"{self.user_id} · {self.tariff_id} до {self.ends_at:%d.%m.%Y}"

    @property
    def is_current(self) -> bool:
        return self.status == SubscriptionStatus.ACTIVE and self.ends_at > timezone.now()

    @property
    def days_left(self) -> int:
        remaining = (self.ends_at - timezone.now()).days
        return max(remaining, 0)
