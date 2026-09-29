#!/usr/bin/env bash
# Nightly Expat8 backup: PostgreSQL dump + uploaded release APKs.
# Run on the production host from cron (see docs/ops/backup-restore.md).
#
# Environment (defaults match ~/deployment/worker-z440):
#   DEPLOY_DIR      compose project directory      (~/deployment/worker-z440)
#   PG_SERVICE      compose service running Postgres (postgres)
#   PG_USER         database user                   (required)
#   PG_DB           Expat8 database name            (required)
#   BACKUP_DIR      where backups are written       (~/backups/expat8)
#   RETENTION_DAYS  delete backups older than this  (14)
#   RELEASES_VOLUME docker volume with release APKs ("" to skip)
#                   (worker-z440_expat8-releases)
set -euo pipefail

DEPLOY_DIR=${DEPLOY_DIR:-$HOME/deployment/worker-z440}
PG_SERVICE=${PG_SERVICE:-postgres}
PG_USER=${PG_USER:?PG_USER is required}
PG_DB=${PG_DB:?PG_DB is required}
BACKUP_DIR=${BACKUP_DIR:-$HOME/backups/expat8}
RETENTION_DAYS=${RETENTION_DAYS:-14}
RELEASES_VOLUME=${RELEASES_VOLUME-worker-z440_expat8-releases}

stamp=$(date -u +%Y%m%d-%H%M)
mkdir -p "$BACKUP_DIR"
dump="$BACKUP_DIR/expat8-db-$stamp.dump"
trap 'rm -f "$dump.partial"' ERR

# Dump straight from the Postgres container (not pgbouncer).
docker compose --project-directory "$DEPLOY_DIR" exec -T "$PG_SERVICE" \
  pg_dump -U "$PG_USER" -Fc "$PG_DB" > "$dump.partial"

# A dump pg_restore cannot list is corrupt; keep the old backups and fail.
tables=$(docker compose --project-directory "$DEPLOY_DIR" exec -T "$PG_SERVICE" \
  pg_restore --list < "$dump.partial" | grep -c 'TABLE DATA' || true)
if [ "${tables:-0}" -lt 10 ]; then
  echo "backup: dump looks wrong (only ${tables:-0} tables)" >&2
  rm -f "$dump.partial"
  exit 1
fi
mv "$dump.partial" "$dump"
echo "backup: $dump ($(du -h "$dump" | cut -f1), $tables tables)"

if [ -n "$RELEASES_VOLUME" ]; then
  releases="$BACKUP_DIR/expat8-releases-$stamp.tar.gz"
  docker run --rm -v "$RELEASES_VOLUME":/data:ro -v "$BACKUP_DIR":/backup alpine \
    tar czf "/backup/$(basename "$releases")" -C /data .
  echo "backup: $releases ($(du -h "$releases" | cut -f1))"
fi

find "$BACKUP_DIR" -maxdepth 1 -name 'expat8-*' -mtime +"$RETENTION_DAYS" -print -delete
