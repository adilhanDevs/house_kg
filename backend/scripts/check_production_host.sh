#!/usr/bin/env bash
# Проверка перед любой SSH-операцией с продакшеном House KG: секретом,
# деплоем, миграцией. Один хардкод правильного хоста в одном месте — так,
# чтобы "единственный сконфигурированный SSH-алиас" никогда больше не
# сходил за продакшен по умолчанию.
#
# См. docs/audits/house-product-risk-audit-2026-09.md, PRODUCTION HOST CONFIG:
# в этой самой сессии запрос отправить Firebase-секрет чуть не ушёл на
# несвязанный хост mtl-server (147.182.243.58) только потому, что это был
# единственный алиас в ~/.ssh/config. Спасло только то, что порт 22 туда
# оказался заблокирован на уровне песочницы — не проверка в процессе.
#
# Использование:
#   backend/scripts/check_production_host.sh <host-или-IP>
#   ssh $(backend/scripts/check_production_host.sh 139.59.224.34) '...'
#
# Код возврата 0 и хост на stdout — если совпал с каноническим.
# Код возврата 1 и ничего на stdout — если нет. Никогда не глотать код
# возврата этого скрипта в деплойном пайплайне.
set -euo pipefail

readonly HOUSE_PRODUCTION_HOST="139.59.224.34"

if [[ $# -ne 1 ]]; then
  echo "usage: $(basename "$0") <host-or-ip>" >&2
  exit 2
fi

target="$1"

if [[ "$target" == "$HOUSE_PRODUCTION_HOST" ]]; then
  echo "$target"
  exit 0
fi

cat >&2 <<EOF
REFUSED: "$target" is not the canonical House production host.

Canonical House production host: $HOUSE_PRODUCTION_HOST
(root@$HOUSE_PRODUCTION_HOST, path /root/house-backend — see
docs/superpowers/plans/*.md for deploy commands)

If "$target" really is production, update HOUSE_PRODUCTION_HOST in this
script deliberately — do not bypass this check for a one-off run. If it
is any other host (a personal server, an SSH alias found by accident,
anything not in this project's own docs), it is not House production;
do not send secrets, deploy, or run migrations against it.
EOF
exit 1
