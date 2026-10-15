#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

dart pub get
dart run build_runner build
dart compile exe bin/server.dart -o bin/server
