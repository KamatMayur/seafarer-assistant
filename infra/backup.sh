#!/usr/bin/env sh
# Nightly encrypted database backup. Cron example (host):
#   15 2 * * *  cd /srv/seafarer-assistant && BACKUP_PASSPHRASE_FILE=/root/.sa-backup-pass infra/backup.sh
# Restore: gpg -d FILE.sql.gz.gpg | gunzip | docker compose -f infra/docker-compose.yml exec -T db psql -U seafarer seafarer
set -eu
: "${BACKUP_PASSPHRASE_FILE:?set BACKUP_PASSPHRASE_FILE}"
DEST="${BACKUP_DIR:-/var/backups/seafarer-assistant}"
KEEP_DAYS="${KEEP_DAYS:-14}"
mkdir -p "$DEST"
OUT="$DEST/seafarer-$(date +%Y%m%d-%H%M%S).sql.gz.gpg"
docker compose -f "$(dirname "$0")/docker-compose.yml" exec -T db pg_dump -U seafarer --no-owner seafarer \
  | gzip -9 \
  | gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase-file "$BACKUP_PASSPHRASE_FILE" -o "$OUT"
find "$DEST" -name 'seafarer-*.sql.gz.gpg' -mtime +"$KEEP_DAYS" -delete
echo "backup written: $OUT"
