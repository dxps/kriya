#!/bin/sh
set -eu
ODIN=${ODIN:-odin}
mkdir -p build
SOKOL=vendor/sokol-odin-main/sokol
for module in app gfx gl glue log; do
  if [ ! -f "build/sokol_$module.o" ]; then
    emcc -c -O1 -DIMPL -DSOKOL_GLES3 "$SOKOL/c/sokol_$module.c" -o "build/sokol_$module.o"
  fi
done
emcc -c -O1 "$(${ODIN} root)/vendor/stb/src/stb_truetype.c" -o build/font.o
"$ODIN" build apps/gallery -target:freestanding_wasm32 -build-mode:obj -out:build/gallery.o -collection:kriya=kriya -collection:sokol="$SOKOL" -debug
emcc build/gallery.o build/font.o build/sokol_*.o --js-library web/odin-library.js -o build/app.js -sUSE_WEBGL2=1 -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=4194304 -sERROR_ON_UNDEFINED_SYMBOLS=1 -sEXPORTED_FUNCTIONS=_kriya_start -sEXPORTED_RUNTIME_METHODS=ccall
cp build/app.wasm web/app.wasm
cp build/app.js web/app.js
