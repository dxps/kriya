package main
import "core:fmt"
import ui "kriya:ui"

stepper_qty: int = 1
stepper_zoom: int = 100
stepper_disabled_val: int = 7

// Three steppers side by side: a small-range quantity (0..9),
// a wider zoom range in 10 % steps (50..200), and a disabled one
// pinned at its initial value so the greyed-out look is visible
// without the user having to open DevTools to force state.
draw_steppers :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 258, INPUT_W + 60, 360}, gap = 0)

	draw_stepper_group(c, &s, 1400, "QUANTITY", &stepper_qty, 0, 9, 1, false)
	ui.skip(&s, 20)
	draw_stepper_group(c, &s, 1401, "ZOOM (%)", &stepper_zoom, 50, 200, 10, false)
	ui.skip(&s, 20)
	draw_stepper_group(c, &s, 1402, "DISABLED", &stepper_disabled_val, 0, 10, 1, true)

	ui.skip(&s, 32)
	body := ui.type_scale(c).body
	ui.label_in(
		c,
		ui.next(&s, body),
		fmt.tprintf(
			"State — quantity: %d · zoom: %d%% · disabled: %d",
			stepper_qty,
			stepper_zoom,
			stepper_disabled_val,
		),
		body,
		color = ui.palette(c).text_muted,
	)
}

// Caption + stepper + 12 px gap below, so every group lines up and
// the view keeps one stepper per row at a comfortable reading rhythm.
draw_stepper_group :: proc(
	c: ^ui.Context,
	s: ^ui.Stack,
	id: u64,
	caption: string,
	value: ^int,
	min_val, max_val, step: int,
	disabled: bool,
) {
	ui.label_in(c, ui.next(s, 11), caption, 11, color = ui.palette(c).text_muted)
	ui.skip(s, 8)
	slot := ui.next(s, CONTROL_H)
	ui.stepper(
		c,
		id,
		ui.Rect{slot.x, slot.y, 180, slot.h},
		value,
		min_val = min_val,
		max_val = max_val,
		step = step,
		disabled = disabled,
	)
}
