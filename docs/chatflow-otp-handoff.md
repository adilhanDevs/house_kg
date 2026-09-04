# WhatsApp OTP: состояние на 4 сентября 2026

В backend добавлен провайдер `SMS_PROVIDER=chatflow` по реализации
`Safa-app-backend/apps/users/chatflow.py`. Поддержаны Flow ID API и legacy
instance ID API. Генерация, хеширование, срок действия и проверка OTP
используют существующие сервисы House KG.

## Деплой

- Репозиторий сервера: `adilhanDevs/house-backend`, ветка `main`.
- Коммит интеграции в серверном репозитории: `7b57306`.
- Production: `root@139.59.224.34`, `/root/house-backend`.
- Код развернут; `gunicorn` перезапущен. Django check, 15 тестов Chatflow,
  health-check и каталог прошли проверку на сервере.
- На момент деплоя `SMS_PROVIDER=telegram`, `DEBUG=False`,
  `CELERY_TASK_ALWAYS_EAGER=True`. Отдельного Celery worker нет:
  OTP-задачи выполняются в процессе backend.

## Следующий шаг

WhatsApp ещё не активирован: на сервере отсутствуют `CHATFLOW_TOKEN` и
`CHATFLOW_FLOW_ID` (также отсутствует legacy `CHATFLOW_INSTANCE_ID`).
После получения реквизитов задайте их в окружении сервера вместе с
`SMS_PROVIDER=chatflow` и перезапустите `gunicorn`. Не копируйте ключи в git.
Подробные настройки находятся в `backend/README.md` и `backend/.env.example`.

Реальная отправка WhatsApp не проверялась. После настройки запросите OTP
на согласованный тестовый номер, получите сообщение и проверьте код.
При `DEBUG=True` и для `OTP_TEST_PHONES` реальная отправка отключена.

Перед SSH используйте `backend/scripts/check_production_host.sh`.
Локально проверены 62 теста Chatflow, SMS, OTP throttling и Telegram Gateway,
а также Ruff. В локальной `.venv` нет pytest-cov, поэтому для целевого
прогона использовался `pytest -o addopts=''`.
