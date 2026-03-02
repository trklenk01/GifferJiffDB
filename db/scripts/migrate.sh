#!/usr/bin/env bash
set -eu
set -o pipefail

until pg_isready -h db -U app -d tenorclone; do sleep 1; done

echo "DB ready. Contents of /migrations:"
ls -la /migrations

shopt -s nullglob
files=(/migrations/*.sql)

if [ "${#files[@]}" -eq 0 ]; then
  echo "ERROR: No .sql files found in /migrations. Fix the compose volume mount path." >&2
  exit 1
fi

psql -h db -U app -d tenorclone -v ON_ERROR_STOP=1 -c "
  CREATE TABLE IF NOT EXISTS schema_migrations (
    version text PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
  );
"

if [ -f /migrations/000_migrations.sql ]; then
  echo "Running 000_migrations.sql"
  psql -h db -U app -d tenorclone -v ON_ERROR_STOP=1 -f /migrations/000_migrations.sql
  psql -h db -U app -d tenorclone -v ON_ERROR_STOP=1 \
    -c "INSERT INTO schema_migrations(version) VALUES ('000_migrations.sql') ON CONFLICT DO NOTHING;"
fi

echo "Applying remaining migrations..."
for f in "${files[@]}"; do
  base="$(basename "$f")"
  [ "$base" = "000_migrations.sql" ] && continue

  already="$(psql -h db -U app -d tenorclone -t -A -v ON_ERROR_STOP=1 \
    -c "SELECT 1 FROM schema_migrations WHERE version='$base' LIMIT 1;")"

  if [ "$already" = "1" ]; then
    echo "Skipping $base (already applied)"
    continue
  fi

  echo "Running $base"
  psql -h db -U app -d tenorclone -v ON_ERROR_STOP=1 -f "$f"
  psql -h db -U app -d tenorclone -v ON_ERROR_STOP=1 \
    -c "INSERT INTO schema_migrations(version) VALUES ('$base');"
done

echo "Migrations complete."
