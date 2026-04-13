#!/bin/bash
set -e

# Run from project root (script cd's here; can be invoked from any directory)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
cd "$PROJECT_ROOT"

# Load variables from .env
if [ ! -f ".env" ]; then
    echo "Error: .env not found in $PROJECT_ROOT"
    exit 1
fi
set -a
# shellcheck disable=SC1091
source .env
set +a

# Paths (.env overrides defaults)
GPG_DIR="${GPG_DIR:-$PROJECT_ROOT/gpg}"
JWT_DIR="${JWT_DIR:-$PROJECT_ROOT/jwt}"
BACKUP_DAYS="${BACKUP_DAYS:-7}"

# Required database variables
for var in DATASOURCES_DEFAULT_HOST DATASOURCES_DEFAULT_USERNAME DATASOURCES_DEFAULT_PASSWORD DATASOURCES_DEFAULT_DATABASE; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env"
        exit 1
    fi
done

START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
START_TIMESTAMP=$(date +%s)
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
BACKUP_DIR="$PROJECT_ROOT/backups"
ARCHIVE_FILE="$BACKUP_DIR/pass_$TIMESTAMP.tar.gz"
LOG_FILE="$BACKUP_DIR/pass_$TIMESTAMP.log"
STATUS_FILE="$BACKUP_DIR/status.log"
DB_DUMP_FILE="dump_$TIMESTAMP.sql"
DOCKER_VERSION_FILE="$BACKUP_DIR/docker-version.txt"

log() {
    local MESSAGE="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $MESSAGE" | tee -a "$LOG_FILE"
}

update_status() {
    local STATUS="$1"
    echo "$STATUS" > "$STATUS_FILE"
}

mkdir -p "$BACKUP_DIR/gpg" "$BACKUP_DIR/jwt"
log "Script started (project root: $PROJECT_ROOT)."

export MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD"
trap 'unset MYSQL_PWD' EXIT

# Dump via docker exec if DB host matches a running container name (or BACKUP_DB_CONTAINER is set)
DB_CONTAINER=""
if [ -n "${BACKUP_DB_CONTAINER:-}" ]; then
    DB_CONTAINER="$BACKUP_DB_CONTAINER"
elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$DATASOURCES_DEFAULT_HOST"; then
    DB_CONTAINER="$DATASOURCES_DEFAULT_HOST"
fi

log "Creating database backup..."
if [ -n "$DB_CONTAINER" ]; then
    if ! docker exec -e MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD" "$DB_CONTAINER" \
        mysqldump -h 127.0.0.1 -P "${DATASOURCES_DEFAULT_PORT:-3306}" \
        -u "$DATASOURCES_DEFAULT_USERNAME" "$DATASOURCES_DEFAULT_DATABASE" \
        > "$BACKUP_DIR/$DB_DUMP_FILE" 2>/dev/null; then
        log "Error: Database backup failed (docker exec into $DB_CONTAINER)."
        update_status "Bad"
        exit 1
    fi
    log "Database backup done via docker exec ($DB_CONTAINER)."
else
    if ! mysqldump -h "$DATASOURCES_DEFAULT_HOST" -P "${DATASOURCES_DEFAULT_PORT:-3306}" \
        -u "$DATASOURCES_DEFAULT_USERNAME" "$DATASOURCES_DEFAULT_DATABASE" \
        > "$BACKUP_DIR/$DB_DUMP_FILE"; then
        log "Error: Database backup failed! If DB is in Docker, set BACKUP_DB_CONTAINER=<container_name> in .env"
        update_status "Bad"
        exit 1
    fi
fi

# Copy gpg and jwt (including dotfiles; empty dirs stay empty)
log "Copying gpg and jwt folders..."
for src_dir in "$GPG_DIR" "$JWT_DIR"; do
    dir_name=$(basename "$src_dir")
    if [ -d "$src_dir" ]; then
        cp -a "$src_dir"/. "$BACKUP_DIR/$dir_name/" 2>/dev/null || true
    fi
done

# Require .env and docker-compose.yaml
for f in .env docker-compose.yaml; do
    if [ ! -f "$PROJECT_ROOT/$f" ]; then
        log "Error: $f not found in $PROJECT_ROOT"
        update_status "Bad"
        exit 1
    fi
done

# Docker version
log "Getting Docker version..."
if ! docker -v > "$DOCKER_VERSION_FILE" 2>/dev/null; then
    log "Warning: Could not get Docker version (docker not in PATH?). Writing 'unknown'."
    echo "unknown" > "$DOCKER_VERSION_FILE"
fi

# Create archive
log "Archiving data..."
if ! tar -czf "$ARCHIVE_FILE" \
    -C "$BACKUP_DIR" gpg jwt "$DB_DUMP_FILE" docker-version.txt \
    -C "$PROJECT_ROOT" .env docker-compose.yaml; then
    log "Error: Failed to create archive!"
    update_status "Bad"
    exit 1
fi

log "Backup created: $ARCHIVE_FILE"

# Remove temporary files
log "Removing temporary files..."
rm -rf "$BACKUP_DIR/gpg" "$BACKUP_DIR/jwt" "$BACKUP_DIR/$DB_DUMP_FILE" "$DOCKER_VERSION_FILE"

# Prune old backups
if [ -n "$BACKUP_DAYS" ] && [ "$BACKUP_DAYS" -gt 0 ] 2>/dev/null; then
    log "Removing backups older than $BACKUP_DAYS days..."
    find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.tar.gz" -mtime +"$BACKUP_DAYS" -delete
    log "Old backups removed."
else
    log "BACKUP_DAYS not set or invalid. Skipping cleanup."
fi

END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
EXECUTION_TIME=$(($(date +%s) - START_TIMESTAMP))
log "Script finished."
log "Start: $START_TIME, End: $END_TIME, Duration: ${EXECUTION_TIME}s"
update_status "OK"
