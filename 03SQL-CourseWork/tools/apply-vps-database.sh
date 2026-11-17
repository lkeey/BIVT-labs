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

printf 'All 14 production SQL scripts applied to SocialNetworkDB.\n'
