#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LAB_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${LAB_DIR}/.env"
readonly CACHE_DIR="${LAB_DIR}/.cache"
readonly BACKUP_FILE="${CACHE_DIR}/AdventureWorksLT2019.bak"
readonly BACKUP_URL="https://github.com/microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksLT2019.bak"
readonly BACKUP_SIZE="8511488"
readonly BACKUP_SHA256="a15724450505b5e344293e7470be2f1da115601acb5709e9cafbbfb76259a78b"
readonly MIN_FREE_KIB=$((10 * 1024 * 1024))
readonly DOCKER_RAW_SOCKET="${HOME}/Library/Containers/com.docker.docker/Data/docker.raw.sock"

download_tmp=""

log() {
  printf '[sql-server-lab] %s\n' "$*"
}

die() {
  printf '[sql-server-lab] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${download_tmp}" && -f "${download_tmp}" ]]; then
    rm -f -- "${download_tmp}"
  fi
}
trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

docker_engine() {
  docker --host "unix://${DOCKER_RAW_SOCKET}" "$@"
}

compose() {
  docker_engine compose --project-directory "${LAB_DIR}" --env-file "${ENV_FILE}" "$@"
}

file_size() {
  wc -c < "$1" | tr -d '[:space:]'
}

file_sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

verify_backup() {
  local path="$1"
  local actual_size actual_sha

  actual_size="$(file_size "${path}")"
  [[ "${actual_size}" == "${BACKUP_SIZE}" ]] || die \
    "Backup size mismatch for ${path}: expected ${BACKUP_SIZE}, got ${actual_size}."

  actual_sha="$(file_sha256 "${path}")"
  [[ "${actual_sha}" == "${BACKUP_SHA256}" ]] || die \
    "Backup SHA-256 mismatch for ${path}: expected ${BACKUP_SHA256}, got ${actual_sha}."
}

create_env_if_needed() {
  local password

  if [[ ! -e "${ENV_FILE}" ]]; then
    umask 077
    password="SqlLab!Aa1$(openssl rand -hex 16)"
    printf 'MSSQL_SA_PASSWORD=%s\n' "${password}" > "${ENV_FILE}"
    log "Created ${ENV_FILE} with a generated SA password."
  fi

  [[ -f "${ENV_FILE}" && ! -L "${ENV_FILE}" ]] || die "${ENV_FILE} must be a regular, non-symlink file."
  chmod 600 "${ENV_FILE}"

  password="$(awk -F= '/^MSSQL_SA_PASSWORD=/{sub(/^[^=]*=/, ""); print; exit}' "${ENV_FILE}" | tr -d '\r')"
  [[ ${#password} -ge 8 ]] || die "MSSQL_SA_PASSWORD in .env must contain at least 8 characters."
  [[ "${password}" =~ [[:upper:]] ]] || die "MSSQL_SA_PASSWORD needs an uppercase character."
  [[ "${password}" =~ [[:lower:]] ]] || die "MSSQL_SA_PASSWORD needs a lowercase character."
  [[ "${password}" =~ [[:digit:]] ]] || die "MSSQL_SA_PASSWORD needs a digit."
  [[ "${password}" =~ [^[:alnum:]] ]] || die "MSSQL_SA_PASSWORD needs a symbol."
}

check_host_prerequisites() {
  local available_kib emulated_arch existing_container host_arch image_arch image_id

  for command_name in curl docker lsof openssl shasum; do
    require_command "${command_name}"
  done

  [[ -S "${DOCKER_RAW_SOCKET}" ]] || die "Docker Desktop raw engine socket is unavailable. Start Docker Desktop and retry."
  docker_engine compose version >/dev/null 2>&1 || die "Docker Compose v2 is unavailable."
  docker_engine info >/dev/null 2>&1 || die "Docker Desktop is not running. Start it and retry."

  available_kib="$(df -Pk "${LAB_DIR}" | awk 'NR == 2 {print $4}')"
  [[ "${available_kib}" =~ ^[0-9]+$ ]] || die "Unable to determine free disk space."
  (( available_kib >= MIN_FREE_KIB )) || die \
    "At least 10 GiB free disk space is required; only $((available_kib / 1024 / 1024)) GiB is available."

  host_arch="$(uname -m)"
  if [[ "${host_arch}" == "arm64" ]]; then
    /usr/bin/arch -x86_64 /usr/bin/true >/dev/null 2>&1 || die \
      "Rosetta 2 is required. Install it with: softwareupdate --install-rosetta"
    log "Apple Silicon detected. SQL Server runs through unsupported amd64 emulation."
  fi

  existing_container="$(compose ps -a -q sqlserver 2>/dev/null || true)"
  if [[ -n "${existing_container}" ]]; then
    image_id="$(docker_engine inspect --format '{{.Image}}' "${existing_container}")"
    image_arch="$(docker_engine image inspect --format '{{.Architecture}}' "${image_id}")"
    [[ "${image_arch}" == "amd64" ]] || die "Existing SQL Server image architecture is ${image_arch}, expected amd64."
    log "Existing SQL Server container uses the verified amd64 image."
  else
    emulated_arch="$(docker_engine run --rm --platform linux/amd64 busybox:1.36.1 uname -m 2>/dev/null)" || die \
      "Docker cannot run linux/amd64 containers. Select Apple Virtualization Framework and enable Rosetta in Docker Desktop."
    [[ "${emulated_arch}" == "x86_64" ]] || die "Expected amd64 emulation to report x86_64, got ${emulated_arch}."
  fi
}

check_port_ownership() {
  local container_id health listener published

  listener="$(lsof -nP -iTCP:1433 -sTCP:LISTEN 2>/dev/null || true)"
  [[ -n "${listener}" ]] || return 0

  container_id="$(compose ps -a -q sqlserver 2>/dev/null || true)"
  [[ -n "${container_id}" ]] || die "Port 1433 is already used by a process outside this Compose project."

  published="$(docker_engine port "${container_id}" 1433/tcp 2>/dev/null || true)"
  [[ "${published}" == *"127.0.0.1:1433"* ]] || die \
    "Port 1433 is listening, but it is not owned by this project's loopback SQL Server mapping."

  health="$(docker_engine inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_id}")"
  if [[ "${health}" == "unhealthy" ]]; then
    log "Port 1433 belongs to this project, but SQL Server is unhealthy; attempting one restart."
    compose restart --timeout 10 sqlserver || {
      compose ps -a >&2 || true
      compose logs --no-color --tail 120 sqlserver >&2 || true
      die "Unable to restart the unhealthy SQL Server container."
    }
  else
    log "Port 1433 is already owned by this Compose project; continuing idempotently."
  fi
}

prepare_backup() {
  mkdir -p -- "${CACHE_DIR}"

  if [[ -e "${BACKUP_FILE}" ]]; then
    [[ -f "${BACKUP_FILE}" && ! -L "${BACKUP_FILE}" ]] || die \
      "${BACKUP_FILE} must be a regular, non-symlink file."
    verify_backup "${BACKUP_FILE}"
    log "Using the verified cached AdventureWorksLT2019 backup."
    return 0
  fi

  download_tmp="$(mktemp "${BACKUP_FILE}.tmp.XXXXXX")"
  log "Downloading AdventureWorksLT2019 from the official Microsoft sample release."
  curl --fail --location --retry 3 --retry-all-errors --silent --show-error \
    --output "${download_tmp}" "${BACKUP_URL}"
  verify_backup "${download_tmp}"
  chmod 0644 "${download_tmp}"
  mv -- "${download_tmp}" "${BACKUP_FILE}"
  download_tmp=""
  log "Backup download and SHA-256 verification succeeded."
}

wait_for_sqlserver() {
  local attempt container_id health

  container_id="$(compose ps -a -q sqlserver)"
  [[ -n "${container_id}" ]] || die "SQL Server container was not created."

  for attempt in $(seq 1 60); do
    health="$(docker_engine inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_id}")"
    case "${health}" in
      healthy)
        log "SQL Server is healthy."
        return 0
        ;;
      exited|dead)
        compose ps -a >&2 || true
        compose logs --no-color --tail 120 sqlserver >&2 || true
        die "SQL Server stopped before becoming healthy."
        ;;
    esac
    sleep 5
  done

  compose ps -a >&2 || true
  compose logs --no-color --tail 120 sqlserver >&2 || true
  die "SQL Server did not become healthy within 5 minutes."
}

verify_database() {
  compose exec -T sqlserver /bin/bash -lc \
    '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b -W -Q "SET NOCOUNT ON; SELECT @@VERSION; SELECT state_desc FROM sys.databases WHERE name = N'\''AdventureWorksLT2019'\''; SELECT TOP (1) CustomerID FROM AdventureWorksLT2019.SalesLT.Customer ORDER BY CustomerID;"'
}

main() {
  cd -- "${LAB_DIR}"
  create_env_if_needed
  check_host_prerequisites
  compose config --quiet
  check_port_ownership
  prepare_backup

  log "Starting SQL Server 2019."
  compose up -d sqlserver
  wait_for_sqlserver

  log "Restoring AdventureWorksLT2019 when necessary."
  compose run --rm db-init
  verify_database

  log "Setup completed. Connect to 127.0.0.1,1433 with SQL Login 'sa'."
  log "The generated password is stored in ${ENV_FILE}."
}

main "$@"
