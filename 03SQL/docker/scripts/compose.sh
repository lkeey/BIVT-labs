#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LAB_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly ENV_FILE="${LAB_DIR}/.env"
readonly DOCKER_CONTEXT="colima-sqlserver"

[[ -f "${ENV_FILE}" ]] || {
  printf 'Missing %s. Run ./scripts/setup.sh first.\n' "${ENV_FILE}" >&2
  exit 1
}
docker context inspect "${DOCKER_CONTEXT}" >/dev/null 2>&1 || {
  printf 'Docker context %s is unavailable. Start Colima with: colima start --profile sqlserver\n' "${DOCKER_CONTEXT}" >&2
  exit 1
}

exec docker --context "${DOCKER_CONTEXT}" compose \
  --project-directory "${LAB_DIR}" \
  --env-file "${ENV_FILE}" \
  "$@"
