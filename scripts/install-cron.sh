#!/bin/bash
# Installs crontab jobs: backup.sh (nightly) and send-backup-email.sh (weekly).
# Schedules can be set in .env or via command-line arguments.

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT"

# Load .env to override schedules (optional)
if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

# Default schedules: nightly (backup daily 02:00, email Sunday 03:00)
# Cron format: minute hour day-of-month month day-of-week (0-7 = Sun-Sat)
DEFAULT_BACKUP_CRON="0 2 * * *"
DEFAULT_EMAIL_CRON="0 3 * * 0"

# Override: from .env (BACKUP_CRON_SCHEDULE, BACKUP_EMAIL_CRON_SCHEDULE) or CLI args
BACKUP_SCHEDULE="${1:-${BACKUP_CRON_SCHEDULE:-$DEFAULT_BACKUP_CRON}}"
EMAIL_SCHEDULE="${2:-${BACKUP_EMAIL_CRON_SCHEDULE:-$DEFAULT_EMAIL_CRON}}"

MARKER="# --- Passbolt CE backup (dockers/pass) ---"
BACKUP_LINE="$BACKUP_SCHEDULE cd $PROJECT_ROOT && ./scripts/backup.sh"
EMAIL_LINE="$EMAIL_SCHEDULE cd $PROJECT_ROOT && ./scripts/send-backup-email.sh"

echo "The following cron jobs will be added or updated:"
echo ""
echo "  backup.sh (daily schedule):"
echo "    $BACKUP_LINE"
echo ""
echo "  send-backup-email.sh (weekly schedule):"
echo "    $EMAIL_LINE"
echo ""
echo "Current schedules: backup = $BACKUP_SCHEDULE, email = $EMAIL_SCHEDULE"
echo ""

# Ensure scripts exist
[ -x "$PROJECT_ROOT/scripts/backup.sh" ] || { echo "Error: scripts/backup.sh not found or not executable"; exit 1; }
[ -x "$PROJECT_ROOT/scripts/send-backup-email.sh" ] || { echo "Error: scripts/send-backup-email.sh not found or not executable"; exit 1; }

# Remove old entries for this project from crontab
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

# Append new entries
{
    cat /tmp/crontab_pass_$$.tmp
    echo ""
    echo "$MARKER"
    echo "$BACKUP_LINE"
    echo "$EMAIL_LINE"
} | crontab -
rm -f /tmp/crontab_pass_$$.tmp

echo "Done. Current crontab:"
crontab -l
echo ""
echo "Custom schedules — pass as arguments or set in .env:"
echo "  ./scripts/install-cron.sh '0 2 * * *' '0 3 * * 0'   # backup 02:00 daily, email 03:00 Sun"
echo "  ./scripts/install-cron.sh '0 3 * * *' '0 4 * * 1'   # backup 03:00 daily, email 04:00 Mon"
echo "  In .env: BACKUP_CRON_SCHEDULE, BACKUP_EMAIL_CRON_SCHEDULE"
