package ui

checkbox :: proc(
	c: ^Context,
	id: u64,
	x, y: f32,
	text: string,
	value: ^bool,
	read_only := false,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	r := Rect{x, y, 18, 18}
	hit := r
	if len(text) > 0 {
		assert(c.measure_text != nil, "Checkbox labels require a text measurement callback")
		hit.w = 28 + c.measure_text(text, 18)
	}
	// Read-only skips the pressable call so clicks don't flip the value or
	// steal the pointer cursor, and the active-color accents (hover /
	// pressed) are suppressed. The box still shows the current state —
	// drawn in the palette's disabled tone — so the value stays readable.
	hover: bool
	if !read_only {
		clicked: bool
		hover, clicked = pressable(c, id, hit)
		if clicked {value^ = !value^}
	}
	border := DEFAULT_PALETTE.primary
	if read_only {
		border = DEFAULT_PALETTE.disabled
	} else {
		if hover {border = DEFAULT_PALETTE.primary_hover}
		if c.active == id && c.down {border = DEFAULT_PALETTE.primary_pressed}
	}
	box(c, r, border, corner_radius)
	// One logical pixel of border, independent of the checked indicator.
	box(c, {x + 1, y + 1, 16, 16}, DEFAULT_PALETTE.surface_raised, max(0, corner_radius - 1))
	if value^ {box(c, {x + 3, y + 3, 12, 12}, border, max(0, corner_radius - 3))}
	label(c, x + 28, y + 14, text)
}
