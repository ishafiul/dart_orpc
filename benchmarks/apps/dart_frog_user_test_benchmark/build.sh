#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

dart pub get
dart run dart_frog_cli:dart_frog build
mkdir -p bin
dart compile exe build/bin/server.dart -o bin/server
