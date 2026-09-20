#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

[[ "$(git -C "${repo_root}" rev-parse --show-toplevel)" == "${repo_root}" ]] || {
  printf 'Unable to resolve the repository root from %s\n' "${script_dir}" >&2
  exit 1
}

git -C "${repo_root}" config core.hooksPath .githooks
chmod +x "${repo_root}/.githooks/pre-commit"

printf 'Git hooks enabled for %s\n' "${repo_root}"
