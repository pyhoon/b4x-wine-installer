#!/usr/bin/env bash
# Fedora / Red Hat-family installer entry point for the shared installer.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
MAIN_INSTALLER="${ROOT_DIR}/install_b4x_wine.sh"

[[ -f "$MAIN_INSTALLER" ]] || { printf 'Shared installer not found: %s\n' "$MAIN_INSTALLER" >&2; exit 1; }
exec bash "$MAIN_INSTALLER" "$@"
