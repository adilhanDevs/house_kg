"""Пересчитывает balance_after и сверяет баланс кошелька с суммой операций."""

from django.db import migrations


def forwards(apps, schema_editor):
    Wallet = apps.get_model("billing", "Wallet")
    WalletTransaction = apps.get_model("billing", "WalletTransaction")

    for wallet in Wallet.objects.all().iterator():
        running = 0
        updates = []
        # Идём в хронологическом порядке: баланс после операции — сумма всех
        # предыдущих поступлений и списаний.
        for operation in WalletTransaction.objects.filter(wallet=wallet).order_by(
            "created_at", "pk"
        ):
            running += operation.amount
            if operation.balance_after != running:
                operation.balance_after = running
                updates.append(operation)

        if updates:
            WalletTransaction.objects.bulk_update(updates, ["balance_after"], batch_size=500)

        # Леджер — источник истины: баланс обязан быть суммой операций.
        if wallet.balance != running:
            wallet.balance = running
            wallet.save(update_fields=["balance"])


def backwards(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("billing", "0003_wallet_ledger"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
