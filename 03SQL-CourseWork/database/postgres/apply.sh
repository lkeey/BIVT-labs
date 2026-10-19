#!/usr/bin/env bash
set -euo pipefail

# libpq reads PGHOST, PGPORT, PGUSER, PGDATABASE, PGPASSWORD/PGPASSFILE,
# and PGSSLMODE from the environment; no credential appears in argv.
for setting in PGHOST PGUSER PGDATABASE; do
  if [[ -z "${!setting:-}" ]]; then
    printf 'Set %s before applying PostgreSQL migrations.\n' "$setting" >&2
    exit 2
  fi
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
migration_args=()
for migration in "$script_dir"/[0-9][0-9]-*.sql; do
  printf 'Applying %s\n' "$(basename -- "$migration")"
  migration_args+=(-f "$migration")
done
psql -X -v ON_ERROR_STOP=1 --single-transaction "${migration_args[@]}"
