#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DOCKER_CONTEXT="colima-sqlserver"
readonly CONTAINER_NAME="adventure-db"

docker_engine() {
  docker --context "${DOCKER_CONTEXT}" "$@"
}

ensure_engine() {
  if ! docker_engine info >/dev/null 2>&1; then
    command -v colima >/dev/null 2>&1 || {
      printf 'Colima is required. Install it with: brew install colima\n' >&2
      exit 1
    }
    colima start --profile sqlserver
    docker_engine info >/dev/null || {
      printf 'Colima profile is not reachable through Docker context %s.\n' "${DOCKER_CONTEXT}" >&2
      exit 1
    }
  fi
}

case "${1:-status}" in
  start)
    ensure_engine
    "${SCRIPT_DIR}/setup.sh"
    ;;
  stop)
    ensure_engine
    docker_engine stop "${CONTAINER_NAME}"
    ;;
  restart)
    ensure_engine
    docker_engine restart "${CONTAINER_NAME}"
    "${SCRIPT_DIR}/setup.sh"
    ;;
  status)
    ensure_engine
    docker_engine ps -a --filter "name=^/${CONTAINER_NAME}$" \
      --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
    ;;
  logs)
    ensure_engine
    shift
    docker_engine logs --tail 100 "$@" "${CONTAINER_NAME}"
    ;;
  *)
    printf 'Usage: %s {start|stop|restart|status|logs}\n' "${0##*/}" >&2
    exit 2
    ;;
esac
