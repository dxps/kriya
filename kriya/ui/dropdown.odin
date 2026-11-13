package ui

Dropdown :: struct {
	selected: int,
	open:     bool,
}

dropdown :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	options: []string,
	value: ^Dropdown,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	assert(len(options) > 0, "Dropdowns require at least one option")
	value.selected = clamp(value.selected, 0, len(options) - 1)
	menu := Rect{r.x, r.y + r.h, r.w, f32(len(options)) * 40 + 2}
	if value.open && c.pressed && !contains(c, r) && !contains(c, menu) {
		value.open = false
	}
	hover, clicked := pressable(c, id, r)
	if clicked {value.open = !value.open}
	border := DEFAULT_PALETTE.border
	if hover || value.open {border = DEFAULT_PALETTE.primary_bright}
	box(c, r, border, corner_radius)
	box(
		c,
		{r.x + 1, r.y + 1, r.w - 2, r.h - 2},
		DEFAULT_PALETTE.surface,
		max(0, corner_radius - 1),
	)
	label(c, r.x + 14, r.y + 29, options[value.selected], 17)
	arrow_x := r.x + r.w - 22
	arrow_y := r.y + r.h / 2
	arrow_color := DEFAULT_PALETTE.text_subtle
	if value.open {
		triangle(
			c,
			arrow_x - 5,
			arrow_y + 3,
			arrow_x + 5,
			arrow_y + 3,
			arrow_x,
			arrow_y - 4,
			arrow_color,
		)
	} else {
		triangle(
			c,
			arrow_x - 5,
			arrow_y - 3,
			arrow_x + 5,
			arrow_y - 3,
			arrow_x,
			arrow_y + 4,
			arrow_color,
		)
	}
	if value.open {
		prev_layer := c.layer
		c.layer = .Overlay
		defer c.layer = prev_layer
		box(c, menu, DEFAULT_PALETTE.overlay_border, corner_radius)
		box(
			c,
			{menu.x + 1, menu.y + 1, menu.w - 2, menu.h - 2},
			DEFAULT_PALETTE.overlay,
			max(0, corner_radius - 1),
		)
		for option, i in options {
			item := Rect{menu.x + 1, menu.y + 1 + f32(i) * 40, menu.w - 2, 40}
			item_hover, item_clicked := pressable(c, sub_id(id, u64(i + 1)), item)
			if item_clicked {value.selected = i; value.open = false}
			item_color := DEFAULT_PALETTE.overlay
			if i == value.selected {item_color = DEFAULT_PALETTE.item_selected}
			if item_hover {item_color = DEFAULT_PALETTE.item_hover}
			item_radius: f32 = 0
			if i == 0 || i == len(options) - 1 {item_radius = max(0, corner_radius - 1)}
			box(c, item, item_color, item_radius)
			// Preserve the panel curves while keeping adjoining row edges square.
			if item_radius > 0 && i == 0 && len(options) > 1 {
				box(c, {item.x, item.y + item.h - item_radius, item.w, item_radius}, item_color)
			}
			if item_radius > 0 && i == len(options) - 1 && len(options) > 1 {
				box(c, {item.x, item.y, item.w, item_radius}, item_color)
			}
			label(c, item.x + 14, item.y + 26, option, 16)
		}
	}
}
