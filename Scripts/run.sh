#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
./Scripts/bundle.sh debug

BIN_PATH="$(swift build -c debug --show-bin-path)"
open "$BIN_PATH/MacStats.app"
