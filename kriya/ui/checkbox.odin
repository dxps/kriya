package ui

// Takes a Rect but only uses r.x and r.y: the checkbox draws its own
// fixed 18×18 box and label, so the caller's width and height are
// ignored. Lets a layout slot flow straight in — ui.checkbox(c, id,
// ui.next(&s, 18), ...) — and matches the Rect-taking signature of
// button, input, dropdown, slider and textarea.
checkbox :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	text: string,
	value: ^bool,
	read_only := false,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	box_r := Rect{r.x, r.y, 18, 18}
	hit := box_r
	if len(text) > 0 {
		assert(c.measure_text != nil, "Checkbox labels require a text measurement callback")
		hit.w = 28 + c.measure_text(text, 18)
	}
	// Read-only skips the pressable call so clicks don't flip the value or
	// steal the pointer cursor, and the active-color accents (hover /
	// pressed) are suppressed. The box still shows the current state —
	// drawn in the palette's disabled tone — so the value stays readable.
	hover: bool
	focused: bool
	if !read_only {
		clicked: bool
		hover, clicked = pressable(c, id, hit)
		focused = focusable(c, id, hit)
		if focused && c.enter {clicked = true}
		if clicked {value^ = !value^}
	}
	border := DEFAULT_PALETTE.primary
	if read_only {
		border = DEFAULT_PALETTE.disabled
	} else {
		if hover {border = DEFAULT_PALETTE.primary_hover}
		if c.active == id && c.down {border = DEFAULT_PALETTE.primary_pressed}
	}
	if focused {focus_ring(c, box_r, corner_radius)}
	box(c, box_r, border, corner_radius)
	// One logical pixel of border, independent of the checked indicator.
	box(c, {r.x + 1, r.y + 1, 16, 16}, DEFAULT_PALETTE.surface_raised, max(0, corner_radius - 1))
	if value^ {box(c, {r.x + 3, r.y + 3, 12, 12}, border, max(0, corner_radius - 3))}
	label(c, r.x + 28, r.y + 14, text)
}
