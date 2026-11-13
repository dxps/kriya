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
	// anchor is the opposite end of the selection. anchor == caret means no
	// selection; otherwise the selected byte range is [min(a, c), max(a, c)).
	anchor:   int,
	// text_dragging retains the mouse drag-select state across frames so a
	// drag that leaves the widget keeps extending the selection until the
	// button is released.
	text_dragging: bool,
	// scroll_x pulls the visible text left so long buffers stay scrollable.
	// The caret-follow at render time keeps the caret inside the view; a
	// trailing clamp keeps empty space from appearing past the end.
	scroll_x: f32,
	revealed: bool,
	// Undo / redo stacks and the kind of the most recent edit. undo holds
	// pre-edit snapshots; redo holds post-undo snapshots so successive
	// redos walk back to where the user was. last_edit_kind drives
	// coalescing: the next edit opens a new entry only when its kind
	// changes (or a non-edit interaction flushes last_edit_kind to .None).
	undo:           [HISTORY_CAP]Input_History_Entry,
	undo_len:       int,
	redo:           [HISTORY_CAP]Input_History_Entry,
	redo_len:       int,
	last_edit_kind: Edit_Kind,
}

set_text :: proc(value: ^Text_Input, text: string) {
	value.len = min(len(text), len(value.data))
	copy(value.data[:value.len], transmute([]u8)text[:value.len])
	value.caret = value.len
	value.anchor = value.len
	value.undo_len = 0
	value.redo_len = 0
	value.last_edit_kind = .None
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

// Removes the rune to the left of caret and collapses the selection.
input_backspace :: proc(value: ^Text_Input) {
	if value.caret == 0 {return}
	end := value.caret
	start := input_step_back(value.data[:value.len], end)
	shift := end - start
	for i := end; i < value.len; i += 1 {value.data[i - shift] = value.data[i]}
	value.len -= shift
	value.caret = start
	value.anchor = start
}

// Removes the selected byte range and collapses caret / anchor to the
// start. Returns true when a selection was deleted.
input_delete_selection :: proc(value: ^Text_Input) -> bool {
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

// Pixel width of data[:caret] in the current display mode. Password-
// bullet mode projects onto the 14px grid; text mode measures the prefix.
input_caret_x :: proc(c: ^Context, data: []u8, caret: int, masked: bool) -> f32 {
	if masked {return f32(input_rune_count(data, caret)) * 14}
	return c.measure_text(string(data[:caret]), 17)
}

// Maps a pixel x (relative to the text origin r.x + 14) to a byte offset.
// Text mode measures the real prefix; password-bullet mode rounds onto the
// 14px grid, then walks that many runes forward.
input_x_to_caret :: proc(c: ^Context, data: []u8, target_x: f32, masked: bool) -> int {
	if !masked {return textarea_x_to_caret(c, data, 0, len(data), target_x)}
	rune_count := input_rune_count(data, len(data))
	target_rune := clamp(int((target_x + 7) / 14), 0, rune_count)
	byte_pos := 0
	runes := 0
	for runes < target_rune && byte_pos < len(data) {
		_, rs := utf8.decode_rune_in_bytes(data[byte_pos:])
		if rs == 0 {rs = 1}
		byte_pos += rs
		runes += 1
	}
	return byte_pos
}

// Shifts the suffix right and copies bytes into the gap at caret, then
// collapses the selection.
input_insert :: proc(value: ^Text_Input, bytes: []u8) {
	n := min(len(bytes), len(value.data) - value.len)
	if n <= 0 {return}
	for i := value.len - 1; i >= value.caret; i -= 1 {value.data[i + n] = value.data[i]}
	copy(value.data[value.caret:value.caret + n], bytes[:n])
	value.len += n
	value.caret += n
	value.anchor = value.caret
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
	pad_x: f32 = 14
	eye_w: f32 = password ? 44 : 0
	text_hit := Rect{r.x, r.y, r.w - eye_w, r.h}
	view_w := r.w - eye_w - pad_x * 2
	if hover {c.pointer_cursor = true}
	masked := password && !value.revealed && value.len > 0
	if c.pressed {
		if contains(c, text_hit) {
			c.focused = id
			// Any click starts a new edit group so the next keystroke
			// doesn't coalesce with earlier typing.
			value.last_edit_kind = .None
			// Position caret at the click. target_x is pixels past the text
			// origin (r.x + pad_x), plus the current horizontal scroll so a
			// click on an already-scrolled line lands on what the user saw.
			target_x := c.mx - r.x - pad_x + value.scroll_x
			new_caret := input_x_to_caret(c, value.data[:value.len], target_x, masked)
			if c.triple_click {
				// Single-line field has no notion of "line" past the whole
				// buffer, so triple-click selects everything.
				value.anchor = 0
				value.caret = value.len
			} else if c.double_click {
				// Expand to word boundaries around the click. Shares the
				// textarea's word scanner since a single line is the degenerate
				// case of a textarea row (line_start = 0, line_end = len).
				ws, we := textarea_word_bounds(value.data[:value.len], new_caret, 0, value.len)
				value.anchor = ws
				value.caret = we
			} else {
				// Shift-click extends the selection: caret moves, anchor stays.
				// Plain click collapses to the clicked position and begins a
				// drag-select that runs until mouse-up.
				if !c.mouse_shift {value.anchor = new_caret}
				value.caret = new_caret
				value.text_dragging = true
			}
		} else if c.focused == id && !hover {c.focused = 0}
	}
	if value.text_dragging {
		if c.down {
			target_x := c.mx - r.x - pad_x + value.scroll_x
			value.caret = input_x_to_caret(c, value.data[:value.len], target_x, masked)
		} else {
			value.text_dragging = false
		}
	}
	focused := c.focused == id
	// Clamp caret into the valid byte range in case the caller shrank the
	// buffer behind our back (set_text, etc).
	value.caret = clamp(value.caret, 0, value.len)
	value.anchor = clamp(value.anchor, 0, value.len)
	navigated := false
	if focused {
		// Any non-edit interaction this frame flushes the coalescing kind,
		// so the next keystroke opens a fresh undo entry.
		if c.nav_left || c.nav_right || c.nav_home || c.nav_end || c.select_all {
			value.last_edit_kind = .None
		}
		// Undo / redo swap current state with the top of the matching stack.
		// Reported as navigation so the caret-follow pass brings the
		// restored caret into view.
		if c.undo_request && input_undo(value) {navigated = true}
		if c.redo_request && input_redo(value) {navigated = true}
		// Select-all stretches the selection across the whole buffer.
		if c.select_all {
			value.anchor = 0
			value.caret = value.len
		}
		// Copy and cut hand the selected bytes to the host clipboard via
		// the backend callback. Masked password mode suppresses both so
		// the raw password can't leave the field through Ctrl+C / Ctrl+X;
		// select-all and paste remain available, matching web password
		// field conventions.
		if (c.copy_request || c.cut_request) &&
		   value.anchor != value.caret &&
		   c.set_clipboard != nil &&
		   !masked {
			s := min(value.anchor, value.caret)
			e := max(value.anchor, value.caret)
			c.set_clipboard(string(value.data[s:e]))
		}
		if c.cut_request && value.anchor != value.caret && !masked {
			input_begin_edit(value, .Other)
			_ = input_delete_selection(value)
		}
		// Paste replaces any current selection with the clipboard text.
		// Single-line fields clip to the first line of a multi-line paste
		// so pasted paragraphs don't wedge an unprintable '\n' in.
		if c.paste_len > 0 {
			input_begin_edit(value, .Other)
			_ = input_delete_selection(value)
			paste_end := c.paste_len
			for i in 0 ..< c.paste_len {
				if c.paste[i] == '\n' || c.paste[i] == '\r' {paste_end = i; break}
			}
			input_insert(value, c.paste[:paste_end])
		}
		// Backspace with a selection deletes the selection as one "other"
		// edit; a run of single-rune backspaces coalesces as .Delete so one
		// undo reverses the whole run.
		if c.backspace {
			if value.anchor != value.caret {
				input_begin_edit(value, .Other)
				_ = input_delete_selection(value)
			} else if value.caret > 0 {
				input_begin_edit(value, .Delete)
				input_backspace(value)
			}
		}
		if c.typed_len > 0 {
			kind: Edit_Kind = value.anchor != value.caret ? .Other : .Insert
			input_begin_edit(value, kind)
			_ = input_delete_selection(value)
			input_insert(value, c.typed[:c.typed_len])
		}
		// Horizontal moves only — single-line has no Up / Down. nav_line
		// (Ctrl / Cmd) collapses Left / Right onto Home / End; nav_word
		// (Alt / Option) steps by word boundary, sharing the textarea's
		// scanner since the single line is one continuous word stream.
		if c.nav_left && value.caret > 0 {
			if c.nav_line {
				value.caret = 0
			} else if c.nav_word {
				value.caret = textarea_prev_word(value.data[:value.len], value.caret)
			} else {
				value.caret = input_step_back(value.data[:value.len], value.caret)
			}
			navigated = true
		}
		if c.nav_right && value.caret < value.len {
			if c.nav_line {
				value.caret = value.len
			} else if c.nav_word {
				value.caret = textarea_next_word(value.data[:value.len], value.caret)
			} else {
				_, rs := utf8.decode_rune_in_string(string(value.data[value.caret:value.len]))
				value.caret = min(value.caret + rs, value.len)
			}
			navigated = true
		}
		if c.nav_home {value.caret = 0; navigated = true}
		if c.nav_end {value.caret = value.len; navigated = true}
		// Shift held: selection extends — caret moves but anchor stays.
		// Otherwise the selection collapses to the caret after the move.
		if navigated && !c.nav_shift {value.anchor = value.caret}
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
	// Edits this frame can toggle masked (typing into an empty password
	// field, backspacing to empty); recompute now that the buffer is final.
	masked = password && !value.revealed && value.len > 0
	// Follow the caret horizontally — pull just enough to keep it inside
	// the inner padded rect — then clamp so the empty tail doesn't appear.
	caret_content_x := input_caret_x(c, value.data[:value.len], value.caret, masked)
	content_w := input_caret_x(c, value.data[:value.len], value.len, masked)
	max_scroll_x := max(0, content_w - view_w)
	if caret_content_x < value.scroll_x {
		value.scroll_x = max(0, caret_content_x)
	} else if caret_content_x > value.scroll_x + view_w {
		value.scroll_x = caret_content_x - view_w
	}
	value.scroll_x = clamp(value.scroll_x, 0, max_scroll_x)
	shown := placeholder
	color := DEFAULT_PALETTE.text_muted
	if value.len > 0 {
		color = DEFAULT_PALETTE.text
		if !masked {
			shown = string(value.data[:value.len])
		}
	}
	rune_count := input_rune_count(value.data[:value.len], value.len)
	// Clip the content to the inner rect (minus the eye gutter) so scrolled
	// text and bullets don't leak into the border or under the eye. Saved
	// and restored so an outer scroll clip is left untouched.
	prev_clip := c.clip
	prev_clipped := c.clipped
	c.clip = {r.x + 1, r.y + 1, r.w - 2 - eye_w, r.h - 2}
	c.clipped = true
	text_x_origin := r.x + pad_x - value.scroll_x
	// Selection band — draw first so text / bullets paint over it.
	if focused && value.anchor != value.caret {
		s_sel := min(value.anchor, value.caret)
		e_sel := max(value.anchor, value.caret)
		start_x := text_x_origin + input_caret_x(c, value.data[:value.len], s_sel, masked)
		end_x := text_x_origin + input_caret_x(c, value.data[:value.len], e_sel, masked)
		hi := DEFAULT_PALETTE.primary
		box(c, {start_x, r.y + 11, end_x - start_x, r.h - 22}, {hi[0], hi[1], hi[2], 0.35}, 2)
	}
	if value.len == 0 {
		// Placeholder isn't scrollable — it stays at the pad origin.
		label(c, r.x + pad_x, r.y + 29, shown, 17, color)
	} else if masked {
		// Draw round password bullets independently of the text font so their
		// shape remains circular at every display scale. One bullet per rune,
		// not per UTF-8 byte.
		bullet_x := text_x_origin
		for _ in 0 ..< rune_count {
			box(c, {bullet_x, r.y + r.h / 2 - 4, 8, 8}, color, 4)
			bullet_x += 14
		}
	} else {
		label(c, text_x_origin, r.y + 29, shown, 17, color)
	}
	if focused {
		caret_x := text_x_origin + caret_content_x
		box(c, {caret_x, r.y + 11, 1, r.h - 22}, DEFAULT_PALETTE.primary_bright)
	}
	c.clip = prev_clip
	c.clipped = prev_clipped
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
