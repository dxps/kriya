package ui

Color :: [4]f32
Font :: enum {
	Body,
	Mono,
}
DEFAULT_CORNER_RADIUS :: 6.0
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
	layer:                   Command_Layer,
	content_bottom:          f32,
}
begin :: proc(c: ^Context) {clear(&c.commands); c.pointer_cursor = false; c.offset_y = 0
	c.clipped = false
	c.input_blocked = false
	c.layer = .Base
	c.content_bottom = 0}
end :: proc(c: ^Context) {c.pressed = false; c.released = false; c.moved = false; c.wheel_y = 0
	c.wheel_x = 0
	c.typed_len = 0
	c.backspace = false
	c.forward_delete = false
	c.enter = false
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
	c.paste_len = 0}
set_corner_radius :: proc(c: ^Context, radius: f32) {c.corner_radius = max(0, radius)}
resolve_corner_radius :: proc(c: ^Context, radius: Maybe(f32)) -> f32 {
	if r, ok := radius.?; ok {return r}
	if r, ok := c.corner_radius.?; ok {return r}
	return DEFAULT_CORNER_RADIUS
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
