package main

import "core:fmt"
import ui "kriya:ui"

// Live corner-radius setting applied globally via ui.set_corner_radius in
// the frame loop. Default lands on "6", matching ui.DEFAULT_CORNER_RADIUS,
// so the gallery starts out looking the same as before.
radius_options := []string{"0", "2", "4", "6", "8", "10", "12", "14", "16"}
radius_values := []f32{0, 2, 4, 6, 8, 10, 12, 14, 16}
radius_dropdown := ui.Dropdown {
	selected = 3,
}

configured_radius :: proc() -> f32 {
	i := radius_dropdown.selected
	if i < 0 || i >= len(radius_values) {return ui.DEFAULT_CORNER_RADIUS}
	return radius_values[i]
}

draw_setup :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "CORNER RADIUS", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.dropdown(c, 50, {WIDGET_X, 266, INPUT_W, CONTROL_H}, radius_options, &radius_dropdown)
	ui.label(
		c,
		WIDGET_X,
		346,
		fmt.tprintf("Applied to every widget. Current: %.0f px.", configured_radius()),
		17,
	)
	ui.label(
		c,
		WIDGET_X,
		376,
		"Switch views to see the change on buttons, inputs, dropdowns and the rest.",
		17,
	)
}
