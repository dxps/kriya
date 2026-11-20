package main
import "core:fmt"
import ui "kriya:ui"

publish_preview := true
save_count: int

// Rect y=253 matches the previous hand-tuned top of the "Project settings"
// label (baseline 274 with size-28 ascender ≈ 253). Subsequent slots then
// drop the raw y arithmetic entirely; only the gap sizes carry over.
draw_composition :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 253, INPUT_W, 260}, gap = 29)

	ui.label_in(c, ui.next(&s, 28), "Project settings", 28, v = .Start)

	ui.checkbox(c, 5, ui.next(&s, 18), "Publish preview", &publish_preview)

	if ui.button(c, 6, ui.next(&s, CONTROL_H, BUTTON_W), "Save settings") {
		save_count += 1
	}

	// Extra breathing room between the button and the status text, so the
	// counter doesn't crowd the control row.
	ui.skip(&s, 8)
	ui.label_in(c, ui.next(&s, 17), fmt.tprintf("Saved %d times", save_count), 17, v = .Start)
}
