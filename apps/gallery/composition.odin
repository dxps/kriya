package main
import "core:fmt"
import ui "kriya:ui"

publish_preview := true
save_count: int

draw_composition :: proc(c: ^ui.Context) {
	ui.label(c, 302, 274, "Project settings", 28)
	ui.checkbox(c, 5, 302, 310, "Publish preview", &publish_preview)
	if ui.button(c, 6, {302, 378, 162, 46}, "Save settings") {save_count += 1}
	ui.label(c, 302, 474, fmt.tprintf("Saved %d times", save_count), 17)
}
