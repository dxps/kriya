package ui

// Horizontal picker of mutually-exclusive options: one segment per entry,
// exactly one highlighted. Click a segment to select it; left / right
// arrows cycle through them when focused. 'selected' is a bare ^int so
// a group of segmented controls can share data with a dropdown or radio
// group without a wrapper struct (same convention as 'radio').
//
// Visual model: outer rounded frame + inset surface; the selected
// segment paints a primary-colored pill over the surface. Hover brightens
// non-selected segments.
segmented :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	options: []string,
	selected: ^int,
	read_only := false,
	radius: Maybe(f32) = nil,
) {
	assert(len(options) > 0, "Segmented control requires at least one option")
	assert(c.measure_text != nil, "Segmented control requires a text measurement callback")

	corner_radius := resolve_corner_radius(c, radius)
	n := len(options)
	seg_w := r.w / f32(n)
	selected^ = clamp(selected^, 0, n - 1)

	hover_idx: int = -1
	focused: bool

	if !read_only {
		focused = focusable(c, id, r)
		if contains(c, r) {
			c.pointer_cursor = true
			local_x := c.mx - r.x
			hover_idx = clamp(int(local_x / seg_w), 0, n - 1)
			if c.pressed {
				selected^ = hover_idx
				c.active = id
			}
			if c.released && c.active == id {c.active = 0}
		}
		// Arrow nav: left / right walk along the segment list, clamped
		// at the ends (no wrap — matches how a real picker feels).
		if focused {
			if c.nav_left && selected^ > 0 {selected^ -= 1}
			if c.nav_right && selected^ < n - 1 {selected^ += 1}
		}
	}

	// Focus ring under the main box so the main box's border masks the
	// ring's interior.
	if focused {focus_ring(c, r, corner_radius)}

	// Outer frame + inset surface.
	border := read_only ? palette(c).disabled : palette(c).border
	box(c, r, border, corner_radius)
	inner_radius := max(0, corner_radius - 1)
	box(c, {r.x + 1, r.y + 1, r.w - 2, r.h - 2}, palette(c).surface_raised, inner_radius)

	// Selected pill. Last segment's width stretches to r.x + r.w - 1 so
	// floating-point seg_w * n doesn't leave a 1 px sliver at the right.
	sel_x := r.x + 1 + f32(selected^) * seg_w
	sel_right := selected^ == n - 1 ? r.x + r.w - 1 : sel_x + seg_w
	sel_fill := read_only ? palette(c).disabled : palette(c).primary
	box(c, {sel_x, r.y + 1, sel_right - sel_x, r.h - 2}, sel_fill, inner_radius)

	// Hover overlay on a non-selected segment.
	if !read_only && hover_idx >= 0 && hover_idx != selected^ {
		hx := r.x + 1 + f32(hover_idx) * seg_w
		right := hover_idx == n - 1 ? r.x + r.w - 1 : hx + seg_w
		box(c, {hx, r.y + 1, right - hx, r.h - 2}, palette(c).item_hover, inner_radius)
	}

	// Labels, centered per segment.
	for option, i in options {
		seg_rect := Rect{r.x + f32(i) * seg_w, r.y, seg_w, r.h}
		text_color: Color
		if read_only {
			text_color = palette(c).text_subtle
		} else if i == selected^ {
			text_color = palette(c).text_on_primary
		} else {
			text_color = palette(c).text
		}
		label_in(c, seg_rect, option, 17, .Center, .Center, color = text_color)
	}
}
