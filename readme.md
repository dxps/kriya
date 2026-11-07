# Kriya

An Odin UI library taking its first steps: renderer-independent widget commands,
a Sokol/WebGL2 component workshop, bundled Work Sans font, and an Odin development server.

## Run on this machine

```sh
./scripts/dev.sh
```

Open **http://localhost:8000** in a desktop browser. Keep the terminal running;
Ctrl+C stops it. The first build compiles the Sokol C modules; subsequent builds reuse them.

Explore Buttons, Checkboxes, Typography and Composition in the sidebar. Click the
button to increment its counter. Edit `apps/gallery/main.odin` or `kriya/ui/ui.odin`
and save: the browser polls the Odin server every 700 ms, which detects changed
sources, rebuilds WASM and refreshes after success. A failed build displays an
overlay; compiler diagnostics appear in the terminal. Fix and save to recover.
Reload resets demonstration state. Restart the server after editing `tools/dev`.

## Toolchain

The current machine has project-local tools under ignored `.tools/`:

- Odin dev-2026-11a (reports dev-2026-11-nightly:9a69916), macOS ARM64.
- Emscripten 4.0.19.

The launcher uses these automatically. With a separately installed toolchain,
activate Emscripten in your shell and run `ODIN=/path/to/odin sh scripts/dev.sh`.
The Odin server is portable source; build orchestration currently uses POSIX shell
(macOS/Linux). Windows bootstrap and native gallery builds are future work.

The browser build compiles Odin to a freestanding WASM object and links it with
Sokol and stb_truetype using Emscripten. The entry point explicitly initializes
Odin's runtime. The application uses fixed backing arenas, and text uses a GPU
atlas generated from the bundled font. Atlases are cached per physical font size
and regenerated when display density changes. The canvas uses high-DPI rendering;
layout and input remain in logical pixels, while glyphs align to physical pixels.
Small JavaScript glue starts WASM and
polls reload status; HTTP serving, change detection and build management are Odin.

## Packages

- `kriya/ui`: widgets, interaction and renderer-neutral draw commands.
- `apps/gallery`: workshop and initial Sokol command renderer.
- `backends/font`: minimal stb_truetype C bindings.
- `tools/dev`: loopback-only HTTP server and rebuild management.
- `web/fonts`: Work Sans variable font and SIL Open Font License.

This milestone has pointer-operated buttons and checkboxes, simple rectangle and
text commands, and four example views. Layout is currently explicit coordinates,
best viewed at desktop widths. Keyboard focus, touch, text editing, clipping,
automatic layout, Unicode shaping, accessibility and native packaging remain to
be implemented. The Sokol renderer will move out of the gallery as its API settles.

## Tests

```sh
.tools/odin-macos-arm64-nightly+2026-11-03/odin test kriya/ui
```

Tests cover matching press/release activation and disabled controls.

## Dependencies

Vendored Sokol Odin snapshot: `dee4e716bd7cf072b3be75f6a80228b408200dcc`
from https://github.com/floooh/sokol-odin. Its upstream license is retained.
Work Sans is from https://github.com/google/fonts/tree/main/ofl/worksans;
its license is in `web/fonts/OFL.txt`. stb_truetype is supplied by the Odin
distribution and compiled against Emscripten's C runtime.
