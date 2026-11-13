package ui

import "core:unicode/utf8"

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
box :: proc(c: ^Context, r: Rect, color: Color, radius: f32 = 0) {
	c.content_bottom = max(c.content_bottom, r.y + r.h)
	translated := r; translated.y += c.offset_y
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Box_Command{rect = translated, color = color, radius = radius},
		},
	)
}
line :: proc(c: ^Context, x1, y1, x2, y2, width: f32, color: Color) {
	c.content_bottom = max(c.content_bottom, max(y1, y2) + width * 0.5)
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Line_Command {
				x1 = x1,
				y1 = y1 + c.offset_y,
				x2 = x2,
				y2 = y2 + c.offset_y,
				width = width,
				color = color,
			},
		},
	)
}
triangle :: proc(c: ^Context, x1, y1, x2, y2, x3, y3: f32, color: Color) {
	c.content_bottom = max(c.content_bottom, max(y1, max(y2, y3)))
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Triangle_Command {
				x1 = x1,
				y1 = y1 + c.offset_y,
				x2 = x2,
				y2 = y2 + c.offset_y,
				x3 = x3,
				y3 = y3 + c.offset_y,
				color = color,
			},
		},
	)
}
label :: proc(
	c: ^Context,
	x, y: f32,
	text: string,
	size: f32 = 18,
	color: Color = DEFAULT_PALETTE.text,
	font: Font = .Body,
) {
	// y is the baseline; add a modest descender allowance for content measurement.
	c.content_bottom = max(c.content_bottom, y + size * 0.3)
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Text_Command {
				x = x,
				y = y + c.offset_y,
				text = text,
				size = size,
				font = font,
				color = color,
			},
		},
	)
}
point_in_rect :: proc(x, y: f32, r: Rect) -> bool {return(
		x >= r.x &&
		x < r.x + r.w &&
		y >= r.y &&
		y < r.y + r.h \
	)}
contains :: proc(c: ^Context, r: Rect) -> bool {
	translated := r; translated.y += c.offset_y
	return(
		!c.input_blocked &&
		(!c.clipped || point_in_rect(c.mx, c.my, c.clip)) &&
		point_in_rect(c.mx, c.my, translated) \
	)
}
button :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	text: string,
	disabled := false,
	radius: Maybe(f32) = nil,
) -> bool {
	corner_radius := resolve_corner_radius(c, radius)
	hover, clicked: bool
	if !disabled {hover, clicked = pressable(c, id, r)}
	color := DEFAULT_PALETTE.primary
	if hover {color = DEFAULT_PALETTE.primary_hover}
	if c.active == id && c.down {color = DEFAULT_PALETTE.primary_pressed}
	if disabled {color = DEFAULT_PALETTE.disabled}
	box(
		c,
		r,
		color,
		corner_radius,
	); label(c, r.x + 18, r.y + 28, text, 18, DEFAULT_PALETTE.text_on_primary)
	return clicked
}
checkbox :: proc(
	c: ^Context,
	id: u64,
	x, y: f32,
	text: string,
	value: ^bool,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	r := Rect{x, y, 18, 18}
	hit := r
	if len(text) > 0 {
		assert(c.measure_text != nil, "Checkbox labels require a text measurement callback")
		hit.w = 28 + c.measure_text(text, 18)
	}
	hover, clicked := pressable(c, id, hit)
	if clicked {value^ = !value^}
	border := DEFAULT_PALETTE.primary
	if hover {border = DEFAULT_PALETTE.primary_hover}
	if c.active == id && c.down {border = DEFAULT_PALETTE.primary_pressed}
	box(c, r, border, corner_radius)
	// One logical pixel of border, independent of the checked indicator.
	box(c, {x + 1, y + 1, 16, 16}, DEFAULT_PALETTE.surface_raised, max(0, corner_radius - 1))
	if value^ {box(c, {x + 3, y + 3, 12, 12}, border, max(0, corner_radius - 3))}
	label(c, x + 28, y + 14, text)
}
// Pill-shaped on/off switch. Track is 32x18, matching the checkbox's 18px
// box; the 12x12 thumb slides between a 3px inset on either side. Clicking
// anywhere on the track or its label flips the value.
toggle :: proc(c: ^Context, id: u64, x, y: f32, text: string, value: ^bool) {
	track := Rect{x, y, 32, 18}
	hit := track
	if len(text) > 0 {
		assert(c.measure_text != nil, "Toggle labels require a text measurement callback")
		hit.w = 42 + c.measure_text(text, 18)
	}
	hover, clicked := pressable(c, id, hit)
	if clicked {value^ = !value^}
	track_color := DEFAULT_PALETTE.border
	if value^ {
		track_color = DEFAULT_PALETTE.primary
		if hover {track_color = DEFAULT_PALETTE.primary_hover}
		if c.active == id && c.down {track_color = DEFAULT_PALETTE.primary_pressed}
	} else if hover {
		track_color = DEFAULT_PALETTE.border_hover
	}
	box(c, track, track_color, 9)
	thumb_x := value^ ? x + 17 : x + 3
	box(c, {thumb_x, y + 3, 12, 12}, DEFAULT_PALETTE.text, 6)
	label(c, x + 42, y + 14, text)
}

Text_Input :: struct {
	data:     [128]u8,
	len:      int,
	revealed: bool,
}

set_text :: proc(value: ^Text_Input, text: string) {
	value.len = min(len(text), len(value.data))
	copy(value.data[:value.len], transmute([]u8)text[:value.len])
}

input :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	placeholder: string,
	value: ^Text_Input,
	password := false,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	hover := contains(c, r)
	eye_w: f32 = password ? 44 : 0
	text_hit := Rect{r.x, r.y, r.w - eye_w, r.h}
	if hover {c.pointer_cursor = true}
	if c.pressed {
		if contains(c, text_hit) {c.focused = id} else if c.focused == id && !hover {c.focused = 0}
	}
	focused := c.focused == id
	if focused {
		if c.backspace && value.len > 0 {
			// Drop one whole rune, not one byte: step back past UTF-8
			// continuation bytes (top two bits == 10).
			value.len -= 1
			for value.len > 0 && (value.data[value.len] & 0xC0) == 0x80 {value.len -= 1}
		}
		for ch in c.typed[:c.typed_len] {
			if value.len < len(value.data) {value.data[value.len] = ch; value.len += 1}
		}
		c.typed_len = 0
		c.backspace = false
	}
	border := DEFAULT_PALETTE.border
	if hover {border = DEFAULT_PALETTE.border_hover}
	if focused {border = DEFAULT_PALETTE.primary_bright}
	box(c, r, border, corner_radius)
	box(
		c,
		{r.x + 1, r.y + 1, r.w - 2, r.h - 2},
		DEFAULT_PALETTE.surface,
		max(0, corner_radius - 1),
	)
	shown := placeholder
	masked := password && !value.revealed && value.len > 0
	color := DEFAULT_PALETTE.text_muted
	if value.len > 0 {
		color = DEFAULT_PALETTE.text
		if !masked {
			shown = string(value.data[:value.len])
		}
	}
	rune_count := utf8.rune_count_in_string(string(value.data[:value.len]))
	if masked {
		// Draw round password bullets independently of the text font so their
		// shape remains circular at every display scale. One bullet per rune,
		// not per UTF-8 byte.
		bullet_x := r.x + 14
		for _ in 0 ..< rune_count {
			box(c, {bullet_x, r.y + r.h / 2 - 4, 8, 8}, color, 4)
			bullet_x += 14
		}
	} else {
		label(c, r.x + 14, r.y + 29, shown, 17, color)
	}
	if focused {
		caret_x := r.x + 14 + f32(rune_count) * 14
		if !masked {
			assert(c.measure_text != nil, "Focused inputs require a text measurement callback")
			caret_x = r.x + 14 + c.measure_text(shown, 17)
		}
		box(
			c,
			{min(caret_x, r.x + r.w - eye_w - 12), r.y + 11, 1, r.h - 22},
			DEFAULT_PALETTE.primary_bright,
		)
	}
	if password {
		divider_x := r.x + r.w - eye_w
		box(c, {divider_x, r.y + 8, 1, r.h - 16}, DEFAULT_PALETTE.divider)
		eye := Rect{divider_x + 12, r.y + 16, 20, 12}
		eye_hover, eye_clicked := pressable(c, sub_id(id, 1), {divider_x, r.y, eye_w, r.h})
		if eye_clicked {value.revealed = !value.revealed}
		eye_color := eye_hover ? DEFAULT_PALETTE.primary_bright : DEFAULT_PALETTE.text_subtle
		// Four short segments per lid retain a gentle curve while keeping the
		// left and right corners pointed like a conventional eye glyph.
		line(c, eye.x, eye.y + 6, eye.x + 5, eye.y + 2, 1.4, eye_color)
		line(c, eye.x + 5, eye.y + 2, eye.x + 10, eye.y + 1, 1.4, eye_color)
		line(c, eye.x + 10, eye.y + 1, eye.x + 15, eye.y + 2, 1.4, eye_color)
		line(c, eye.x + 15, eye.y + 2, eye.x + 20, eye.y + 6, 1.4, eye_color)
		line(c, eye.x, eye.y + 6, eye.x + 5, eye.y + 10, 1.4, eye_color)
		line(c, eye.x + 5, eye.y + 10, eye.x + 10, eye.y + 11, 1.4, eye_color)
		line(c, eye.x + 10, eye.y + 11, eye.x + 15, eye.y + 10, 1.4, eye_color)
		line(c, eye.x + 15, eye.y + 10, eye.x + 20, eye.y + 6, 1.4, eye_color)
		box(c, {eye.x + 7, eye.y + 3, 6, 6}, eye_color, 3)
		if !value.revealed {
			// Hidden is visually distinct by default: the eye is struck through.
			line(
				c,
				eye.x - 2,
				eye.y + eye.h + 3,
				eye.x + eye.w + 2,
				eye.y - 3,
				2.5,
				DEFAULT_PALETTE.surface,
			)
			line(c, eye.x - 2, eye.y + eye.h + 3, eye.x + eye.w + 2, eye.y - 3, 1.25, eye_color)
		}
	}
}

// Multi-line text buffer. Larger than Text_Input so paragraphs fit; newlines
// are stored verbatim as '\n' and are the only line break the widget honors
// (no soft-wrap). Content is still raw bytes — rune-aware edits step past
// UTF-8 continuation bytes the same way the single-line input does.
// caret is a byte index into data[:len] and must land on a rune boundary;
// every mutation routes through textarea_insert / textarea_backspace so this
// stays invariant. scroll, dragging and grab_y retain scroll and drag across
// frames so each textarea remembers its own view and interaction state.
// Edit_Kind classifies the previous write so consecutive edits of the
// same kind coalesce into one undo entry — typing a word creates one
// undo step, not one per character; a run of Backspaces is one step too.
// Anything less uniform (Enter, paste, cut, backspace with selection)
// flushes to .Other so each stands alone.
Edit_Kind :: enum u8 {
	None,
	Insert,
	Delete,
	Other,
}

// Fixed-size snapshot of the editable state. Stored on undo / redo stacks
// so a revert is one struct copy — simple and allocation-free at the
// cost of ~1 KB per entry.
History_Entry :: struct {
	data:   [1024]u8,
	len:    int,
	caret:  int,
	anchor: int,
}

HISTORY_CAP :: 8

Text_Area :: struct {
	data:         [1024]u8,
	len:          int,
	caret:        int,
	// anchor is the opposite end of the selection. When anchor == caret
	// there is no selection; otherwise the selected byte range is
	// [min(anchor, caret), max(anchor, caret)). Every edit path that
	// should "replace selection" calls textarea_delete_selection first,
	// which collapses the pair to the start of the range.
	anchor:       int,
	// goal_x is the ideal horizontal position (pixels from line start) that
	// Up and Down try to land at. goal_sticky stays true across consecutive
	// vertical moves so the caret returns to its original column after a
	// detour through a shorter line; any horizontal action, click or edit
	// clears it and the next vertical press re-anchors from the caret's
	// current x.
	goal_x:       f32,
	goal_sticky:  bool,
	scroll:       f32,
	dragging:     bool,
	grab_y:       f32,
	// Horizontal scroll twins of scroll / dragging / grab_y. scroll_x
	// slides the content left so overlong lines stop clipping; dragging_x
	// and grab_x retain the horizontal scrollbar drag across frames.
	scroll_x:     f32,
	dragging_x:   bool,
	grab_x:       f32,
	// text_dragging retains the mouse-drag select state across frames so a
	// drag that leaves the widget keeps extending the selection until the
	// button is released.
	text_dragging:  bool,
	// Undo / redo stacks and the kind of the most recent edit. undo holds
	// pre-edit snapshots; redo holds post-undo snapshots so successive
	// redos walk back to where the user was. last_edit_kind drives
	// coalescing — the next edit opens a new entry only when its kind
	// changes (or when a non-edit interaction flushes last_edit_kind to
	// .None).
	undo:           [HISTORY_CAP]History_Entry,
	undo_len:       int,
	redo:           [HISTORY_CAP]History_Entry,
	redo_len:       int,
	last_edit_kind: Edit_Kind,
}

set_area_text :: proc(value: ^Text_Area, text: string) {
	value.len = min(len(text), len(value.data))
	copy(value.data[:value.len], transmute([]u8)text[:value.len])
	value.caret = value.len
	value.anchor = value.len
	value.goal_sticky = false
	value.undo_len = 0
	value.redo_len = 0
	value.last_edit_kind = .None
}

// Captures the current buffer, length, caret and anchor as a History_Entry.
textarea_snapshot :: proc(value: ^Text_Area) -> History_Entry {
	entry: History_Entry
	copy(entry.data[:value.len], value.data[:value.len])
	entry.len = value.len
	entry.caret = value.caret
	entry.anchor = value.anchor
	return entry
}

// Replaces the current state with a History_Entry. Clears the goal column
// and the sticky-drag flags because they don't belong to the saved text.
// The entry comes in by pointer so its embedded array stays addressable
// for the slice copy — Odin procedure parameters aren't.
textarea_restore :: proc(value: ^Text_Area, entry: ^History_Entry) {
	value.len = entry.len
	copy(value.data[:entry.len], entry.data[:entry.len])
	value.caret = entry.caret
	value.anchor = entry.anchor
	value.goal_sticky = false
}

// Pushes onto a fixed-size stack. When full, shifts left so the oldest
// entry is dropped and the new entry lands at the top; cheap enough for
// an 8-slot stack and avoids ring-buffer bookkeeping.
textarea_history_push :: proc(
	stack: ^[HISTORY_CAP]History_Entry,
	len: ^int,
	entry: ^History_Entry,
) {
	if len^ < HISTORY_CAP {
		stack[len^] = entry^
		len^ += 1
	} else {
		for i in 0 ..< HISTORY_CAP - 1 {stack[i] = stack[i + 1]}
		stack[HISTORY_CAP - 1] = entry^
	}
}

// Call right before every write. Pushes the current state onto undo when
// the edit kind changed (so same-kind runs coalesce) and always clears
// the redo stack — a new edit forks history.
textarea_begin_edit :: proc(value: ^Text_Area, kind: Edit_Kind) {
	if kind != value.last_edit_kind {
		snap := textarea_snapshot(value)
		textarea_history_push(&value.undo, &value.undo_len, &snap)
		value.last_edit_kind = kind
	}
	value.redo_len = 0
}

// Reverts to the most recent snapshot. Pushes the current state onto the
// redo stack first so redo can bring it back. Returns true on success.
textarea_undo :: proc(value: ^Text_Area) -> bool {
	if value.undo_len == 0 {return false}
	snap := textarea_snapshot(value)
	textarea_history_push(&value.redo, &value.redo_len, &snap)
	value.undo_len -= 1
	textarea_restore(value, &value.undo[value.undo_len])
	value.last_edit_kind = .None
	return true
}

// Replays the most recent undone state. Mirrors textarea_undo.
textarea_redo :: proc(value: ^Text_Area) -> bool {
	if value.redo_len == 0 {return false}
	snap := textarea_snapshot(value)
	textarea_history_push(&value.undo, &value.undo_len, &snap)
	value.redo_len -= 1
	textarea_restore(value, &value.redo[value.redo_len])
	value.last_edit_kind = .None
	return true
}

// Removes the selected byte range (when anchor != caret) by shifting the
// suffix left, then collapses the pair to the start of the range. Returns
// true when a selection was deleted.
textarea_delete_selection :: proc(value: ^Text_Area) -> bool {
	if value.anchor == value.caret {return false}
	s := min(value.anchor, value.caret)
	e := max(value.anchor, value.caret)
	shift := e - s
	for i := e; i < value.len; i += 1 {value.data[i - shift] = value.data[i]}
	value.len -= shift
	value.caret = s
	value.anchor = s
	return true
}

// Byte index of the start of the line containing caret. Walks forward
// because rune-aware edits only guarantee a valid caret on rune
// boundaries, not that we can scan backward one byte at a time.
textarea_line_start :: proc(data: []u8, caret: int) -> int {
	s := 0
	for i in 0 ..< caret {
		if data[i] == '\n' {s = i + 1}
	}
	return s
}

// Byte index of the newline terminating the line containing caret, or
// len(data) when the line has no trailing newline.
textarea_line_end :: proc(data: []u8, caret: int) -> int {
	for i in caret ..< len(data) {
		if data[i] == '\n' {return i}
	}
	return len(data)
}

// Classifies a byte as "word" (letters, digits, underscore and every
// non-ASCII byte — UTF-8 lead and continuation bytes are both >= 0x80, so
// multi-byte word characters stay grouped). Newlines, spaces and ASCII
// punctuation are not word bytes.
textarea_is_word_byte :: proc(b: u8) -> bool {
	if b >= 0x80 {return true}
	if b >= 'a' && b <= 'z' {return true}
	if b >= 'A' && b <= 'Z' {return true}
	if b >= '0' && b <= '9' {return true}
	return b == '_'
}

// Walks forward from pos past any run of non-word bytes, then past the
// following run of word bytes, and returns that stopping position. Used
// by Ctrl+Right to jump to the end of the next word. The scan is
// rune-safe because textarea_is_word_byte treats every UTF-8 lead and
// continuation byte as a word byte, so every multi-byte word rune is
// crossed whole.
textarea_next_word :: proc(data: []u8, pos: int) -> int {
	i := pos
	for i < len(data) && !textarea_is_word_byte(data[i]) {i += 1}
	for i < len(data) && textarea_is_word_byte(data[i]) {i += 1}
	return i
}

// Mirror of textarea_next_word for Ctrl+Left: steps backward past any
// run of non-word bytes, then past the preceding run of word bytes.
textarea_prev_word :: proc(data: []u8, pos: int) -> int {
	i := pos
	for i > 0 && !textarea_is_word_byte(data[i - 1]) {i -= 1}
	for i > 0 && textarea_is_word_byte(data[i - 1]) {i -= 1}
	return i
}

// Returns the byte range [ws, we) of the word around pos, bounded by the
// enclosing line. Used by double-click to expand a caret click into a
// word selection. If pos lands on whitespace or punctuation and neither
// neighbor is a word byte, returns pos, pos — the caller should keep the
// caret where it is.
textarea_word_bounds :: proc(data: []u8, pos, line_start, line_end: int) -> (int, int) {
	ws := pos
	we := pos
	if pos > line_start && textarea_is_word_byte(data[pos - 1]) {
		for ws > line_start && textarea_is_word_byte(data[ws - 1]) {ws -= 1}
	}
	if pos < line_end && textarea_is_word_byte(data[pos]) {
		for we < line_end && textarea_is_word_byte(data[we]) {we += 1}
	}
	return ws, we
}

// Given a target x in pixels relative to the line's text origin, returns
// the byte index on that line whose rune boundary is closest to the
// target. Used by click positioning and by Up / Down to project the goal
// column onto a different line.
textarea_x_to_caret :: proc(
	c: ^Context,
	data: []u8,
	line_start, line_end: int,
	target_x: f32,
) -> int {
	if target_x <= 0 {return line_start}
	text := string(data[line_start:line_end])
	byte_pos := 0
	prev_w: f32 = 0
	for byte_pos < len(text) {
		_, rs := utf8.decode_rune_in_string(text[byte_pos:])
		end := byte_pos + rs
		if end > len(text) {end = len(text)}
		w := c.measure_text(text[:end], 17)
		if target_x < (prev_w + w) / 2 {return line_start + byte_pos}
		prev_w = w
		byte_pos = end
	}
	return line_end
}

// Shifts the suffix right and copies bytes into the gap at value.caret,
// then collapses the selection. Returns the number of bytes actually
// inserted (0 when full or empty).
textarea_insert :: proc(value: ^Text_Area, bytes: []u8) -> int {
	n := min(len(bytes), len(value.data) - value.len)
	if n <= 0 {return 0}
	for i := value.len - 1; i >= value.caret; i -= 1 {value.data[i + n] = value.data[i]}
	copy(value.data[value.caret:value.caret + n], bytes[:n])
	value.len += n
	value.caret += n
	value.anchor = value.caret
	return n
}

// Removes the rune to the left of the caret by stepping back past UTF-8
// continuation bytes (top two bits == 10), then shifting the suffix left
// and collapsing the selection. Returns true when a rune was removed.
textarea_backspace :: proc(value: ^Text_Area) -> bool {
	if value.caret == 0 {return false}
	end := value.caret
	start := end - 1
	for start > 0 && (value.data[start] & 0xC0) == 0x80 {start -= 1}
	shift := end - start
	for i := end; i < value.len; i += 1 {value.data[i - shift] = value.data[i]}
	value.len -= shift
	value.caret = start
	value.anchor = start
	return true
}

// Multi-line text input. Lines break only on explicit '\n' (Enter inserts
// one); content below the box is clipped rather than scrolled. Shares the
// single-line input's focus plumbing: click to focus, click outside to blur.
// Half-open byte range of one visual row. In no-wrap mode there's one
// visual line per '\n' segment. In wrap mode a logical line can be
// broken into several visual lines at word boundaries, each with its
// own [start, end). ends_with_nl marks rows whose end is a '\n' —
// used by the selection highlight to extend the band past the last
// rune when the selection crosses the newline.
Visual_Line :: struct {
	start, end:     int,
	ends_with_nl:   bool,
}

textarea :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	placeholder: string,
	value: ^Text_Area,
	wrap: bool = false,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	hover := contains(c, r)
	if hover {c.pointer_cursor = true}
	pad_x: f32 = 14
	pad_y: f32 = 10
	line_height: f32 = 22
	assert(
		c.measure_text != nil,
		"Textarea layout requires a text measurement callback",
	)
	// Visual lines: one per rendered row. Without wrap, they match '\n'
	// segments; with wrap, long logical lines break at word boundaries so
	// the whole paragraph fits the text width. Backed by the temp allocator
	// so the array sizes to whatever the buffer needs this frame and gets
	// freed by the host's free_all at frame end.
	visual_lines := make([dynamic]Visual_Line, 0, 16, context.temp_allocator)
	emit_vl :: proc(vls: ^[dynamic]Visual_Line, s, e: int, nl: bool) {
		append(vls, Visual_Line{s, e, nl})
	}
	// In wrap mode, reserve the vertical-scrollbar gutter upfront so the
	// wrap width is stable regardless of whether vertical overflow kicks
	// in — avoids a two-pass layout.
	initial_right_gutter: f32 = wrap ? 14 : 2
	text_w := r.w - initial_right_gutter - pad_x * 2
	content_w := pad_x * 2
	if wrap {
		cur_line_start := 0
		line_w: f32 = 0
		last_break: int = -1 // byte offset right after the last space we saw
		pos := 0
		for pos < value.len {
			if value.data[pos] == '\n' {
				emit_vl(&visual_lines,cur_line_start, pos, true)
				pos += 1
				cur_line_start = pos
				line_w = 0
				last_break = -1
				continue
			}
			_, rs := utf8.decode_rune_in_bytes(value.data[pos:value.len])
			if rs == 0 {rs = 1}
			rune_end := pos + rs
			char_w := c.measure_text(string(value.data[pos:rune_end]), 17)
			if line_w + char_w > text_w && cur_line_start < pos {
				if last_break > cur_line_start {
					emit_vl(&visual_lines,cur_line_start, last_break, false)
					cur_line_start = last_break
					pos = cur_line_start
				} else {
					emit_vl(&visual_lines,cur_line_start, pos, false)
					cur_line_start = pos
				}
				line_w = 0
				last_break = -1
				continue
			}
			line_w += char_w
			if value.data[pos] == ' ' {last_break = rune_end}
			pos = rune_end
		}
		emit_vl(&visual_lines,cur_line_start, value.len, false)
	} else {
		ls := 0
		for i in 0 ..< value.len {
			if value.data[i] == '\n' {
				emit_vl(&visual_lines,ls, i, true)
				w := c.measure_text(string(value.data[ls:i]), 17)
				if w + pad_x * 2 > content_w {content_w = w + pad_x * 2}
				ls = i + 1
			}
		}
		emit_vl(&visual_lines,ls, value.len, false)
		w := c.measure_text(string(value.data[ls:value.len]), 17)
		if w + pad_x * 2 > content_w {content_w = w + pad_x * 2}
	}
	if len(visual_lines) == 0 {emit_vl(&visual_lines, 0, 0, false)}
	content_h := pad_y * 2 + f32(len(visual_lines)) * line_height
	// Decide whether each scrollbar is needed, then subtract the gutter
	// the other one eats so the inner view size reflects reality. Wrap
	// mode never allows horizontal scroll.
	need_v := content_h > r.h
	need_h := !wrap && content_w > r.w
	right_gutter: f32 = need_v || wrap ? 14 : 2
	bottom_gutter: f32 = need_h ? 14 : 2
	view_w := r.w - right_gutter
	view_h := r.h - bottom_gutter
	max_scroll := max(0, content_h - view_h)
	max_scroll_x := wrap ? 0 : max(0, content_w - view_w)
	// Vertical scrollbar track — shortened when the horizontal scrollbar
	// occupies the bottom gutter so they don't overlap at the corner.
	track_x: f32 = r.x + r.w - 8
	track_w: f32 = 3
	track_y: f32 = r.y + 6
	track_h: f32 = r.h - 12 - (need_h ? bottom_gutter : 0)
	thumb_hit := Rect{r.x + r.w - 14, r.y + 4, 14, track_h + 4}
	thumb_h: f32
	thumb_y: f32
	thumb_hovered: bool
	if max_scroll > 0 {
		thumb_h = max(24, track_h * view_h / content_h)
		travel := track_h - thumb_h
		thumb_y = track_y + (travel > 0 ? travel * value.scroll / max_scroll : 0)
		thumb_hovered = contains(c, thumb_hit)
	}
	// Horizontal scrollbar track — mirrors the vertical one at the bottom.
	htrack_x: f32 = r.x + 6
	htrack_y: f32 = r.y + r.h - 8
	htrack_w: f32 = r.w - 12 - (need_v ? right_gutter : 0)
	htrack_h: f32 = 3
	hthumb_hit := Rect{r.x + 4, r.y + r.h - 14, htrack_w + 4, 14}
	hthumb_w: f32
	hthumb_x: f32
	hthumb_hovered: bool
	if max_scroll_x > 0 {
		hthumb_w = max(24, htrack_w * view_w / content_w)
		travel := htrack_w - hthumb_w
		hthumb_x = htrack_x + (travel > 0 ? travel * value.scroll_x / max_scroll_x : 0)
		hthumb_hovered = contains(c, hthumb_hit)
	}
	// Resolves the mouse position to a caret byte index. Shared by initial
	// press and the ongoing drag-select path.
	mouse_to_caret :: proc(
		c: ^Context,
		r: Rect,
		data: []u8,
		vls: []Visual_Line,
		scroll, scroll_x, pad_x, pad_y, line_height: f32,
	) -> int {
		local_y := c.my - (r.y + c.offset_y) - pad_y + scroll
		line_i := clamp(int(local_y / line_height), 0, len(vls) - 1)
		vl := vls[line_i]
		return textarea_x_to_caret(c, data, vl.start, vl.end, c.mx - r.x - pad_x + scroll_x)
	}
	// Returns the index of the visual line that owns the given byte
	// position. On a wrap boundary (caret == end of a non-newline line)
	// the caret belongs to the next line, matching the usual "just
	// inserted a wrap" cursor placement. On a '\n' boundary it stays on
	// the preceding line, before the newline.
	vl_of_caret :: proc(vls: []Visual_Line, caret: int) -> int {
		for i in 0 ..< len(vls) {
			if caret < vls[i].end {return i}
			if caret == vls[i].end {
				if vls[i].ends_with_nl {return i}
				if i == len(vls) - 1 {return i}
			}
		}
		return len(vls) - 1
	}
	// Press routing: scrollbar wins over text. A press inside the thumb hit
	// zone starts a drag and focuses the widget without moving the caret;
	// a press anywhere else inside r focuses, positions the caret, and
	// begins a drag-select that runs until mouse-up. Shift extends the
	// existing selection instead of collapsing it.
	if c.pressed {
		if max_scroll > 0 && thumb_hovered {
			value.dragging = true
			value.grab_y =
				c.my >= thumb_y && c.my < thumb_y + thumb_h ? c.my - thumb_y : thumb_h / 2
			c.focused = id
		} else if max_scroll_x > 0 && hthumb_hovered {
			value.dragging_x = true
			value.grab_x =
				c.mx >= hthumb_x && c.mx < hthumb_x + hthumb_w ? c.mx - hthumb_x : hthumb_w / 2
			c.focused = id
		} else if hover {
			c.focused = id
			// Any click in the text area starts a new edit group so the
			// next keystroke doesn't coalesce with earlier typing.
			value.last_edit_kind = .None
			assert(
				c.measure_text != nil,
				"Textarea click positioning requires a text measurement callback",
			)
			new_caret := mouse_to_caret(
				c,
				r,
				value.data[:value.len],
				visual_lines[:],
				value.scroll,
				value.scroll_x,
				pad_x,
				pad_y,
				line_height,
			)
			if c.triple_click {
				// Select the whole clicked line, trailing newline included
				// so cut / paste moves the line as a unit; the last line
				// has no newline to include.
				ls := textarea_line_start(value.data[:value.len], new_caret)
				le := textarea_line_end(value.data[:value.len], new_caret)
				if le < value.len && value.data[le] == '\n' {le += 1}
				value.anchor = ls
				value.caret = le
			} else if c.double_click {
				// Expand to word boundaries around the click, bounded by
				// the enclosing line so the selection never crosses a '\n'.
				ls := textarea_line_start(value.data[:value.len], new_caret)
				le := textarea_line_end(value.data[:value.len], new_caret)
				ws, we := textarea_word_bounds(
					value.data[:value.len],
					new_caret,
					ls,
					le,
				)
				value.anchor = ws
				value.caret = we
			} else {
				if !c.mouse_shift {value.anchor = new_caret}
				value.caret = new_caret
				value.text_dragging = true
			}
			value.goal_sticky = false
		} else if c.focused == id {
			c.focused = 0
		}
	}
	if value.text_dragging {
		if c.down {
			value.caret = mouse_to_caret(
				c,
				r,
				value.data[:value.len],
				visual_lines[:],
				value.scroll,
				value.scroll_x,
				pad_x,
				pad_y,
				line_height,
			)
		} else {
			value.text_dragging = false
		}
	}
	focused := c.focused == id
	edited := false
	navigated := false
	if focused {
		// Any non-edit interaction this frame flushes the coalescing kind,
		// so the next keystroke opens a fresh undo entry.
		if c.nav_left ||
		   c.nav_right ||
		   c.nav_up ||
		   c.nav_down ||
		   c.nav_home ||
		   c.nav_end ||
		   c.nav_page_up ||
		   c.nav_page_down ||
		   c.select_all {
			value.last_edit_kind = .None
		}
		// Undo / redo swap the current state with the top of the undo or
		// redo stack. Reported as navigation so auto-follow brings the
		// restored caret into view.
		if c.undo_request && textarea_undo(value) {
			navigated = true
			value.goal_sticky = false
		}
		if c.redo_request && textarea_redo(value) {
			navigated = true
			value.goal_sticky = false
		}
		// Horizontal moves clear the sticky goal column; vertical moves
		// anchor it on first press and reuse it on subsequent presses.
		// nav_shift extends the selection — the caret moves but the anchor
		// stays — otherwise the selection collapses to the caret.
		if c.nav_left && value.caret > 0 {
			if c.nav_line {
				value.caret = textarea_line_start(value.data[:value.len], value.caret)
			} else if c.nav_word {
				value.caret = textarea_prev_word(value.data[:value.len], value.caret)
			} else {
				new := value.caret - 1
				for new > 0 && (value.data[new] & 0xC0) == 0x80 {new -= 1}
				value.caret = new
			}
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_right && value.caret < value.len {
			if c.nav_line {
				value.caret = textarea_line_end(value.data[:value.len], value.caret)
			} else if c.nav_word {
				value.caret = textarea_next_word(value.data[:value.len], value.caret)
			} else {
				_, rs := utf8.decode_rune_in_string(
					string(value.data[value.caret:value.len]),
				)
				value.caret = min(value.caret + rs, value.len)
			}
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_home {
			value.caret = visual_lines[vl_of_caret(visual_lines[:], value.caret)].start
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_end {
			value.caret = visual_lines[vl_of_caret(visual_lines[:], value.caret)].end
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_up || c.nav_down || c.nav_page_up || c.nav_page_down {
			if !value.goal_sticky {
				assert(
					c.measure_text != nil,
					"Vertical navigation requires a text measurement callback",
				)
				cur_vl := visual_lines[vl_of_caret(visual_lines[:], value.caret)]
				value.goal_x = c.measure_text(
					string(value.data[cur_vl.start:value.caret]),
					17,
				)
				value.goal_sticky = true
			}
			cur_i := vl_of_caret(visual_lines[:], value.caret)
			target_i := cur_i
			if c.nav_up {target_i = max(0, cur_i - 1)}
			if c.nav_down {target_i = min(len(visual_lines) - 1, cur_i + 1)}
			// Page keys step by rows that fit in the view, minus one so a row
			// of overlap stays visible between pages.
			rows := max(1, int(view_h / line_height) - 1)
			if c.nav_page_up {target_i = max(0, cur_i - rows)}
			if c.nav_page_down {target_i = min(len(visual_lines) - 1, cur_i + rows)}
			if target_i != cur_i {
				vl := visual_lines[target_i]
				value.caret = textarea_x_to_caret(
					c,
					value.data[:value.len],
					vl.start,
					vl.end,
					value.goal_x,
				)
				navigated = true
			}
		}
		if navigated && !c.nav_shift {value.anchor = value.caret}
		// Select-all stretches the selection across the whole buffer; the
		// view stays where it is, matching conventional editor behavior.
		if c.select_all {
			value.anchor = 0
			value.caret = value.len
			value.goal_sticky = false
		}
		// Copy and cut hand the selected bytes to the host clipboard via
		// the backend-supplied callback. Cut also deletes the selection
		// and routes through textarea_delete_selection so it counts as an
		// edit (caret follow, goal column reset).
		if (c.copy_request || c.cut_request) &&
		   value.anchor != value.caret &&
		   c.set_clipboard != nil {
			s := min(value.anchor, value.caret)
			e := max(value.anchor, value.caret)
			c.set_clipboard(string(value.data[s:e]))
		}
		if c.cut_request && value.anchor != value.caret {
			textarea_begin_edit(value, .Other)
			if textarea_delete_selection(value) {
				edited = true
				value.goal_sticky = false
			}
		}
		// Paste replaces any current selection with the clipboard text.
		if c.paste_len > 0 {
			textarea_begin_edit(value, .Other)
			_ = textarea_delete_selection(value)
			if textarea_insert(value, c.paste[:c.paste_len]) > 0 {
				edited = true
				value.goal_sticky = false
			}
		}
		// Backspace with a selection deletes the selection as one
		// "other" edit; a run of single-rune backspaces coalesces as
		// .Delete so one Ctrl+Z undoes the whole run.
		if c.backspace {
			if value.anchor != value.caret {
				textarea_begin_edit(value, .Other)
				if textarea_delete_selection(value) {
					edited = true
					value.goal_sticky = false
				}
			} else if value.caret > 0 {
				textarea_begin_edit(value, .Delete)
				if textarea_backspace(value) {
					edited = true
					value.goal_sticky = false
				}
			}
		}
		if c.enter {
			textarea_begin_edit(value, .Other)
			_ = textarea_delete_selection(value)
			nl := [1]u8{'\n'}
			if textarea_insert(value, nl[:]) > 0 {
				edited = true
				value.goal_sticky = false
			}
		}
		if c.typed_len > 0 {
			kind: Edit_Kind = value.anchor != value.caret ? .Other : .Insert
			textarea_begin_edit(value, kind)
			_ = textarea_delete_selection(value)
			if textarea_insert(value, c.typed[:c.typed_len]) > 0 {
				edited = true
				value.goal_sticky = false
			}
		}
		c.typed_len = 0
		c.backspace = false
		c.enter = false
		c.nav_left = false
		c.nav_right = false
		c.nav_up = false
		c.nav_down = false
		c.nav_home = false
		c.nav_end = false
		c.nav_page_up = false
		c.nav_page_down = false
	}
	// Rebuild the visual layout after an edit so follow-caret math and the
	// scrollbars reflect just-typed newlines, wrap breaks or deleted runes.
	// Gutter sizes stay as decided up top; the next frame catches up when
	// a line grows past the viewport for the first time.
	if edited {
		clear(&visual_lines)
		content_w = pad_x * 2
		if wrap {
			cur_line_start := 0
			line_w: f32 = 0
			last_break: int = -1
			pos := 0
			for pos < value.len {
				if value.data[pos] == '\n' {
					emit_vl(&visual_lines,cur_line_start, pos, true)
					pos += 1
					cur_line_start = pos
					line_w = 0
					last_break = -1
					continue
				}
				_, rs := utf8.decode_rune_in_bytes(value.data[pos:value.len])
				if rs == 0 {rs = 1}
				rune_end := pos + rs
				char_w := c.measure_text(string(value.data[pos:rune_end]), 17)
				if line_w + char_w > text_w && cur_line_start < pos {
					if last_break > cur_line_start {
						emit_vl(&visual_lines,cur_line_start, last_break, false)
						cur_line_start = last_break
						pos = cur_line_start
					} else {
						emit_vl(&visual_lines,cur_line_start, pos, false)
						cur_line_start = pos
					}
					line_w = 0
					last_break = -1
					continue
				}
				line_w += char_w
				if value.data[pos] == ' ' {last_break = rune_end}
				pos = rune_end
			}
			emit_vl(&visual_lines,cur_line_start, value.len, false)
		} else {
			ls := 0
			for i in 0 ..< value.len {
				if value.data[i] == '\n' {
					emit_vl(&visual_lines,ls, i, true)
					w := c.measure_text(string(value.data[ls:i]), 17)
					if w + pad_x * 2 > content_w {content_w = w + pad_x * 2}
					ls = i + 1
				}
			}
			emit_vl(&visual_lines,ls, value.len, false)
			w := c.measure_text(string(value.data[ls:value.len]), 17)
			if w + pad_x * 2 > content_w {content_w = w + pad_x * 2}
		}
		if len(visual_lines) == 0 {emit_vl(&visual_lines, 0, 0, false)}
		content_h = pad_y * 2 + f32(len(visual_lines)) * line_height
		max_scroll = max(0, content_h - view_h)
		max_scroll_x = wrap ? 0 : max(0, content_w - view_w)
	}
	// Locate the caret within the visual layout.
	caret_vl_i := vl_of_caret(visual_lines[:], value.caret)
	caret_line_start := visual_lines[caret_vl_i].start
	caret_line := caret_vl_i
	// Follow the caret on edit and navigation frames, in both directions. A
	// pure wheel / drag frame leaves scroll alone so the viewer isn't
	// yanked back.
	if edited || navigated {
		caret_top := pad_y + f32(caret_line) * line_height
		caret_bottom := caret_top + line_height
		if caret_bottom > value.scroll + view_h {
			value.scroll = caret_bottom - view_h
		} else if caret_top < value.scroll {
			value.scroll = caret_top
		}
	}
	if hover && c.wheel_y != 0 {value.scroll += c.wheel_y}
	if hover && c.wheel_x != 0 {value.scroll_x += c.wheel_x}
	if value.dragging {
		travel := track_h - thumb_h
		if travel > 0 {
			value.scroll = (c.my - track_y - value.grab_y) / travel * max_scroll
		}
		if !c.down {value.dragging = false}
	}
	if value.dragging_x {
		travel := htrack_w - hthumb_w
		if travel > 0 {
			value.scroll_x = (c.mx - htrack_x - value.grab_x) / travel * max_scroll_x
		}
		if !c.down {value.dragging_x = false}
	}
	if thumb_hovered || value.dragging || hthumb_hovered || value.dragging_x {
		c.pointer_cursor = true
	}
	// Horizontal caret-follow: pull just enough to keep the caret inside
	// the inner padded rect. Vertical lives inside the edited||navigated
	// branch above; horizontal is split out so a click into a long line
	// also brings the caret into view.
	if edited || navigated {
		caret_content_x := pad_x + c.measure_text(
			string(value.data[caret_line_start:value.caret]),
			17,
		)
		if caret_content_x < value.scroll_x + pad_x {
			value.scroll_x = max(0, caret_content_x - pad_x)
		} else if caret_content_x > value.scroll_x + view_w - pad_x {
			value.scroll_x = caret_content_x - (view_w - pad_x)
		}
	}
	value.scroll = clamp(value.scroll, 0, max_scroll)
	value.scroll_x = clamp(value.scroll_x, 0, max_scroll_x)
	border := DEFAULT_PALETTE.border
	if hover {border = DEFAULT_PALETTE.border_hover}
	if focused {border = DEFAULT_PALETTE.primary_bright}
	box(c, r, border, corner_radius)
	box(
		c,
		{r.x + 1, r.y + 1, r.w - 2, r.h - 2},
		DEFAULT_PALETTE.surface,
		max(0, corner_radius - 1),
	)
	if value.len == 0 && !focused {
		label(
			c,
			r.x + pad_x,
			r.y + pad_y + 17,
			placeholder,
			17,
			DEFAULT_PALETTE.text_muted,
		)
		return
	}
	// Scissor to the interior so partially-visible top / bottom / left /
	// right lines clip instead of jumping. The right and bottom edges
	// shrink when a scrollbar is on, so long lines and low lines don't
	// bleed under the thumbs. Saved and restored because the gallery sets
	// its own page-scroll clip around this call.
	prev_clip := c.clip
	prev_clipped := c.clipped
	c.clip = {r.x + 1, r.y + 1, r.w - 1 - right_gutter, r.h - 1 - bottom_gutter}
	c.clipped = true
	content := string(value.data[:value.len])
	text_x_origin := r.x + pad_x - value.scroll_x
	first_baseline := r.y + pad_y + 17 - value.scroll
	// Draws the selection band for one line as a translucent rect behind
	// the text. A trailing newline that is inside the selection extends the
	// highlight ~a space-width past the last rune so adjacent full-line
	// selections read as one continuous band.
	draw_sel :: proc(
		c: ^Context,
		data: []u8,
		ls, le, ss, se: int,
		baseline, line_height, left_x, right_max: f32,
	) {
		// Clamp the selection endpoints into this line's text range. When
		// the selection crosses the newline terminating this line, show a
		// short trailer past the last rune so adjacent full-line
		// selections read as one continuous band.
		start := clamp(ss, ls, le)
		end := clamp(se, ls, le)
		extend: f32 = 0
		if se > le && ss <= le && le < len(data) && data[le] == '\n' {extend = 8}
		x0 := start > ls ? c.measure_text(string(data[ls:start]), 17) : 0
		x1 := end > ls ? c.measure_text(string(data[ls:end]), 17) : 0
		rect_x := left_x + x0
		rect_w := min((x1 - x0) + extend, right_max - rect_x)
		if rect_w <= 0 {return}
		hi := DEFAULT_PALETTE.primary
		box(
			c,
			{rect_x, baseline - 15, rect_w, line_height - 2},
			{hi[0], hi[1], hi[2], 0.35},
			2,
		)
	}
	s_sel := min(value.anchor, value.caret)
	e_sel := max(value.anchor, value.caret)
	has_sel := focused && s_sel != e_sel
	sel_right_max := r.x + r.w - 1 - right_gutter
	for li in 0 ..< len(visual_lines) {
		vl := visual_lines[li]
		baseline := first_baseline + f32(li) * line_height
		if baseline <= r.y - line_height || baseline - 14 >= r.y + r.h {continue}
		if has_sel {
			draw_sel(
				c,
				value.data[:value.len],
				vl.start,
				vl.end,
				s_sel,
				e_sel,
				baseline,
				line_height,
				text_x_origin,
				sel_right_max,
			)
		}
		label(c, text_x_origin, baseline, string(value.data[vl.start:vl.end]), 17, DEFAULT_PALETTE.text)
	}
	if focused {
		caret_prefix := string(value.data[caret_line_start:value.caret])
		caret_x := text_x_origin + c.measure_text(caret_prefix, 17)
		caret_baseline := first_baseline + f32(caret_line) * line_height
		box(
			c,
			{caret_x, caret_baseline - 14, 1, 18},
			DEFAULT_PALETTE.primary_bright,
		)
	}
	c.clip = prev_clip
	c.clipped = prev_clipped
	if max_scroll > 0 {
		travel := track_h - thumb_h
		thumb_y_draw := track_y + (travel > 0 ? travel * value.scroll / max_scroll : 0)
		hot := thumb_hovered || value.dragging
		w: f32 = hot ? 5 : track_w
		alpha: f32 = hot ? 0.95 : 0.75
		center_x := track_x + track_w / 2
		tr := DEFAULT_PALETTE.scroll_track
		th := DEFAULT_PALETTE.scroll_thumb
		box(c, {track_x, track_y, track_w, track_h}, {tr[0], tr[1], tr[2], 0.18}, 1.5)
		box(c, {center_x - w / 2, thumb_y_draw, w, thumb_h}, {th[0], th[1], th[2], alpha}, w / 2)
	}
	if max_scroll_x > 0 {
		travel := htrack_w - hthumb_w
		hthumb_x_draw := htrack_x + (travel > 0 ? travel * value.scroll_x / max_scroll_x : 0)
		hot := hthumb_hovered || value.dragging_x
		h: f32 = hot ? 5 : htrack_h
		alpha: f32 = hot ? 0.95 : 0.75
		center_y := htrack_y + htrack_h / 2
		tr := DEFAULT_PALETTE.scroll_track
		th := DEFAULT_PALETTE.scroll_thumb
		box(c, {htrack_x, htrack_y, htrack_w, htrack_h}, {tr[0], tr[1], tr[2], 0.18}, 1.5)
		box(c, {hthumb_x_draw, center_y - h / 2, hthumb_w, h}, {th[0], th[1], th[2], alpha}, h / 2)
	}
}

Dropdown :: struct {
	selected: int,
	open:     bool,
}

dropdown :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	options: []string,
	value: ^Dropdown,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	assert(len(options) > 0, "Dropdowns require at least one option")
	value.selected = clamp(value.selected, 0, len(options) - 1)
	menu := Rect{r.x, r.y + r.h, r.w, f32(len(options)) * 40 + 2}
	if value.open && c.pressed && !contains(c, r) && !contains(c, menu) {
		value.open = false
	}
	hover, clicked := pressable(c, id, r)
	if clicked {value.open = !value.open}
	border := DEFAULT_PALETTE.border
	if hover || value.open {border = DEFAULT_PALETTE.primary_bright}
	box(c, r, border, corner_radius)
	box(
		c,
		{r.x + 1, r.y + 1, r.w - 2, r.h - 2},
		DEFAULT_PALETTE.surface,
		max(0, corner_radius - 1),
	)
	label(c, r.x + 14, r.y + 29, options[value.selected], 17)
	arrow_x := r.x + r.w - 22
	arrow_y := r.y + r.h / 2
	arrow_color := DEFAULT_PALETTE.text_subtle
	if value.open {
		triangle(
			c,
			arrow_x - 5,
			arrow_y + 3,
			arrow_x + 5,
			arrow_y + 3,
			arrow_x,
			arrow_y - 4,
			arrow_color,
		)
	} else {
		triangle(
			c,
			arrow_x - 5,
			arrow_y - 3,
			arrow_x + 5,
			arrow_y - 3,
			arrow_x,
			arrow_y + 4,
			arrow_color,
		)
	}
	if value.open {
		prev_layer := c.layer
		c.layer = .Overlay
		defer c.layer = prev_layer
		box(c, menu, DEFAULT_PALETTE.overlay_border, corner_radius)
		box(
			c,
			{menu.x + 1, menu.y + 1, menu.w - 2, menu.h - 2},
			DEFAULT_PALETTE.overlay,
			max(0, corner_radius - 1),
		)
		for option, i in options {
			item := Rect{menu.x + 1, menu.y + 1 + f32(i) * 40, menu.w - 2, 40}
			item_hover, item_clicked := pressable(c, sub_id(id, u64(i + 1)), item)
			if item_clicked {value.selected = i; value.open = false}
			item_color := DEFAULT_PALETTE.overlay
			if i == value.selected {item_color = DEFAULT_PALETTE.item_selected}
			if item_hover {item_color = DEFAULT_PALETTE.item_hover}
			item_radius: f32 = 0
			if i == 0 || i == len(options) - 1 {item_radius = max(0, corner_radius - 1)}
			box(c, item, item_color, item_radius)
			// Preserve the panel curves while keeping adjoining row edges square.
			if item_radius > 0 && i == 0 && len(options) > 1 {
				box(c, {item.x, item.y + item.h - item_radius, item.w, item_radius}, item_color)
			}
			if item_radius > 0 && i == len(options) - 1 && len(options) > 1 {
				box(c, {item.x, item.y, item.w, item_radius}, item_color)
			}
			label(c, item.x + 14, item.y + 26, option, 16)
		}
	}
}
