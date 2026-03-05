#!/bin/bash
# Добавляет в crontab задачи: backup.sh (ежедневно ночью) и send-backup-email.sh (раз в неделю ночью).
# Расписание можно задать в .env или аргументами командной строки.

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT"

# Загрузка .env для переопределения расписания (опционально)
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Расписание по умолчанию: ночью (backup — каждый день 02:00, email — воскресенье 03:00)
# Формат cron: минута час день_месяца месяц день_недели (0-7 = вс-сб)
DEFAULT_BACKUP_CRON="0 2 * * *"
DEFAULT_EMAIL_CRON="0 3 * * 0"

# Переопределение: из .env (BACKUP_CRON_SCHEDULE, BACKUP_EMAIL_CRON_SCHEDULE) или из аргументов
BACKUP_SCHEDULE="${1:-${BACKUP_CRON_SCHEDULE:-$DEFAULT_BACKUP_CRON}}"
EMAIL_SCHEDULE="${2:-${BACKUP_EMAIL_CRON_SCHEDULE:-$DEFAULT_EMAIL_CRON}}"

MARKER="# --- Passbolt CE backup (dockers/pass) ---"
BACKUP_LINE="$BACKUP_SCHEDULE cd $PROJECT_ROOT && ./scripts/backup.sh"
EMAIL_LINE="$EMAIL_SCHEDULE cd $PROJECT_ROOT && ./scripts/send-backup-email.sh"

echo "Будут добавлены/обновлены задачи cron:"
echo ""
echo "  backup.sh (ежедневно ночью):"
echo "    $BACKUP_LINE"
echo ""
echo "  send-backup-email.sh (раз в неделю ночью):"
echo "    $EMAIL_LINE"
echo ""
echo "Текущее расписание: backup = $BACKUP_SCHEDULE, email = $EMAIL_SCHEDULE"
echo ""

# Проверка наличия скриптов
[ -x "$PROJECT_ROOT/scripts/backup.sh" ] || { echo "Error: scripts/backup.sh not found or not executable"; exit 1; }
[ -x "$PROJECT_ROOT/scripts/send-backup-email.sh" ] || { echo "Error: scripts/send-backup-email.sh not found or not executable"; exit 1; }

# Удалить старые записи этого проекта из crontab
current=$(crontab -l 2>/dev/null) || true
> /tmp/crontab_pass_$$.tmp
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        *"$PROJECT_ROOT"*scripts/backup.sh*) continue ;;
        *"$PROJECT_ROOT"*scripts/send-backup-email.sh*) continue ;;
        "# --- Passbolt CE backup"*) continue ;;
    esac
    printf '%s\n' "$line" >> /tmp/crontab_pass_$$.tmp
done <<< "$current"

# Добавить новые записи
{
    cat /tmp/crontab_pass_$$.tmp
    echo ""
    echo "$MARKER"
    echo "$BACKUP_LINE"
    echo "$EMAIL_LINE"
} | crontab -
rm -f /tmp/crontab_pass_$$.tmp

echo "Готово. Текущий crontab:"
crontab -l
echo ""
echo "Другое расписание — аргументами или в .env:"
echo "  ./scripts/install-cron.sh '0 2 * * *' '0 3 * * 0'   # backup 02:00 ежедневно, email 03:00 вс"
echo "  ./scripts/install-cron.sh '0 3 * * *' '0 4 * * 1'   # backup 03:00 ежедневно, email 04:00 пн"
echo "  В .env: BACKUP_CRON_SCHEDULE, BACKUP_EMAIL_CRON_SCHEDULE"
