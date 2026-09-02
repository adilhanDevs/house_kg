"""Заводит страницы соглашения и политики ПДн, без которых не работает регистрация.

Экран регистрации показывает галку «принимаю соглашение» со ссылкой на текст и
отправляет версию документа в `/auth/otp/verify/`. Версия сверяется с
`CONSENT_DOCUMENT_VERSION`, а сам текст клиент забирает из
`/app/pages/terms/` — без этих страниц ссылка отдаёт 404.

    python manage.py seed_legal_pages           # создать, существующие не трогать
    python manage.py seed_legal_pages --force   # перезаписать текст

Текст здесь — рабочая заготовка, а не юридический документ. Замените его в
админке («Статические страницы»), и, если правка меняет смысл, поднимите
версию: пользователи будут спрошены заново.
"""

from typing import Any

from django.conf import settings
from django.core.management.base import BaseCommand, CommandParser

from apps.common.models import StaticPage

TERMS = """\
# Пользовательское соглашение

Приложение — площадка для размещения и поиска объявлений о недвижимости
в Кыргызской Республике.

## Регистрация

Аккаунт создаётся по номеру телефона. Номер подтверждается кодом из SMS,
пароль задаётся при регистрации и используется для последующих входов.

## Объявления

Владелец объявления отвечает за достоверность указанных сведений и за то,
что имеет право размещать фотографии и видео объекта. Объявление может быть
снято с публикации по жалобам пользователей или решению модератора.

## Оплата

Платные возможности оплачиваются внутренней валютой приложения. Пополнение
и списания отражаются в истории операций.

## Ответственность

Площадка не является стороной сделки между продавцом и покупателем и не
гарантирует её исход.
"""

PRIVACY = """\
# Согласие на обработку персональных данных

## Какие данные обрабатываются

Номер телефона, имя, фотография профиля, а для исполнителей — ИИН и документы,
подтверждающие личность. Дополнительно сохраняются данные объявлений, история
просмотров и избранное.

## Зачем

Чтобы создать и вести аккаунт, показывать объявления, связывать покупателя
с продавцом, начислять и списывать внутреннюю валюту, отправлять уведомления
о состоянии объявлений.

## Как долго

Пока существует аккаунт. Документы, подтверждающие личность, удаляются после
завершения проверки в срок, установленный внутренним регламентом.

## Права

Вы можете запросить выгрузку своих данных и удаление аккаунта в разделе
профиля. Согласие отзывается удалением аккаунта.
"""

PAGES: dict[str, tuple[str, str]] = {
    StaticPage.Slug.TERMS: ("Пользовательское соглашение", TERMS),
    StaticPage.Slug.PRIVACY: ("Согласие на обработку персональных данных", PRIVACY),
}


class Command(BaseCommand):
    help = "Создаёт страницы соглашения и политики ПДн для экрана регистрации"

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument(
            "--force",
            action="store_true",
            help="Перезаписать текст и версию у уже существующих страниц.",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        force = bool(options["force"])
        version = settings.CONSENT_DOCUMENT_VERSION

        for slug, (title, content) in PAGES.items():
            page = StaticPage.objects.filter(slug=slug).first()

            if page is None:
                StaticPage.objects.create(
                    slug=slug,
                    title=title,
                    content=content,
                    version=version,
                    is_active=True,
                )
                self.stdout.write(self.style.SUCCESS(f"  {slug}: создана (v{version})"))
                continue

            if not force:
                self.stdout.write(f"  {slug}: уже есть (v{page.version}), пропускаю")
                continue

            page.title = title
            page.content = content
            page.version = version
            page.is_active = True
            page.save(update_fields=["title", "content", "version", "is_active", "updated_at"])
            self.stdout.write(self.style.SUCCESS(f"  {slug}: перезаписана (v{version})"))

        self.stdout.write(
            "Версия документов должна совпадать с CONSENT_DOCUMENT_VERSION "
            f"(сейчас {version}) — иначе регистрация отклонит согласие."
        )
