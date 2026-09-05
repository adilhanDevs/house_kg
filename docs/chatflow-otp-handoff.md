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

## Обновление: 4 сентября 2026 — диагностика на проде

`SMS_PROVIDER=chatflow`, `CHATFLOW_TOKEN` и `CHATFLOW_FLOW_ID` заданы на
сервере. Каждая попытка `POST /auth/otp/request/` уходит в Celery-задачу
`send_otp_sms`, но реальная отправка падает после 4 попыток:
`OtpDeliveryError('Chatflow вернул HTTP 404.')` (см. `apps/users/sms.py:451`).

Прямой запрос к `https://app.chatflow.kz/api/v1/n8n/action/text` с текущими
токеном и flow_id с сервера возвращает:

```
HTTP 404: {"success":false,"message":"Flow ID not found"}
```

Код соответствует эталонной реализации 1:1 (Bearer-токен + `flow_id` /
`recipient` / `msg`, `app.chatflow.kz`). Проблема не в коде: значение
`CHATFLOW_FLOW_ID`, сохранённое в `.env` на проде, не существует в аккаунте
Chatflow, к которому привязан `CHATFLOW_TOKEN`. Вероятная причина — Flow ID
скопирован не из той n8n-интеграции/не из того workspace, либо поток был
удалён/переименован после того, как ID был получен.

**Побочный эффект:** `/auth/otp/request/` при этом возвращает `200` клиенту,
хотя реальная отправка молча проваливается — пользователь получает "успех"
без сообщения в WhatsApp.

## Следующий шаг

Нужно зайти в **app.chatflow.kz** (тем же аккаунтом, что и `CHATFLOW_TOKEN`),
открыть n8n-интеграцию для WhatsApp-канала и скопировать актуальный Flow ID.
Обновить `CHATFLOW_FLOW_ID` в `.env` на сервере и перезапустить `gunicorn`.
Не копируйте ключи в git. Подробные настройки находятся в `backend/README.md`
и `backend/.env.example`.

Реальная отправка WhatsApp всё ещё не проверена end-to-end. После обновления
Flow ID запросите OTP на согласованный тестовый номер, получите сообщение и
проверьте код. При `DEBUG=True` и для `OTP_TEST_PHONES` реальная отправка
отключена.

Перед SSH используйте `backend/scripts/check_production_host.sh`.
Локально проверены 62 теста Chatflow, SMS, OTP throttling и Telegram Gateway,
а также Ruff. В локальной `.venv` нет pytest-cov, поэтому для целевого
прогона использовался `pytest -o addopts=''`.
