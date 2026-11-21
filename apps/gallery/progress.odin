package main
import "core:fmt"
import ui "kriya:ui"

download_slider := ui.Slider{value = 65}

// Three modes together: a slider-driven determinate progress bar, an
// indeterminate progress bar, and a spinner next to a status label.
// Container y=254; slider drives the first bar, so the user can scrub
// through 0..100 and watch the fill move.
draw_progress :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 254, INPUT_W, 360}, gap = 0)

	ui.label_in(
		c,
		ui.next(&s, 11),
		fmt.tprintf("DOWNLOAD — %d%%", int(download_slider.value)),
		11,
		color = ui.palette(c).text_muted,
	)
	ui.skip(&s, 8)
	ui.slider(c, 60, ui.next(&s, CONTROL_H), &download_slider, min_val = 0, max_val = 100, step = 1)
	ui.skip(&s, 10)
	ui.progress_bar(c, ui.next(&s, 14), download_slider.value / 100)
	ui.skip(&s, 32)

	ui.label_in(c, ui.next(&s, 11), "SYNCING…", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 8)
	ui.progress_bar(c, ui.next(&s, 14))
	ui.skip(&s, 36)

	row := ui.row(ui.next(&s, 48), gap = 18)
	ui.spinner(c, ui.next(&row, 32))
	label_slot := ui.next(&row, ui.remaining(row))
	body := ui.type_scale(c).body
	ui.label_in(c, {label_slot.x, label_slot.y, label_slot.w, body}, "Preparing report", body)
}
