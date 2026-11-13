package ui

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
