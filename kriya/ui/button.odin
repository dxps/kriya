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
	focused: bool
	if !disabled {
		hover, clicked = pressable(c, id, r)
		focused = focusable(c, id, r)
		if focused && c.enter {clicked = true}
	}
	color := palette(c).primary
	if hover {color = palette(c).primary_hover}
	if c.active == id && c.down {color = palette(c).primary_pressed}
	if disabled {color = palette(c).disabled}
	if focused {focus_ring(c, r, corner_radius)}
	box(
		c,
		r,
		color,
		corner_radius,
	); label(c, r.x + 18, r.y + 28, text, 18, palette(c).text_on_primary)
	return clicked
}
