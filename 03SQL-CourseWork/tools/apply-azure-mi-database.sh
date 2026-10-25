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

scripts=(database/[0-1][0-9]-*.sql)
if [[ ${#scripts[@]} -ne 18 ]]; then
  printf 'Expected 18 numbered SQL scripts; found %s.\n' "${#scripts[@]}" >&2
  exit 1
fi
for number in {00..17}; do
  if [[ "${scripts[10#$number]}" != database/"$number"-*.sql ]]; then
    printf 'SQL script %s is missing or out of order.\n' "$number" >&2
    exit 1
  fi
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
  -Q "IF DB_ID(N'SocialNetworkDB') IS NULL CREATE DATABASE SocialNetworkDB;"

for script in "${scripts[@]}"; do
  printf 'Applying %s\n' "$script"
  sqlcmd -S "$COURSEWORK_SQL_ENDPOINT" -d SocialNetworkDB \
    -U "$COURSEWORK_SQL_ADMIN" -Nm -I -b -i "$script"
done

printf 'All 18 SQL scripts applied successfully.\n'
