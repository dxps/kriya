package ui

import "core:unicode/utf8"

// Multi-line text buffer. Larger than Text_Input so paragraphs fit; newlines
// are stored verbatim as '\n'. Content is still raw bytes — rune-aware edits
// step past UTF-8 continuation bytes the same way the single-line input does.
// caret is a byte index into data[:len] and must land on a rune boundary;
// every mutation routes through textarea_insert / textarea_backspace so this
// stays invariant. scroll / scroll_x retain the view across frames; dragging,
// grab_y / grab_x retain scrollbar drags; text_dragging retains the mouse
// drag-select state so a drag that leaves the widget keeps extending the
// selection until the button is released.
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

// Multi-line text input. Enter inserts a '\n'; content beyond the view is
// clipped and scrolled. Shares the single-line input's focus plumbing: click
// to focus, click outside to blur. With wrap=false, overlong lines scroll
// horizontally; with wrap=true, long lines break at word boundaries.
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
