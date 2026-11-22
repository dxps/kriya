package main
import "core:fmt"
import ui "kriya:ui"

toast_stack: ui.Toast_Stack
toast_counter: int

// Three buttons that queue three different toasts. The toasts()
// draw call sits at the end of this view: it decrements each
// toast's remaining time, removes expired ones, and paints the
// survivors stacked at the bottom-right of the viewport on the
// overlay layer — so they float above the gallery's own chrome
// (sidebar, preview card, footer) regardless of where the mouse is.
draw_toasts :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W + 60, 220}, gap = 0)

	ui.label_in(
		c,
		ui.next(&s, 11),
		"QUEUE A TOAST — WATCH THE BOTTOM-RIGHT CORNER",
		11,
		color = ui.palette(c).text_muted,
	)
	ui.skip(&s, 12)

	row := ui.row(ui.next(&s, CONTROL_H), gap = 12)
	if ui.button(c, 1300, ui.next(&row, 120), "Save") {
		toast_counter += 1
		ui.toast_push(&toast_stack, fmt.tprintf("Saved · %d item(s)", toast_counter))
	}
	if ui.button(c, 1301, ui.next(&row, 120), "Delete") {
		ui.toast_push(&toast_stack, "Item removed")
	}
	if ui.button(c, 1302, ui.next(&row, 120), "Error") {
		ui.toast_push(&toast_stack, "Could not connect to server")
	}

	ui.skip(&s, 24)
	body := ui.type_scale(c).body
	ui.label_in(
		c,
		ui.next(&s, body),
		fmt.tprintf("In flight: %d · each auto-dismisses after 3 s", toast_stack.count),
		body,
		color = ui.palette(c).text_muted,
	)

	// Draw the stack last so it sits over the Edit hint and anything
	// else drawn after a view this frame.
	ui.toasts(c, 1310, &toast_stack)
}
