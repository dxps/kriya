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
	nav_shift:               bool,
	mouse_shift:             bool,
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
	c.typed_len = 0
	c.backspace = false
	c.enter = false
	c.nav_left = false
	c.nav_right = false
	c.nav_up = false
	c.nav_down = false
	c.nav_home = false
	c.nav_end = false
	c.nav_shift = false
	c.mouse_shift = false}
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
	// text_dragging retains the mouse-drag select state across frames so a
	// drag that leaves the widget keeps extending the selection until the
	// button is released.
	text_dragging: bool,
}

set_area_text :: proc(value: ^Text_Area, text: string) {
	value.len = min(len(text), len(value.data))
	copy(value.data[:value.len], transmute([]u8)text[:value.len])
	value.caret = value.len
	value.anchor = value.len
	value.goal_sticky = false
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
textarea :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	placeholder: string,
	value: ^Text_Area,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	hover := contains(c, r)
	if hover {c.pointer_cursor = true}
	pad_x: f32 = 14
	pad_y: f32 = 10
	line_height: f32 = 22
	view_h := r.h
	line_count := 1
	for i in 0 ..< value.len {
		if value.data[i] == '\n' {line_count += 1}
	}
	content_h := pad_y * 2 + f32(line_count) * line_height
	max_scroll := max(0, content_h - view_h)
	// Scrollbar track geometry, reused by the drag hit test and by the
	// scrollbar visual. thumb_h stays 0 when there is no overflow — the drag
	// block below guards on max_scroll before using it.
	track_x: f32 = r.x + r.w - 8
	track_w: f32 = 3
	track_y: f32 = r.y + 6
	track_h: f32 = r.h - 12
	thumb_hit := Rect{r.x + r.w - 14, r.y + 4, 14, r.h - 8}
	thumb_h: f32
	thumb_y: f32
	thumb_hovered: bool
	if max_scroll > 0 {
		thumb_h = max(24, track_h * view_h / content_h)
		travel := track_h - thumb_h
		thumb_y = track_y + (travel > 0 ? travel * value.scroll / max_scroll : 0)
		thumb_hovered = contains(c, thumb_hit)
	}
	// Resolves the mouse position to a caret byte index. Shared by initial
	// press and the ongoing drag-select path.
	mouse_to_caret :: proc(
		c: ^Context,
		r: Rect,
		data: []u8,
		scroll, pad_x, pad_y, line_height: f32,
		line_count: int,
	) -> int {
		local_y := c.my - (r.y + c.offset_y) - pad_y + scroll
		line_i := clamp(int(local_y / line_height), 0, line_count - 1)
		start := 0
		li := 0
		for i in 0 ..< len(data) {
			if li == line_i {break}
			if data[i] == '\n' {start = i + 1; li += 1}
		}
		end := textarea_line_end(data, start)
		return textarea_x_to_caret(c, data, start, end, c.mx - r.x - pad_x)
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
		} else if hover {
			c.focused = id
			assert(
				c.measure_text != nil,
				"Textarea click positioning requires a text measurement callback",
			)
			new_caret := mouse_to_caret(
				c,
				r,
				value.data[:value.len],
				value.scroll,
				pad_x,
				pad_y,
				line_height,
				line_count,
			)
			if !c.mouse_shift {value.anchor = new_caret}
			value.caret = new_caret
			value.text_dragging = true
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
				value.scroll,
				pad_x,
				pad_y,
				line_height,
				line_count,
			)
		} else {
			value.text_dragging = false
		}
	}
	focused := c.focused == id
	edited := false
	navigated := false
	if focused {
		// Horizontal moves clear the sticky goal column; vertical moves
		// anchor it on first press and reuse it on subsequent presses.
		// nav_shift extends the selection — the caret moves but the anchor
		// stays — otherwise the selection collapses to the caret.
		if c.nav_left && value.caret > 0 {
			new := value.caret - 1
			for new > 0 && (value.data[new] & 0xC0) == 0x80 {new -= 1}
			value.caret = new
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_right && value.caret < value.len {
			_, rs := utf8.decode_rune_in_string(
				string(value.data[value.caret:value.len]),
			)
			value.caret = min(value.caret + rs, value.len)
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_home {
			value.caret = textarea_line_start(value.data[:value.len], value.caret)
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_end {
			value.caret = textarea_line_end(value.data[:value.len], value.caret)
			value.goal_sticky = false
			navigated = true
		}
		if c.nav_up || c.nav_down {
			if !value.goal_sticky {
				assert(
					c.measure_text != nil,
					"Vertical navigation requires a text measurement callback",
				)
				line_start := textarea_line_start(value.data[:value.len], value.caret)
				value.goal_x = c.measure_text(
					string(value.data[line_start:value.caret]),
					17,
				)
				value.goal_sticky = true
			}
			if c.nav_up {
				cur := textarea_line_start(value.data[:value.len], value.caret)
				if cur > 0 {
					prev := textarea_line_start(value.data[:value.len], cur - 1)
					value.caret = textarea_x_to_caret(
						c,
						value.data[:value.len],
						prev,
						cur - 1,
						value.goal_x,
					)
					navigated = true
				}
			}
			if c.nav_down {
				cur_end := textarea_line_end(value.data[:value.len], value.caret)
				if cur_end < value.len {
					next_start := cur_end + 1
					next_end := textarea_line_end(value.data[:value.len], next_start)
					value.caret = textarea_x_to_caret(
						c,
						value.data[:value.len],
						next_start,
						next_end,
						value.goal_x,
					)
					navigated = true
				}
			}
		}
		if navigated && !c.nav_shift {value.anchor = value.caret}
		// Backspace with a selection deletes the selection; otherwise it
		// removes the rune to the left of the caret.
		if c.backspace {
			if textarea_delete_selection(value) {
				edited = true
				value.goal_sticky = false
			} else if textarea_backspace(value) {
				edited = true
				value.goal_sticky = false
			}
		}
		if c.enter {
			_ = textarea_delete_selection(value)
			nl := [1]u8{'\n'}
			if textarea_insert(value, nl[:]) > 0 {
				edited = true
				value.goal_sticky = false
			}
		}
		if c.typed_len > 0 {
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
	}
	// Recount after the edit so the follow-caret math and scrollbar reflect
	// the just-typed newline or deleted rune.
	if edited {
		line_count = 1
		for i in 0 ..< value.len {
			if value.data[i] == '\n' {line_count += 1}
		}
		content_h = pad_y * 2 + f32(line_count) * line_height
		max_scroll = max(0, content_h - view_h)
	}
	// Locate the caret: line_index + byte offset of its line start.
	caret_line := 0
	caret_line_start := 0
	for i in 0 ..< value.caret {
		if value.data[i] == '\n' {
			caret_line += 1
			caret_line_start = i + 1
		}
	}
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
	if value.dragging {
		travel := track_h - thumb_h
		if travel > 0 {
			value.scroll = (c.my - track_y - value.grab_y) / travel * max_scroll
		}
		if !c.down {value.dragging = false}
	}
	if thumb_hovered || value.dragging {c.pointer_cursor = true}
	value.scroll = clamp(value.scroll, 0, max_scroll)
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
	// Scissor to the interior so partially-visible top / bottom lines clip
	// instead of jumping. The right edge shrinks when a scrollbar is on, so
	// long lines don't bleed under the thumb. Saved and restored because the
	// gallery sets its own page-scroll clip around this call.
	prev_clip := c.clip
	prev_clipped := c.clipped
	right_gutter: f32 = max_scroll > 0 ? 14 : 2
	c.clip = {r.x + 1, r.y + 1, r.w - 1 - right_gutter, r.h - 2}
	c.clipped = true
	content := string(value.data[:value.len])
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
	line_start := 0
	li := 0
	for i in 0 ..< len(content) {
		if content[i] == '\n' {
			baseline := first_baseline + f32(li) * line_height
			if baseline > r.y - line_height && baseline - 14 < r.y + r.h {
				if has_sel {
					draw_sel(
						c,
						value.data[:value.len],
						line_start,
						i,
						s_sel,
						e_sel,
						baseline,
						line_height,
						r.x + pad_x,
						sel_right_max,
					)
				}
				label(c, r.x + pad_x, baseline, content[line_start:i], 17, DEFAULT_PALETTE.text)
			}
			line_start = i + 1
			li += 1
		}
	}
	last_line := content[line_start:]
	last_baseline := first_baseline + f32(li) * line_height
	if last_baseline > r.y - line_height && last_baseline - 14 < r.y + r.h {
		if has_sel {
			draw_sel(
				c,
				value.data[:value.len],
				line_start,
				value.len,
				s_sel,
				e_sel,
				last_baseline,
				line_height,
				r.x + pad_x,
				sel_right_max,
			)
		}
		label(c, r.x + pad_x, last_baseline, last_line, 17, DEFAULT_PALETTE.text)
	}
	if focused {
		assert(c.measure_text != nil, "Focused textareas require a text measurement callback")
		caret_prefix := string(value.data[caret_line_start:value.caret])
		caret_x := r.x + pad_x + c.measure_text(caret_prefix, 17)
		caret_baseline := first_baseline + f32(caret_line) * line_height
		box(
			c,
			{min(caret_x, r.x + r.w - 2 - right_gutter), caret_baseline - 14, 1, 18},
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
