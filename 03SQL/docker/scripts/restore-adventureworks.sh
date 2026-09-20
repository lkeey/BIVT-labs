#!/usr/bin/env bash

set -Eeuo pipefail

readonly SQLCMD="/opt/mssql-tools18/bin/sqlcmd"
readonly SQLSERVER_HOST="${SQLSERVER_HOST:-sqlserver}"
readonly SQLSERVER_PORT="${SQLSERVER_PORT:-1433}"
readonly DATABASE_NAME="${DATABASE_NAME:-AdventureWorksLT2019}"
readonly BACKUP_FILE="/var/opt/mssql/backup/AdventureWorksLT2019.bak"
readonly EXPECTED_DATA_LOGICAL_NAME="AdventureWorksLT2019_Data"
readonly EXPECTED_LOG_LOGICAL_NAME="AdventureWorksLT2019_Log"
readonly DATA_FILE="/var/opt/mssql/data/AdventureWorksLT2019.mdf"
readonly LOG_FILE="/var/opt/mssql/data/AdventureWorksLT2019_log.ldf"

filelist_file=""

log() {
  printf '[db-init] %s\n' "$*"
}

cleanup() {
  if [[ -n "${filelist_file}" && -f "${filelist_file}" ]]; then
    rm -f -- "${filelist_file}"
  fi
}
trap cleanup EXIT

die() {
  printf '[db-init] ERROR: %s\n' "$*" >&2
  exit 1
}

run_sql() {
  "${SQLCMD}" \
    -S "tcp:${SQLSERVER_HOST},${SQLSERVER_PORT}" \
    -U sa \
    -P "${MSSQL_SA_PASSWORD}" \
    -C -b -r1 -l 30 \
    "$@"
}

trimmed_first_line() {
  tr -d '\r' | awk 'NF {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print; exit}'
}

main() {
  local db_state
  local -a data_names log_names

  [[ -x "${SQLCMD}" ]] || die "sqlcmd was not found at ${SQLCMD}."
  [[ -r "${BACKUP_FILE}" && -f "${BACKUP_FILE}" ]] || die "Backup is not readable: ${BACKUP_FILE}."
  [[ -n "${MSSQL_SA_PASSWORD:-}" ]] || die "MSSQL_SA_PASSWORD is not set."
  [[ "${DATABASE_NAME}" == "AdventureWorksLT2019" ]] || die "Unexpected database name: ${DATABASE_NAME}."

  db_state="$(run_sql -h -1 -W -Q "SET NOCOUNT ON; SELECT state_desc FROM sys.databases WHERE name = N'AdventureWorksLT2019';" | trimmed_first_line)"
  if [[ "${db_state}" == "ONLINE" ]]; then
    log "AdventureWorksLT2019 is already ONLINE; restore skipped to preserve lab data."
    exit 0
  fi
  [[ -z "${db_state}" ]] || die \
    "AdventureWorksLT2019 exists in state ${db_state}; refusing to overwrite it."

  log "Verifying the SQL Server backup."
  run_sql -Q "RESTORE VERIFYONLY FROM DISK = N'${BACKUP_FILE}' WITH CHECKSUM;"

  filelist_file="$(mktemp)"
  run_sql -h -1 -W -s '|' -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'${BACKUP_FILE}';" > "${filelist_file}"

  mapfile -t data_names < <(
    awk -F'|' '
      function trim(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
      }
      NF >= 3 && trim($3) == "D" { print trim($1) }
    ' "${filelist_file}"
  )
  mapfile -t log_names < <(
    awk -F'|' '
      function trim(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
      }
      NF >= 3 && trim($3) == "L" { print trim($1) }
    ' "${filelist_file}"
  )

  [[ ${#data_names[@]} -eq 1 && "${data_names[0]}" == "${EXPECTED_DATA_LOGICAL_NAME}" ]] || die \
    "Unexpected data logical files: ${data_names[*]:-(none)}."
  [[ ${#log_names[@]} -eq 1 && "${log_names[0]}" == "${EXPECTED_LOG_LOGICAL_NAME}" ]] || die \
    "Unexpected log logical files: ${log_names[*]:-(none)}."

  log "Restoring AdventureWorksLT2019 with Linux data paths."
  run_sql -Q "
    RESTORE DATABASE [AdventureWorksLT2019]
    FROM DISK = N'${BACKUP_FILE}'
    WITH
      MOVE N'${EXPECTED_DATA_LOGICAL_NAME}' TO N'${DATA_FILE}',
      MOVE N'${EXPECTED_LOG_LOGICAL_NAME}' TO N'${LOG_FILE}',
      RECOVERY,
      STATS = 10;
  "

  db_state="$(run_sql -h -1 -W -Q "SET NOCOUNT ON; SELECT state_desc FROM sys.databases WHERE name = N'AdventureWorksLT2019';" | trimmed_first_line)"
  [[ "${db_state}" == "ONLINE" ]] || die "Restored database state is ${db_state:-missing}, expected ONLINE."

  run_sql -Q "DBCC CHECKDB (N'AdventureWorksLT2019') WITH NO_INFOMSGS;"
  run_sql -Q "SET NOCOUNT ON; SELECT TOP (1) CustomerID FROM AdventureWorksLT2019.SalesLT.Customer ORDER BY CustomerID;"
  log "AdventureWorksLT2019 restore and integrity checks succeeded."
}

main "$@"
