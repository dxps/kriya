package main
import "core:fmt"
import ui "kriya:ui"

publish_preview := true
save_count: int

draw_composition :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 274, "Project settings", 28)
	ui.checkbox(c, 5, WIDGET_X, 310, "Publish preview", &publish_preview)
	if ui.button(c, 6, {WIDGET_X, 378, BUTTON_W, CONTROL_H}, "Save settings") {save_count += 1}
	ui.label(c, WIDGET_X, 474, fmt.tprintf("Saved %d times", save_count), 17)
}
