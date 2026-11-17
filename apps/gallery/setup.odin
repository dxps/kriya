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

// Live padding setting applied globally via ui.set_padding. Default lands
// on "14", matching ui.DEFAULT_PADDING, so the gallery starts out spaced
// exactly as before. Affects inputs, dropdowns and textareas — the fields
// whose text sits inset from a framed edge — on both axes where both
// apply (textarea) and horizontally for the single-line widgets.
padding_options := []string{"6", "8", "10", "12", "14", "16", "20", "24"}
padding_values := []f32{6, 8, 10, 12, 14, 16, 20, 24}
padding_dropdown := ui.Dropdown {
	selected = 4,
}

configured_radius :: proc() -> f32 {
	i := radius_dropdown.selected
	if i < 0 || i >= len(radius_values) {return ui.DEFAULT_CORNER_RADIUS}
	return radius_values[i]
}

configured_padding :: proc() -> f32 {
	i := padding_dropdown.selected
	if i < 0 || i >= len(padding_values) {return ui.DEFAULT_PADDING}
	return padding_values[i]
}

draw_setup :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "CORNER RADIUS", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.dropdown(c, 50, {WIDGET_X, 266, INPUT_W, field_h()}, radius_options, &radius_dropdown)
	ui.label(c, WIDGET_X, 346, "PADDING", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.dropdown(c, 51, {WIDGET_X, 362, INPUT_W, field_h()}, padding_options, &padding_dropdown)
	ui.label(
		c,
		WIDGET_X,
		442,
		fmt.tprintf(
			"Applied globally. Radius: %.0f px. Padding: %.0f px.",
			configured_radius(),
			configured_padding(),
		),
		17,
	)
	ui.label(
		c,
		WIDGET_X,
		472,
		"Padding insets text in inputs, dropdowns and textareas. Switch views to see it.",
		17,
	)
}
