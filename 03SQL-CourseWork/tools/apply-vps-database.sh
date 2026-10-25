#!/usr/bin/env bash
# Initialize SocialNetworkDB on the local SQL Server 2025 Express instance.
set -euo pipefail

if [[ ! -f database/00-create-schemas.sql ]]; then
  printf 'Run this script from the 03SQL-CourseWork directory.\n' >&2
  exit 1
fi
if ! command -v sqlcmd >/dev/null 2>&1; then
  printf 'sqlcmd is not installed.\n' >&2
  exit 1
fi

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
if [[ "${scripts[11]}" != database/11-demo.sql ]]; then
  printf 'Refusing to deploy: script 11 must be the optional demo seed.\n' >&2
  exit 1
fi

if [[ -z "${SQLCMDPASSWORD:-}" ]]; then
  if [[ ! -t 0 ]]; then
    printf 'Set SQLCMDPASSWORD or run in an interactive terminal.\n' >&2
    exit 1
  fi
  read -r -s -p 'Local SQL Server sa password: ' SQLCMDPASSWORD
  printf '\n'
fi
export SQLCMDPASSWORD
trap 'unset SQLCMDPASSWORD' EXIT

# No -C: the local SQL Server certificate must validate for localhost.
# -Nm requires TLS; -b makes SQL errors fail the shell script.
sqlcmd -S localhost -d master -U sa -Nm -I -b -Q "
SET NOCOUNT ON;
IF TRY_CONVERT(int, SERVERPROPERTY('ProductMajorVersion')) <> 17
    THROW 51900, 'SQL Server 2025 (major version 17) is required.', 1;
IF CONVERT(nvarchar(128), SERVERPROPERTY('Edition')) NOT LIKE N'%Express%'
    THROW 51901, 'SQL Server Express edition is required for this VPS recipe.', 1;
IF FULLTEXTSERVICEPROPERTY('IsFullTextInstalled') <> 1
    THROW 51902, 'Install mssql-server-fts before applying the schema.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.fulltext_languages WHERE lcid = 1049)
    THROW 51903, 'Russian full-text language (LCID 1049) is required.', 1;
IF DB_ID(N'SocialNetworkDB') IS NOT NULL
    THROW 51904, 'SocialNetworkDB already exists; inspect it before another deployment.', 1;
"
sqlcmd -S localhost -d master -U sa -Nm -I -b \
  -Q "CREATE DATABASE SocialNetworkDB;"

for script in "${scripts[@]}"; do
  if [[ "$script" == database/11-demo.sql ]]; then
    printf 'Skipping optional demo seed %s\n' "$script"
    continue
  fi
  printf 'Applying %s\n' "$script"
  sqlcmd -S localhost -d SocialNetworkDB -U sa -Nm -I -b -i "$script"
done

printf 'All 17 production SQL scripts applied to SocialNetworkDB.\n'
