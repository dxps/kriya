package main
import "core:fmt"
import ui "kriya:ui"

toast_stack: ui.Toast_Stack
toast_counter: int
toast_corner_idx: int // 0 = TR (default), 1 = TL, 2 = BR, 3 = BL
toast_duration_slider: ui.Slider = {value = 3.0}

// The segmented control's labels line up with the Toast_Corner
// enum's variants, so a selection is just a ui.Toast_Corner cast.
toast_corner_labels := [?]string{"Top-right", "Top-left", "Bottom-right", "Bottom-left"}

// Three buttons that queue three different-kind toasts and a
// segmented control that re-anchors the stack. toasts() sits at
// the end of this view: it decrements each toast's remaining time,
// removes expired ones, and paints the survivors on the overlay
// layer at the corner the user picked.
draw_toasts :: proc(c: ^ui.Context) {
	// Re-apply the corner and duration each frame — both are
	// context defaults, so changing them affects every toasts()
	// call and every toast_push for the rest of the frame.
	ui.set_toast_corner(c, ui.Toast_Corner(toast_corner_idx))
	ui.set_toast_duration(c, toast_duration_slider.value)

	s := ui.col({WIDGET_X, 240, INPUT_W + 60, 420}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "CORNER", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)
	ui.segmented(c, 1320, ui.next(&s, 36), toast_corner_labels[:], &toast_corner_idx)
	ui.skip(&s, 24)

	ui.label_in(c, ui.next(&s, 11), "DURATION (SECONDS)", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)
	ui.slider(
		c,
		1321,
		ui.next(&s, 36),
		&toast_duration_slider,
		min_val = 3,
		max_val = 8,
		step = 0.5,
		precision = 1,
	)
	ui.skip(&s, 24)

	ui.label_in(c, ui.next(&s, 11), "KIND", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)
	row := ui.row(ui.next(&s, CONTROL_H), gap = 12)
	if ui.button(c, 1300, ui.next(&row, 120), "Info") {
		toast_counter += 1
		ui.toast_push(c, &toast_stack, fmt.tprintf("Saved · %d item(s)", toast_counter), kind = .Info)
	}
	if ui.button(c, 1301, ui.next(&row, 120), "Warn") {
		ui.toast_push(c, &toast_stack, "Rate limit approaching", kind = .Warn)
	}
	if ui.button(c, 1302, ui.next(&row, 120), "Error") {
		ui.toast_push(c, &toast_stack, "Could not connect to server", kind = .Error)
	}

	ui.skip(&s, 24)
	body := ui.type_scale(c).body
	ui.label_in(
		c,
		ui.next(&s, body),
		fmt.tprintf(
			"In flight: %d · each auto-dismisses after %.1f s",
			toast_stack.count,
			toast_duration_slider.value,
		),
		body,
		color = ui.palette(c).text_muted,
	)

	// Scope the toast viewport to the right pane only so left-
	// anchored corners don't disappear behind the sidebar. In a
	// real app, c.viewport usually already excludes persistent
	// chrome; here it's the full window so we trim it ourselves.
	saved_vp := c.viewport
	c.viewport = ui.Rect{SIDEBAR_W, 0, max(0, c.viewport.w - SIDEBAR_W), c.viewport.h}
	ui.toasts(c, 1310, &toast_stack)
	c.viewport = saved_vp
}
