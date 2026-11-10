package main
import "core:fmt"
import ui "kriya:ui"

button_count: int

draw_buttons :: proc(c: ^ui.Context) {
	if ui.button(c, 1, {302, 258, 162, 46}, "Click me") {button_count += 1}
	ui.button(c, 2, {482, 258, 162, 46}, "Disabled", true)
	ui.label(c, 302, 356, fmt.tprintf("Button pressed %d times", button_count), 24)
	ui.label(c, 302, 400, "Hover, press and release to explore each state.", 17)
}
