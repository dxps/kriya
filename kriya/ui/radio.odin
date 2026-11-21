package ui

// One option in a radio group. Multiple 'radio' calls share the same
// 'selected' pointer and differ by 'index': clicking (or Enter when
// focused) sets selected^ = index. A radio is always circular — the
// context's corner_radius is ignored since circularity is the control's
// defining visual. Signature parallels checkbox: the Rect carries only
// r.x / r.y, the 18×18 glyph box is fixed.
radio :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	text: string,
	selected: ^int,
	index: int,
	read_only := false,
) {
	box_r := Rect{r.x, r.y, 18, 18}
	hit := box_r
	if len(text) > 0 {
		assert(c.measure_text != nil, "Radio labels require a text measurement callback")
		hit.w = 28 + c.measure_text(text, 18)
	}
	hover: bool
	focused: bool
	chosen := selected^ == index
	if !read_only {
		clicked: bool
		hover, clicked = pressable(c, id, hit)
		focused = focusable(c, id, hit)
		if focused && c.enter {clicked = true}
		if clicked {selected^ = index}
	}
	border := palette(c).primary
	if read_only {
		border = palette(c).disabled
	} else {
		if hover {border = palette(c).primary_hover}
		if c.active == id && c.down {border = palette(c).primary_pressed}
	}
	if focused {focus_ring(c, box_r, 9)}
	// Outer circle (radius 9 fills the 18×18 box).
	box(c, box_r, border, 9)
	// One-pixel border interior.
	box(c, {r.x + 1, r.y + 1, 16, 16}, palette(c).surface_raised, 8)
	// Selected dot — concentric 10×10 circle.
	if chosen {box(c, {r.x + 4, r.y + 4, 10, 10}, border, 5)}
	label(c, r.x + 28, r.y + 14, text)
}
