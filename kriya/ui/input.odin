package ui

import "core:unicode/utf8"

// Single-line text input. caret is a byte index into data[:len] and must
// land on a rune boundary; every mutation (typed insert, backspace) walks
// past UTF-8 continuation bytes so the invariant holds. Arrow keys and
// Home / End move it; typed text inserts at it and advances it.
Text_Input :: struct {
	data:     [128]u8,
	len:      int,
	caret:    int,
	revealed: bool,
}

set_text :: proc(value: ^Text_Input, text: string) {
	value.len = min(len(text), len(value.data))
	copy(value.data[:value.len], transmute([]u8)text[:value.len])
	value.caret = value.len
}

// Counts the runes in data[:n]. Used to project a byte offset onto the
// bullet grid in password mode where glyph width is fixed at 14px.
input_rune_count :: proc(data: []u8, n: int) -> int {
	count := 0
	for i in 0 ..< n {
		if (data[i] & 0xC0) != 0x80 {count += 1}
	}
	return count
}

// Steps the caret back one rune, past any UTF-8 continuation bytes.
input_step_back :: proc(data: []u8, caret: int) -> int {
	if caret == 0 {return 0}
	new := caret - 1
	for new > 0 && (data[new] & 0xC0) == 0x80 {new -= 1}
	return new
}

// Removes the rune to the left of caret; returns the new caret.
input_backspace :: proc(value: ^Text_Input) {
	if value.caret == 0 {return}
	end := value.caret
	start := input_step_back(value.data[:value.len], end)
	shift := end - start
	for i := end; i < value.len; i += 1 {value.data[i - shift] = value.data[i]}
	value.len -= shift
	value.caret = start
}

// Shifts the suffix right and copies bytes into the gap at caret.
input_insert :: proc(value: ^Text_Input, bytes: []u8) {
	n := min(len(bytes), len(value.data) - value.len)
	if n <= 0 {return}
	for i := value.len - 1; i >= value.caret; i -= 1 {value.data[i + n] = value.data[i]}
	copy(value.data[value.caret:value.caret + n], bytes[:n])
	value.len += n
	value.caret += n
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
	// Clamp caret into the valid byte range in case the caller shrank the
	// buffer behind our back (set_text, etc).
	value.caret = clamp(value.caret, 0, value.len)
	if focused {
		if c.backspace {input_backspace(value)}
		if c.typed_len > 0 {input_insert(value, c.typed[:c.typed_len])}
		// Horizontal moves only — single-line has no Up / Down. nav_line
		// (Ctrl / Cmd) collapses Left / Right onto Home / End so each
		// host's conventional shortcut jumps to the edges. nav_word (Alt)
		// handled in a later step.
		if c.nav_left && value.caret > 0 {
			value.caret = c.nav_line ? 0 : input_step_back(value.data[:value.len], value.caret)
		}
		if c.nav_right && value.caret < value.len {
			if c.nav_line {
				value.caret = value.len
			} else {
				_, rs := utf8.decode_rune_in_string(string(value.data[value.caret:value.len]))
				value.caret = min(value.caret + rs, value.len)
			}
		}
		if c.nav_home {value.caret = 0}
		if c.nav_end {value.caret = value.len}
		c.typed_len = 0
		c.backspace = false
		c.nav_left = false
		c.nav_right = false
		c.nav_home = false
		c.nav_end = false
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
	rune_count := input_rune_count(value.data[:value.len], value.len)
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
		// Caret-x from the caret's byte offset. Password-bullet mode projects
		// onto the 14px grid; text mode measures the prefix.
		caret_x: f32
		if masked {
			caret_x = r.x + 14 + f32(input_rune_count(value.data[:value.len], value.caret)) * 14
		} else {
			assert(c.measure_text != nil, "Focused inputs require a text measurement callback")
			caret_x = r.x + 14 + c.measure_text(string(value.data[:value.caret]), 17)
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
