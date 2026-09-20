#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LAB_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${LAB_DIR}/.env"
readonly DOCKER_RAW_SOCKET="${HOME}/Library/Containers/com.docker.docker/Data/docker.raw.sock"

[[ -f "${ENV_FILE}" ]] || {
  printf 'Missing %s. Run ./scripts/setup.sh first.\n' "${ENV_FILE}" >&2
  exit 1
}
[[ -S "${DOCKER_RAW_SOCKET}" ]] || {
  printf 'Docker Desktop is not running: %s is unavailable.\n' "${DOCKER_RAW_SOCKET}" >&2
  exit 1
}

exec docker --host "unix://${DOCKER_RAW_SOCKET}" compose \
  --project-directory "${LAB_DIR}" \
  --env-file "${ENV_FILE}" \
  "$@"
