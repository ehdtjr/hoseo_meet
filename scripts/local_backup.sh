#!/usr/bin/env bash
# Stop writers first so DB and media describe the same snapshot.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
backup_dir=${1:?Usage: scripts/local_backup.sh /absolute/new-backup-dir}
mkdir "$backup_dir"
backup_dir=$(cd "$backup_dir" && pwd)
restart_writers() { docker compose start web celery-worker celery-beat admin >/dev/null; }
trap restart_writers EXIT
docker compose stop admin web celery-worker celery-beat
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$backup_dir/db.dump"
docker compose run --rm --no-deps -T web tar -C /data/media -czf - . > "$backup_dir/media.tar.gz"
# SECRET_KEY is needed to preserve existing signed media URLs.
cp .env "$backup_dir/local.env"
(cd "$backup_dir" && sha256sum db.dump media.tar.gz > SHA256SUMS)
printf 'Backup written to %s (contains credentials; keep private).\n' "$backup_dir"
