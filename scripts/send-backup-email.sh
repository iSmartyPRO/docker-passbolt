#!/bin/bash
set -e

# Переход в корень проекта
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT"

if [ ! -f ".env" ]; then
    echo "Error: .env not found in $PROJECT_ROOT"
    exit 1
fi
set -a
source .env
set +a

# Получатель — обязательно в .env
BACKUP_EMAIL_TO="${BACKUP_EMAIL_TO:-}"
if [ -z "$BACKUP_EMAIL_TO" ]; then
    echo "Error: BACKUP_EMAIL_TO is not set in .env (e.g. BACKUP_EMAIL_TO=admin@example.com)"
    exit 1
fi

# Путь к каталогу бэкапов
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Error: Backup directory not found: $BACKUP_DIR (run backup.sh first)"
    exit 1
fi
LATEST=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
    echo "Error: No .tar.gz backup found in $BACKUP_DIR (run backup.sh first)"
    exit 1
fi

BACKUP_FILE="$LATEST"
BACKUP_NAME=$(basename "$BACKUP_FILE")
# Дата модификации файла (Linux: stat, BSD/macOS: date -r)
BACKUP_DATE=$(stat -c '%y' "$BACKUP_FILE" 2>/dev/null | cut -c1-16 || date -r "$BACKUP_FILE" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "")

# Проверка переменных SMTP (те же, что для Passbolt)
for var in EMAIL_TRANSPORT_DEFAULT_HOST EMAIL_DEFAULT_FROM; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

SMTP_HOST="${EMAIL_TRANSPORT_DEFAULT_HOST}"
SMTP_PORT="${EMAIL_TRANSPORT_DEFAULT_PORT:-587}"
SMTP_USER="${EMAIL_TRANSPORT_DEFAULT_USERNAME:-}"
SMTP_PASS="${EMAIL_TRANSPORT_DEFAULT_PASSWORD:-}"
USE_TLS="${EMAIL_TRANSPORT_DEFAULT_TLS:-true}"
# Отключить проверку SSL (для самоподписанных сертификатов), как в Passbolt
SSL_VERIFY="${PASSBOLT_PLUGINS_SMTP_SETTINGS_SECURITY_SSL_VERIFY_PEER:-true}"
FROM_NAME="${EMAIL_DEFAULT_FROM_NAME:-Passbolt Backup}"
FROM_ADDR="${EMAIL_DEFAULT_FROM}"

export BACKUP_FILE BACKUP_NAME BACKUP_DATE BACKUP_EMAIL_TO
export SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS USE_TLS SSL_VERIFY FROM_NAME FROM_ADDR

python3 << 'PYTHON'
import os
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

backup_file = os.environ["BACKUP_FILE"]
backup_name = os.environ["BACKUP_NAME"]
backup_date = os.environ.get("BACKUP_DATE", "")
to_addr = os.environ["BACKUP_EMAIL_TO"]
smtp_host = os.environ["SMTP_HOST"]
smtp_port = int(os.environ.get("SMTP_PORT", "587"))
smtp_user = os.environ.get("SMTP_USER", "")
smtp_pass = os.environ.get("SMTP_PASS", "")
use_tls = os.environ.get("USE_TLS", "true").lower() in ("true", "1", "yes")
ssl_verify = os.environ.get("SSL_VERIFY", "true").lower() in ("true", "1", "yes")
from_name = os.environ.get("FROM_NAME", "Passbolt Backup")
from_addr = os.environ["FROM_ADDR"]

def ssl_context():
    ctx = ssl.create_default_context()
    if not ssl_verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    return ctx

msg = MIMEMultipart()
msg["Subject"] = f"Passbolt backup: {backup_name}"
msg["From"] = f"{from_name} <{from_addr}>"
msg["To"] = to_addr

body = f"Last Passbolt backup as attachment.\n\nFile: {backup_name}\n"
if backup_date:
    body += f"Created: {backup_date}\n"
msg.attach(MIMEText(body, "plain"))

with open(backup_file, "rb") as f:
    part = MIMEBase("application", "gzip")
    part.set_payload(f.read())
encoders.encode_base64(part)
part.add_header("Content-Disposition", "attachment", filename=backup_name)
msg.attach(part)

if smtp_port == 465:
    with smtplib.SMTP_SSL(smtp_host, smtp_port, context=ssl_context()) as server:
        if smtp_user and smtp_pass:
            server.login(smtp_user, smtp_pass)
        server.sendmail(from_addr, [to_addr], msg.as_string())
else:
    with smtplib.SMTP(smtp_host, smtp_port) as server:
        if use_tls:
            server.starttls(context=ssl_context())
        if smtp_user and smtp_pass:
            server.login(smtp_user, smtp_pass)
        server.sendmail(from_addr, [to_addr], msg.as_string())
PYTHON

echo "Backup sent to $BACKUP_EMAIL_TO: $BACKUP_NAME"
