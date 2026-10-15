#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -x "$HERE/bin/server" ]]; then
  bash "$HERE/build.sh"
fi
exec "$HERE/bin/server"
