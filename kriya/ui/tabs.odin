package ui

// Horizontal tab strip. No outer frame — each tab sizes to its label
// with uniform horizontal padding, laid out left-to-right from r.x.
// The selected tab shows a primary-colored underline; a thin divider
// runs across the whole strip's bottom edge. Click selects; left /
// right arrows walk the selection when focused, clamped at the ends.
// 'selected' is a bare ^int, same convention as 'radio' / 'segmented'.
//
// If the tabs' natural total width exceeds r.w, they simply extend past
// the right edge; a scrollable-tabs variant is a separate concern.
TAB_PAD_X :: f32(18)
TAB_UNDERLINE_H :: f32(2)

tabs :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	options: []string,
	selected: ^int,
	read_only := false,
) {
	assert(len(options) > 0, "Tabs require at least one option")
	assert(c.measure_text != nil, "Tabs require a text measurement callback")

	n := len(options)
	widths := make([]f32, n, context.temp_allocator)
	for option, i in options {
		widths[i] = c.measure_text(option, 17) + 2 * TAB_PAD_X
	}

	hover_idx: int = -1
	focused: bool
	if !read_only {
		focused = focusable(c, id, r)
		cx := r.x
		for w, i in widths {
			tab_rect := Rect{cx, r.y, w, r.h}
			if contains(c, tab_rect) {
				hover_idx = i
				c.pointer_cursor = true
				if c.pressed {
					selected^ = i
					c.active = id
				}
				break
			}
			cx += w
		}
		if c.released && c.active == id {c.active = 0}
		if focused {
			if c.nav_left && selected^ > 0 {selected^ -= 1}
			if c.nav_right && selected^ < n - 1 {selected^ += 1}
		}
	}
	selected^ = clamp(selected^, 0, n - 1)

	if focused {focus_ring(c, r, 0)}

	// Base divider across the whole strip. The selected tab's underline
	// paints over it with a wider 2 px bar.
	box(c, {r.x, r.y + r.h - 1, r.w, 1}, palette(c).divider, 0)

	cx := r.x
	for option, i in options {
		w := widths[i]
		tab_rect := Rect{cx, r.y, w, r.h}

		text_color: Color
		if read_only {
			text_color = palette(c).text_subtle
		} else if i == selected^ {
			text_color = palette(c).text
		} else if hover_idx == i {
			text_color = palette(c).text
		} else {
			text_color = palette(c).text_muted
		}
		label_in(c, tab_rect, option, 17, .Center, .Center, color = text_color)

		if i == selected^ {
			under_color := read_only ? palette(c).disabled : palette(c).primary
			box(
				c,
				{cx + TAB_PAD_X, r.y + r.h - TAB_UNDERLINE_H, w - 2 * TAB_PAD_X, TAB_UNDERLINE_H},
				under_color,
				0,
			)
		}
		cx += w
	}
}
