#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -z "${ODIN:-}" ]; then
  if [ -x .tools/odin/odin ]; then
    ODIN="$PWD/.tools/odin/odin"
  elif command -v odin >/dev/null 2>&1; then
    ODIN=$(command -v odin)
  elif [ -x .tools/odin-macos-arm64-nightly+2026-11-03/odin ]; then
    # Compatibility with the project's original local installation.
    ODIN="$PWD/.tools/odin-macos-arm64-nightly+2026-11-03/odin"
  else
    echo "Odin not found. Follow Prerequisites in readme.md or set ODIN=/absolute/path/to/odin." >&2
    exit 1
  fi
fi
if ! command -v "$ODIN" >/dev/null 2>&1; then
  echo "Cannot execute ODIN=$ODIN. See Prerequisites in readme.md." >&2
  exit 1
fi
export ODIN
export EMSDK_QUIET=1
if [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
  . "$EMSDK/emsdk_env.sh"
elif [ -f .tools/emsdk/emsdk_env.sh ]; then
  . .tools/emsdk/emsdk_env.sh
elif ! command -v emcc >/dev/null 2>&1 && [ -f .tools/emsdk-main/emsdk_env.sh ]; then
  . .tools/emsdk-main/emsdk_env.sh
fi
if ! command -v emcc >/dev/null 2>&1; then
  echo "Emscripten not found. Follow Prerequisites in readme.md, or activate your SDK with: . /path/to/emsdk/emsdk_env.sh" >&2
  exit 1
fi
mkdir -p build
"$ODIN" run tools/dev -out:build/dev
