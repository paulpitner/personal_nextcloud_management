#!/bin/bash
# =============================================================================
# Nextcloud Backup Script
# Run inside tmux: tmux new -s nextcloud-backup
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
DATE=$(date +%Y-%m-%d)
NEXTCLOUD_DIR="/mnt/raid5/nextcloud"
BACKUP_ROOT="/mnt/backup"
BACKUP_DIR="${BACKUP_ROOT}/nextcloud"
SQL_BACKUP_FILE="/home/paul/nextcloud-sqlbkp_${DATE}.bak"
DB_HOST="localhost"
DB_USER="nextcloud"
DB_NAME="nextcloud"
OCC_CMD="sudo -u www-data php /var/www/nextcloud/occ"  # adjust path if needed

# --- Helper ------------------------------------------------------------------
log() { echo "[$(date '+%H:%M:%S')] $*"; }

# --- Password prompt ---------------------------------------------------------
read -rsp "Enter database password (hint: Il14!): " DB_PASS
echo

# --- Preflight ---------------------------------------------------------------
log "Starting Nextcloud backup for ${DATE}"

if ! mountpoint -q "${BACKUP_ROOT}"; then
    log "ERROR: Backup drive is not mounted at ${BACKUP_ROOT}. Aborting."
    exit 1
fi

# --- Maintenance mode ON -----------------------------------------------------
log "Enabling maintenance mode..."
${OCC_CMD} maintenance:mode --on

# --- rsync files -------------------------------------------------------------
log "Syncing Nextcloud files to ${BACKUP_DIR} ..."
mkdir -p "${BACKUP_DIR}"
sudo rsync -Aavx --delete --progress "${NEXTCLOUD_DIR}" "${BACKUP_DIR}"
log "File sync complete."

# --- MySQL/MariaDB dump ------------------------------------------------------
log "Dumping database to ${SQL_BACKUP_FILE} ..."
mysqldump --single-transaction \
          -h "${DB_HOST}" \
          -u "${DB_USER}" \
          -p"${DB_PASS}" \
          "${DB_NAME}" > "${SQL_BACKUP_FILE}"
log "Database dump complete."

# --- Move .bak to backup root ------------------------------------------------
log "Moving SQL backup to ${BACKUP_DIR}/ ..."
sudo mv "${SQL_BACKUP_FILE}" "${BACKUP_DIR}/"

# --- Update this script's date log -------------------------------------------
SCRIPT_PATH="$(realpath "$0")"
# Append today's date to the "Previous backups" list inside this script
sed -i "/^# END_BACKUP_LOG/i # ${DATE}" "${SCRIPT_PATH}" 2>/dev/null || true

# --- Maintenance mode OFF ----------------------------------------------------
log "Disabling maintenance mode..."
${OCC_CMD} maintenance:mode --off

log "Backup finished successfully. Files at: ${BACKUP_DIR}"

# --- Previous backup dates (auto-appended) -----------------------------------
# 2025-08-21
# 2025-10-11
# 2025-11-24
# 2026-01-07
# 2026-02-09
# 2026-03-24
# 2026-04-25
# 2026-04-25
# END_BACKUP_LOG
