#!/bin/bash

# Load variables from the .env file
export $(grep -v '^#' .env | xargs)

# Set the current date and time for file naming and time tracking
START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
START_TIMESTAMP=$(date +%s)  # Start time in seconds
TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
BACKUP_DIR="./backups"
ARCHIVE_FILE="$BACKUP_DIR/pass_$TIMESTAMP.tar.gz"
LOG_FILE="$BACKUP_DIR/pass_$TIMESTAMP.log"
STATUS_FILE="$BACKUP_DIR/status.log"  # Status file
DB_DUMP_FILE="dump_$TIMESTAMP.sql"
DOCKER_VERSION_FILE="$BACKUP_DIR/docker-version.txt"

# Get current directory and build the required paths relative to it
BASE_DIR=$(pwd)
GPG_DIR="$BASE_DIR/gpg"
JWT_DIR="$BASE_DIR/jwt"
DOCKER_PATH="$BASE_DIR"

# Logging function
log() {
    local MESSAGE="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $MESSAGE" | tee -a "$LOG_FILE"
}

# Function to update the status file
update_status() {
    local STATUS="$1"
    echo "$STATUS" > "$STATUS_FILE"
}

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR/jwt"
mkdir -p "$BACKUP_DIR/gpg"

# Start script log
log "Script started."

# Set MySQL password environment variable to avoid prompting
export MYSQL_PWD="$DATASOURCES_DEFAULT_PASSWORD"

# Perform database backup using mysqldump
log "Creating a database backup..."
mysqldump -h "$DATASOURCES_DEFAULT_HOST" -P "$DATASOURCES_DEFAULT_PORT" -u "$DATASOURCES_DEFAULT_USERNAME" "$DATASOURCES_DEFAULT_DATABASE" > "$BACKUP_DIR/$DB_DUMP_FILE"

# Check if mysqldump was successful
if [ $? -ne 0 ]; then
    log "Error: Database backup failed!"
    update_status "Bad"
    exit 1
fi

# Copy the contents of the gpg and jwt folders to the backup directory
log "Copying gpg and jwt folders..."
cp -r "$GPG_DIR"/* "$BACKUP_DIR/gpg/"
cp -r "$JWT_DIR"/* "$BACKUP_DIR/jwt/"

# Check if .env and docker-compose.yaml files exist
if [ ! -f "$DOCKER_PATH/.env" ]; then
    log "Error: .env file not found in $DOCKER_PATH!"
    update_status "Bad"
    exit 1
fi
if [ ! -f "$DOCKER_PATH/docker-compose.yaml" ]; then
    log "Error: docker-compose.yaml file not found in $DOCKER_PATH!"
    update_status "Bad"
    exit 1
fi

# Get Docker version and save it to a file
log "Getting Docker version..."
docker -v > "$DOCKER_VERSION_FILE"

# Check if getting Docker version was successful
if [ $? -ne 0 ]; then
    log "Error: Failed to retrieve Docker version!"
    update_status "Bad"
    exit 1
fi

# Archive all data in a structured format, including .env, docker-compose.yaml, and docker-version.txt
log "Archiving data..."
tar -czf "$ARCHIVE_FILE" \
    -C "$BACKUP_DIR" gpg jwt "$DB_DUMP_FILE" docker-version.txt \
    -C "$DOCKER_PATH" .env docker-compose.yaml

# Check if archiving was successful
if [ $? -eq 0 ]; then
    log "Backup successfully created: $ARCHIVE_FILE"
else
    log "Error: Failed to create the archive!"
    update_status "Bad"
    exit 1
fi

# Remove temporary folders and files
log "Removing temporary folders and files..."
rm -rf "$BACKUP_DIR/gpg" "$BACKUP_DIR/jwt" "$BACKUP_DIR/$DB_DUMP_FILE" "$DOCKER_VERSION_FILE"
log "Temporary folders and files removed."

# Remove old backups based on BACKUP_DAYS variable
if [ -n "$BACKUP_DAYS" ]; then
    log "Removing backups older than $BACKUP_DAYS days..."
    find "$BACKUP_DIR" -type f -name "*.tar.gz" -mtime +$BACKUP_DAYS -exec rm -f {} \;
    log "Old backups removed."
else
    log "BACKUP_DAYS is not set. No old backups removed."
fi

# End script and calculate execution time
END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
END_TIMESTAMP=$(date +%s)  # End time in seconds
EXECUTION_TIME=$((END_TIMESTAMP - START_TIMESTAMP))

log "Script finished."
log "Start time: $START_TIME"
log "End time: $END_TIME"
log "Execution time: $EXECUTION_TIME seconds."

# Update status file with "OK"
update_status "OK"
