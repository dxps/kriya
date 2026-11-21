package ui

Color :: [4]f32
Font :: enum {
	Body,
	Mono,
}
DEFAULT_CORNER_RADIUS :: 6.0
DEFAULT_PADDING :: 14.0
Rect :: struct {
	x, y, w, h: f32,
}
// Base covers the normal widget drawing order. Overlay commands are rendered
// after every Base command in the same frame, so popup menus and tooltips
// paint on top of anything drawn after them.
Command_Layer :: enum u8 {
	Base,
	Overlay,
}
Box_Command :: struct {
	rect:   Rect,
	color:  Color,
	radius: f32,
}
Line_Command :: struct {
	x1, y1, x2, y2, width: f32,
	color:                 Color,
}
Triangle_Command :: struct {
	x1, y1, x2, y2, x3, y3: f32,
	color:                  Color,
}
Text_Command :: struct {
	x, y:  f32,
	text:  string,
	size:  f32,
	font:  Font,
	color: Color,
}
Command_Variant :: union {
	Box_Command,
	Line_Command,
	Triangle_Command,
	Text_Command,
}
Command :: struct {
	clip:    Rect,
	clipped: bool,
	layer:   Command_Layer,
	variant: Command_Variant,
}
Context :: struct {
	commands:                [dynamic]Command,
	mx, my:                  f32,
	pressed, released, down: bool,
	active:                  u64,
	measure_text:            proc(text: string, size: f32) -> f32,
	pointer_cursor:          bool,
	moved:                   bool,
	wheel_y:                 f32,
	wheel_x:                 f32,
	offset_y:                f32,
	clip:                    Rect,
	clipped:                 bool,
	input_blocked:           bool,
	focused:                 u64,
	typed:                   [32]u8,
	typed_len:               int,
	backspace:               bool,
	forward_delete:          bool,
	enter:                   bool,
	cancel:                  bool,
	nav_left:                bool,
	nav_right:               bool,
	nav_up:                  bool,
	nav_down:                bool,
	nav_home:                bool,
	nav_end:                 bool,
	nav_page_up:             bool,
	nav_page_down:           bool,
	nav_shift:               bool,
	nav_word:                bool,
	nav_line:                bool,
	mouse_shift:             bool,
	double_click:            bool,
	triple_click:            bool,
	// Clipboard plumbing. The backend captures clipboard shortcuts into
	// these per-frame flags and the matching paste text (delivered through
	// sokol's CLIPBOARD_PASTED event on web, where KEY_DOWN for V can't read
	// clipboard contents synchronously). set_clipboard is a callback the
	// backend installs so widgets can send text out without importing a
	// windowing backend; nil when the host has no clipboard.
	select_all:              bool,
	copy_request:            bool,
	cut_request:             bool,
	undo_request:            bool,
	redo_request:            bool,
	paste:                   [1024]u8,
	paste_len:               int,
	set_clipboard:           proc(text: string),
	corner_radius:           Maybe(f32),
	// Inner padding between a field's edges and its text, applied on both
	// axes. input, dropdown and textarea read it through resolve_padding so
	// a per-widget argument always wins over the context default. Single-
	// line fields only inset horizontally; textareas inset on both axes.
	padding:                 Maybe(f32),
	layer:                   Command_Layer,
	content_bottom:          f32,
	// Monotonic seconds since the host began delivering frames. The backend
	// accumulates frame durations into it; widgets read it to drive caret
	// blink and any other time-based animation. 0 on the first frame is fine.
	now:                     f64,
	// Seconds elapsed since the previous frame. The backend sets it from the
	// host clock; widgets use it to advance per-frame idle timers.
	dt:                      f32,
	// Overlay region that holds first claim on the mouse wheel: when the
	// cursor is inside it, begin_scroll skips its own wheel handling so the
	// overlay (dropdown popup) scrolls instead of the page below. Claimed
	// by widget id so multiple overlays don't fight; the claimer clears it
	// when it closes. Persists across frames so this frame's begin_scroll
	// can see last frame's claim — a one-frame lag on opening is fine.
	scroll_claim_id:         u64,
	scroll_claim:            Rect,
	// Focus traversal. nav_tab is a one-frame flag like the other nav_*
	// keys; the backend sets it on Tab (with nav_shift for Shift-Tab).
	// focus_ids captures the ids widgets register via 'focusable' this
	// frame, in draw order; end() rotates it into focus_ids_prev so the
	// next begin() can walk a complete list before any widget has drawn.
	nav_tab:                 bool,
	focus_ids:               [MAX_FOCUSABLE]u64,
	focus_count:             int,
	focus_ids_prev:          [MAX_FOCUSABLE]u64,
	focus_count_prev:        int,
	// Active theme; nil resolves to DARK_THEME in the palette() helper.
	// Set via set_theme once at startup, or re-set each frame to swap
	// at runtime.
	theme:                   ^Theme,
	// Nested scroll stack. begin_scroll pushes the outer clip / offset /
	// content_bottom / input_blocked state and the current scroll's
	// screen-space viewport; end_scroll pops and restores. Depth-bounded
	// so the frame array can live on the Context without an allocator.
	scroll_stack:            [MAX_SCROLL_DEPTH]Scroll_Frame,
	scroll_depth:            int,
	// Tooltip hover timer. One active hover at a time; tooltip_id is
	// the widget id currently accumulating hover duration, cleared when
	// the cursor leaves. A tooltip's delay is reached when
	// tooltip_hover_time > its own delay; the widget draws at that point.
	tooltip_id:              u64,
	tooltip_hover_time:      f32,
}

MAX_SCROLL_DEPTH :: 8

Scroll_Frame :: struct {
	outer_clip:           Rect,
	outer_clipped:        bool,
	outer_offset_y:       f32,
	outer_content_bottom: f32,
	outer_input_blocked:  bool,
	// Current scroll's viewport in screen coordinates. Saved so
	// end_scroll can draw its scrollbar without having to re-derive
	// the screen position from c.offset_y, which it just restored.
	screen_viewport:      Rect,
}
begin :: proc(c: ^Context) {clear(&c.commands); c.pointer_cursor = false; c.offset_y = 0
	c.clipped = false
	c.input_blocked = false
	c.layer = .Base
	c.content_bottom = 0
	// Tab handling runs against LAST frame's focus registry (filled by
	// end), so the whole list is available before any widget has drawn
	// this frame. A focused id that's no longer registered (widget
	// disappeared, focus was cleared) tabs to the first widget, and
	// shift-tabs to the last.
	if c.nav_tab && c.focus_count_prev > 0 {
		current := -1
		for i in 0 ..< c.focus_count_prev {
			if c.focus_ids_prev[i] == c.focused {current = i; break}
		}
		n := c.focus_count_prev
		if c.nav_shift {
			idx := current - 1
			if idx < 0 {idx = n - 1}
			c.focused = c.focus_ids_prev[idx]
		} else {
			idx := current + 1
			if idx >= n {idx = 0}
			c.focused = c.focus_ids_prev[idx]
		}
	}
	c.focus_count = 0}
end :: proc(c: ^Context) {c.pressed = false; c.released = false; c.moved = false; c.wheel_y = 0
	c.wheel_x = 0
	c.typed_len = 0
	c.backspace = false
	c.forward_delete = false
	c.enter = false
	c.cancel = false
	c.nav_left = false
	c.nav_right = false
	c.nav_up = false
	c.nav_down = false
	c.nav_home = false
	c.nav_end = false
	c.nav_page_up = false
	c.nav_page_down = false
	c.nav_shift = false
	c.nav_word = false
	c.nav_line = false
	c.mouse_shift = false
	c.double_click = false
	c.triple_click = false
	c.select_all = false
	c.copy_request = false
	c.cut_request = false
	c.undo_request = false
	c.redo_request = false
	c.paste_len = 0
	c.nav_tab = false
	// Rotate this frame's focus registry into _prev for next frame's
	// Tab handling. Fixed-size arrays copy by assignment in Odin.
	c.focus_ids_prev = c.focus_ids
	c.focus_count_prev = c.focus_count}
set_corner_radius :: proc(c: ^Context, radius: f32) {c.corner_radius = max(0, radius)}
resolve_corner_radius :: proc(c: ^Context, radius: Maybe(f32)) -> f32 {
	if r, ok := radius.?; ok {return r}
	if r, ok := c.corner_radius.?; ok {return r}
	return DEFAULT_CORNER_RADIUS
}
set_padding :: proc(c: ^Context, padding: f32) {c.padding = max(0, padding)}
resolve_padding :: proc(c: ^Context, padding: Maybe(f32)) -> f32 {
	if p, ok := padding.?; ok {return p}
	if p, ok := c.padding.?; ok {return p}
	return DEFAULT_PADDING
}
// Derives a unique auxiliary id for a secondary hit region inside a widget
// (dropdown items, password-reveal eye). The golden-ratio stride spreads
// derived ids across the 64-bit space so neighboring user ids don't collide.
sub_id :: proc(id, n: u64) -> u64 {return id ~ ((n + 1) * 0x9e3779b97f4a7c15)}
// Standard hover/press/active/release plumbing shared by every clickable
// widget. Returns both hover (for color selection) and clicked (for the
// widget's action).
pressable :: proc(c: ^Context, id: u64, hit: Rect) -> (hover, clicked: bool) {
	hover = contains(c, hit)
	if hover {c.pointer_cursor = true}
	if hover && c.pressed {c.active = id}
	clicked = hover && c.released && c.active == id
	if c.released && c.active == id {c.active = 0}
	return
}
