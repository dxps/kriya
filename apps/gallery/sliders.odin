package main

import ui "kriya:ui"

volume_slider := ui.Slider {
	value = 35,
}
opacity_slider := ui.Slider {
	value = 0.6,
}
level_slider := ui.Slider {
	value = 7,
}

// Two horizontal sliders then a vertical slider with a help label on its
// right. The vertical row uses a nested ui.row whose gap (30) matches the
// original 80 px offset between slider left edge and label left edge
// (50 slider + 30 gap). The label sits 14 px below the row top for the
// original visual balance — that's a nudge too small to be a slot.
draw_sliders :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 242, INPUT_W, 500}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "VOLUME", 11, color = ui.DEFAULT_PALETTE.text_muted)
	ui.skip(&s, 8)
	ui.slider(
		c,
		40,
		ui.next(&s, CONTROL_H),
		&volume_slider,
		min_val = 0,
		max_val = 100,
		step = 1,
	)
	ui.skip(&s, 31)

	ui.label_in(c, ui.next(&s, 11), "OPACITY", 11, color = ui.DEFAULT_PALETTE.text_muted)
	ui.skip(&s, 8)
	ui.slider(
		c,
		41,
		ui.next(&s, CONTROL_H),
		&opacity_slider,
		min_val = 0,
		max_val = 1,
		step = 0.05,
		precision = 2,
	)
	ui.skip(&s, 41)

	ui.label_in(c, ui.next(&s, 11), "LEVEL", 11, color = ui.DEFAULT_PALETTE.text_muted)
	ui.skip(&s, 8)

	row := ui.row(ui.next(&s, 220), gap = 30)
	ui.slider(
		c,
		42,
		ui.next(&row, 50),
		&level_slider,
		min_val = 0,
		max_val = 10,
		step = 1,
		orientation = .Vertical,
	)
	help := ui.next(&row, ui.remaining(row))
	ui.label_in(
		c,
		{help.x, help.y + 14, help.w, 17},
		"Drag the thumb or click anywhere on the track.",
		17,
		v = .Start,
	)
}
