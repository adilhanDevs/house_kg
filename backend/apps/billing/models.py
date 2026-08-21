"""Кошелёк во внутренней валюте («кирпичи») и неизменяемый леджер операций."""

from typing import Any

from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.db import models

from apps.common.enums import WalletEntryKind
from apps.common.models import TimeStampedModel

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
    related_object_id = models.PositiveBigIntegerField("ID объекта", blank=True, null=True)
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
