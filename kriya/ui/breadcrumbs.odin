package ui

// Navigation trail — a horizontal row of clickable path segments
// separated by small right-pointing filled triangles. The last
// crumb is the current page: rendered in the base text color (not
// muted) and NOT hit-tested, so clicking it does nothing — there's
// nowhere to go when you're already here.
//
// Returns the index of the crumb clicked this frame, or -1 when no
// crumb was clicked, matching modal's "no action yet" signal. A
// derived sub-id is used per crumb so a page with several
// breadcrumb rows can share one base_id without collisions.
breadcrumbs :: proc(c: ^Context, base_id: u64, r: Rect, crumbs: []string) -> int {
	assert(c.measure_text != nil, "breadcrumbs requires a text measurement callback")
	clicked := -1
	pal := palette(c)
	size := f32(15)
	x := r.x
	for crumb, i in crumbs {
		w := c.measure_text(crumb, size)
		is_last := i == len(crumbs) - 1
		slot := Rect{x, r.y, w, r.h}
		color: Color
		if is_last {
			color = pal.text
		} else {
			hover, released := pressable(c, sub_id(base_id, u64(i)), slot)
			color = hover ? pal.text : pal.text_muted
			if released {clicked = i}
		}
		label_in(c, slot, crumb, size, .Start, .Center, color = color)
		x += w
		if is_last {break}

		// Separator: small right-pointing filled triangle, same
		// idiom as the accordion / sidebar / dropdown disclosure
		// arrows. BREADCRUMB_SEP_GAP of breathing room on each
		// side keeps the crumbs reading as separate words rather
		// than a slash-glued path.
		cx := x + BREADCRUMB_SEP_GAP + 3
		cy := r.y + r.h / 2
		triangle(c, cx - 3, cy - 4, cx - 3, cy + 4, cx + 3, cy, pal.text_subtle)
		x += 2 * BREADCRUMB_SEP_GAP + 6
	}
	return clicked
}

BREADCRUMB_SEP_GAP :: f32(8)
