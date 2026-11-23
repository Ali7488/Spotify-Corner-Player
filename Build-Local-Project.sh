#!/usr/bin/env bash
# Compatibility entrypoint for old bootstrap instructions.
# The project now already exists on GitHub; do not reinitialize/create a new repo.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "$0")" && pwd -P)"
echo 'Existing project detected. Generating the complete Windows v1.3.0 ZIP.'
exec bash "$ROOT/Build-Release.sh"
