#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
ODIN=${ODIN:-"$PWD/.tools/odin-macos-arm64-nightly+2026-11-03/odin"}
export ODIN
export EMSDK_QUIET=1
if [ -f .tools/emsdk-main/emsdk_env.sh ]; then
  . .tools/emsdk-main/emsdk_env.sh
fi
mkdir -p build
"$ODIN" run tools/dev -out:build/dev
