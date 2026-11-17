#!/usr/bin/env bash
# Apply the coursework schema to an Azure SQL Managed Instance public endpoint.
set -euo pipefail

: "${COURSEWORK_SQL_ENDPOINT:?Set COURSEWORK_SQL_ENDPOINT to the MI public FQDN,3342}"
: "${COURSEWORK_SQL_ADMIN:?Set COURSEWORK_SQL_ADMIN}"

if [[ ! -f database/00-create-schemas.sql ]]; then
  printf 'Run this script from the 03SQL-CourseWork directory.\n' >&2
  exit 1
fi
if ! command -v sqlcmd >/dev/null 2>&1; then
  printf 'sqlcmd is not installed.\n' >&2
  exit 1
fi

case "$COURSEWORK_SQL_ENDPOINT" in
  *,3342) ;;
  *)
    printf 'COURSEWORK_SQL_ENDPOINT must end in ,3342.\n' >&2
    exit 1
    ;;
esac

scripts=(database/00-create-schemas.sql database/01-social-nodes.sql
  database/02-content.sql database/03-follow-graph.sql database/04-relational-links.sql
  database/05-audit.sql database/06-indexes.sql database/07-access-views.sql
  database/08-publication.sql database/10-recommendations.sql database/11-demo.sql
  database/12-social-api.sql database/14-authorized-reads.sql database/15-api-reads.sql
  database/17-auth-and-roles.sql)
for script in "${scripts[@]}"; do
  [[ -f "$script" ]] || { printf 'Missing SQL script: %s\n' "$script" >&2; exit 1; }
done

if [[ -z "${SQLCMDPASSWORD:-}" ]]; then
  read -r -s -p 'SQL MI admin password: ' SQLCMDPASSWORD
  printf '\n'
fi
export SQLCMDPASSWORD
trap 'unset SQLCMDPASSWORD' EXIT

# -b fails on SQL errors; -I enables QUOTED_IDENTIFIER; -Nm requires TLS.
# No -C: validate the server certificate.
sqlcmd -S "$COURSEWORK_SQL_ENDPOINT" -d master \
  -U "$COURSEWORK_SQL_ADMIN" -Nm -I -b \
  -Q "IF DB_ID(N'SocialNetworkDB') IS NOT NULL THROW 51904, 'Database exists; use a separate migration.', 1; CREATE DATABASE SocialNetworkDB;"

for script in "${scripts[@]}"; do
  printf 'Applying %s\n' "$script"
  sqlcmd -S "$COURSEWORK_SQL_ENDPOINT" -d SocialNetworkDB \
    -U "$COURSEWORK_SQL_ADMIN" -Nm -I -b -i "$script"
done

printf 'All 15 SQL scripts applied successfully.\n'
