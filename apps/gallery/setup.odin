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

// Live theme setting applied globally via ui.set_theme. Defaults to Dark
// so the gallery starts out looking the same as before.
theme_options := []string{"Dark", "Light"}
theme_dropdown := ui.Dropdown {
	selected = 0,
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

configured_theme :: proc() -> ^ui.Theme {
	if theme_dropdown.selected == 1 {return &ui.LIGHT_THEME}
	return &ui.DARK_THEME
}

// Container y=242 lifts the first label's baseline (size-11 Start = y + 8.25)
// onto the original 250. field_group emits the caption + 8 px skip and
// hands back the field_h() slot; the trailing skip stays per-group.
draw_setup :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 242, INPUT_W, 300}, gap = 0)

	ui.dropdown(c, 50, field_group(c, &s, "CORNER RADIUS"), radius_options, &radius_dropdown)
	ui.skip(&s, 32)

	ui.dropdown(c, 51, field_group(c, &s, "PADDING"), padding_options, &padding_dropdown)
	ui.skip(&s, 32)

	ui.dropdown(c, 52, field_group(c, &s, "THEME"), theme_options, &theme_dropdown)
	ui.skip(&s, 32)

	ui.label_in(
		c,
		ui.next(&s, 17),
		fmt.tprintf(
			"Applied globally. Radius: %.0f px. Padding: %.0f px.",
			configured_radius(),
			configured_padding(),
		),
		17,
	)
	ui.skip(&s, 13)
	ui.label_in(
		c,
		ui.next(&s, 17),
		"Padding insets text in inputs, dropdowns and textareas. Switch views to see it.",
		17,
	)
}
