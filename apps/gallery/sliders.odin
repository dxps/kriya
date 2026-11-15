package main

import ui "kriya:ui"

volume_slider := ui.Slider {
	value = 35,
}
opacity_slider := ui.Slider {
	value = 0.6,
}

draw_sliders :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "VOLUME", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.slider(
		c,
		40,
		{WIDGET_X, 266, INPUT_W, CONTROL_H},
		&volume_slider,
		min_val = 0,
		max_val = 100,
		step = 1,
	)
	ui.label(c, WIDGET_X, 346, "OPACITY", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.slider(
		c,
		41,
		{WIDGET_X, 362, INPUT_W, CONTROL_H},
		&opacity_slider,
		min_val = 0,
		max_val = 1,
		step = 0.05,
		precision = 2,
	)
	ui.label(c, WIDGET_X, 452, "Drag the thumb or click anywhere on the track.", 17)
}
