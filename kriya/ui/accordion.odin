package ui

// Clickable disclosure row: a filled triangle plus a title fill the
// given rect, hover lights a rounded background behind them. Flips
// 'expanded' on click (so a caller declares one bool per section
// instead of writing the toggle themselves) and returns its post-
// click value — which is also "should the body draw this frame".
//
// Composition: the widget owns the HEADER only. The body's layout
// and content are the caller's job; typical use puts a divider
// between adjacent sections and stacks headers + bodies with ui.col.
// One bool per header keeps the state shape the same as modal's own
// 'open' bit.
accordion :: proc(c: ^Context, id: u64, r: Rect, title: string, expanded: ^bool) -> bool {
	hover, clicked := pressable(c, id, r)
	pal := palette(c)

	// Hover background mirrors sidebar_link: item_hover on pointer-
	// over, item_selected while held down. Rounded to the global
	// radius so it reads as the same family as every other hover
	// affordance.
	if hover {
		bg := pal.item_hover
		if c.active == id && c.down {bg = pal.item_selected}
		box(c, r, bg, DEFAULT_CORNER_RADIUS)
	}

	color := hover ? pal.text : pal.text_muted

	// Triangle apex points down when open, right when closed — the
	// same filled-triangle idiom the sidebar group kicker and
	// dropdown trigger share, so a page of accordions reads as one
	// family with its siblings.
	cx := r.x + 18
	cy := r.y + r.h / 2
	if expanded^ {
		triangle(c, cx - 5, cy - 4, cx + 5, cy - 4, cx, cy + 4, color)
	} else {
		triangle(c, cx - 4, cy - 5, cx - 4, cy + 5, cx + 4, cy, color)
	}

	label_in(c, Rect{r.x + 32, r.y, max(0, r.w - 32), r.h}, title, 16, .Start, .Center, color = color)

	if clicked {expanded^ = !expanded^}
	return expanded^
}
