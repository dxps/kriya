# Kriya

An Odin UI library taking its first steps: renderer-independent widget commands,
a Sokol/WebGL2 component workshop, bundled Work Sans font, and an Odin development server.

## Prerequisites

`.tools/` is ignored by Git. Cloning this repository does **not** install or copy
the compiler or SDK, and the development launcher does not download them.
Complete the following setup once on each machine, from the repository root.

The current scripts target macOS and Linux with a POSIX shell. On Windows, use
a Linux environment such as WSL2 and follow the Linux steps; native Windows
scripts are not implemented. Only macOS ARM64 has been verified so far.

Required tools:

| Tool | Version / purpose |
| --- | --- |
| Odin | `dev-2026-11a`, the compiler version used by this project |
| Emscripten SDK | `4.0.19`, compiles Sokol C code and links the browser bundle |
| Native C toolchain | Xcode Command Line Tools on macOS; Clang and build tools on Linux, for the Odin server |
| Git, Python 3, curl, tar | SDK installation and release extraction |
| Browser | A current browser with WebGL2, WebAssembly, and EventSource support |

Sokol and Work Sans are already committed to the repository. Emscripten installs
its own Node.js and LLVM tools; npm, Deno, and a separate file watcher are not
needed. This build emits an Odin object and links it with Emscripten, so a separate
`wasm-ld` installation is not required for this workflow.

### 1. Install system tools

On macOS, install Apple's command-line tools if they are not already installed:

```sh
xcode-select --install
```

You also need `python3` available to run the SDK installer. If it is missing,
install Python 3 from [python.org](https://www.python.org/downloads/), or with
`brew install python` if you use Homebrew.

On Debian/Ubuntu Linux (including Ubuntu under WSL2):

```sh
sudo apt update
sudo apt install build-essential clang git python3 curl ca-certificates xz-utils
```

On other Linux distributions, install the equivalent packages.

### 2. Install Odin

Download the archive for your OS and CPU from the
[Odin dev-2026-11a release](https://github.com/odin-lang/Odin/releases/tag/dev-2026-11a).
Use `uname -s` and `uname -m` to identify your machine. The release offers
macOS ARM64, Linux AMD64, and Linux ARM64 archives. Use the matching name below
as `ODIN_ARCHIVE`:

```sh
# Choose ONE matching your machine:
ODIN_ARCHIVE=odin-macos-arm64-dev-2026-11a.tar.gz
# ODIN_ARCHIVE=odin-linux-amd64-dev-2026-11a.tar.gz
# ODIN_ARCHIVE=odin-linux-arm64-dev-2026-11a.tar.gz

mkdir -p .tools/odin
curl -fL "https://github.com/odin-lang/Odin/releases/download/dev-2026-11a/$ODIN_ARCHIVE" -o .tools/odin.tar.gz
tar -xzf .tools/odin.tar.gz -C .tools/odin --strip-components=1
.tools/odin/odin version
```

Keep the **entire** extracted distribution, including `base`, `core`, `vendor`,
and its libraries, alongside the executable. For a machine without a matching
release archive, build the `dev-2026-11a` tag using the
[official Odin installation instructions](https://odin-lang.org/docs/install/),
then set `ODIN` to that compiler's absolute path. Building Odin itself also
requires the LLVM dependencies listed there.

If you already have the matching Odin version installed elsewhere, you can skip
the download: put `odin` on `PATH` or export `ODIN=/absolute/path/to/odin`.

### 3. Install Emscripten

From the repository root:

```sh
git clone https://github.com/emscripten-core/emsdk.git .tools/emsdk
.tools/emsdk/emsdk install 4.0.19
.tools/emsdk/emsdk activate 4.0.19
. .tools/emsdk/emsdk_env.sh
emcc --version
```

The launcher activates `.tools/emsdk` automatically on subsequent runs. If you
keep an SDK elsewhere, install and activate `4.0.19` there, then source its
`emsdk_env.sh` in each terminal before launching the project. See the
[official Emscripten SDK guide](https://emscripten.org/docs/getting_started/downloads.html).

Do not copy `.tools/` between operating systems or CPU architectures; install the
appropriate tools on the destination machine instead.

### 4. Verify and launch

```sh
.tools/odin/odin version
emcc --version
./scripts/dev.sh
```

The examples above use a local Odin installation. With an external compiler,
verify it using `"$ODIN" version` or `odin version` instead.

The launcher resolves Odin in this order: explicit `ODIN`, `.tools/odin/odin`,
`odin` on `PATH`, then the original macOS ARM64 installation directory for
backward compatibility. It reports missing dependencies before starting the server.

## Local development

```sh
./scripts/dev.sh
```

Open **http://localhost:8000** in a desktop browser. Keep the terminal running;
Ctrl+C stops it. The first build compiles the Sokol C modules; subsequent builds reuse them.

Sections have shareable paths: `/buttons`, `/checkboxes`, `/typography`, and
`/composition`. `/` redirects to `/buttons`. Sidebar navigation updates browser
history; Back/Forward and refreshing a section retain the selected view.

Explore Buttons, Checkboxes, Typography and Composition in the sidebar. Click the
button to increment its counter. Edit `apps/gallery/main.odin` or `kriya/ui/ui.odin`
and save: the Odin server watches sources independently of browser requests,
debounces changes, and rebuilds WASM. Build status is pushed over the persistent
`/__events` SSE channel; a successful build refreshes the current section.
A failed build displays an
overlay; compiler diagnostics appear in the terminal. Fix and save to recover.
Reload resets demonstration state. Restart the server after editing `tools/dev`.
Each section's content and demo state live in its own file under `apps/gallery/`
(`buttons.odin`, `checkboxes.odin`, `typography.odin`, `composition.odin`). The
shared shell and renderer remain in `main.odin`, with view registration in
`views.odin`.

When the window is shorter than the content, scroll the main view with the mouse
wheel/trackpad or drag the rounded scrollbar thumb. The sidebar stays fixed and
each section retains its own scroll position while navigating. The scrollbar
appears on mouse movement or scrolling, holds for 0.25 seconds, then fades over
0.5 seconds. It stays visible while hovered or dragged and is hidden when all
content fits. Drawing and interaction are clipped to the scroll viewport.
EventSource reconnects automatically if the server becomes unavailable. SSE
connections receive an initial build snapshot and periodic heartbeat comments.
Multiple tabs can subscribe while static assets continue to load concurrently.
To use another local port: `KRIYA_PORT=8001 ./scripts/dev.sh`.

## Toolchain

Odin `dev-2026-11a` reports `dev-2026-11-nightly:9a69916` in `odin version`.

The browser build compiles Odin to a freestanding WASM object and links it with
Sokol and stb_truetype using Emscripten. The entry point explicitly initializes
Odin's runtime. The application uses fixed backing arenas, and text uses a GPU
atlas generated from the bundled font. Atlases are cached per physical font size
and regenerated when display density changes. The canvas uses high-DPI rendering;
layout and input remain in logical pixels, while glyphs align to physical pixels.
Small JavaScript glue starts WASM, synchronizes browser history with the gallery,
and listens for SSE build events; HTTP serving, change detection and build
management are Odin.

## Packages

- `kriya/ui`: widgets, interaction, scroll views, and renderer-neutral draw commands.
- `apps/gallery`: workshop and initial Sokol command renderer.
- `backends/font`: minimal stb_truetype C bindings.
- `backends/web`: browser navigation bridge.
- `gallery/routes`: shared section titles and URL paths used by the app and server.
- `tools/dev`: loopback-only HTTP server and rebuild management.
- `web/fonts`: Work Sans variable font and SIL Open Font License.

This milestone has pointer-operated buttons and checkboxes, simple rectangle and
text commands, and four example views. Layout is currently explicit coordinates,
best viewed at desktop widths. Keyboard focus, touch, text editing, clipping,
automatic layout, Unicode shaping, accessibility and native packaging remain to
be implemented. The Sokol renderer will move out of the gallery as its API settles.

## Tests

```sh
.tools/odin/odin test kriya/ui
```

Use `"$ODIN" test kriya/ui` or `odin test kriya/ui` with an external compiler.
Tests cover matching press/release activation, disabled controls, and checkbox
label activation and cursor behavior, scroll bounds, clipping, thumb dragging,
and scrollbar visibility/fading.

## Dependencies

Vendored Sokol Odin snapshot: `dee4e716bd7cf072b3be75f6a80228b408200dcc`
from https://github.com/floooh/sokol-odin. Its upstream license is retained.
Work Sans is from https://github.com/google/fonts/tree/main/ofl/worksans;
its license is in `web/fonts/OFL.txt`. stb_truetype is supplied by the Odin
distribution and compiled against Emscripten's C runtime.
