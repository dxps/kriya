package main
import "core:fmt"
import ui "kriya:ui"

button_count: int

draw_buttons :: proc(c: ^ui.Context) {
	if ui.button(c, 1, {WIDGET_X, 258, BUTTON_W, CONTROL_H}, "Click me") {button_count += 1}
	ui.button(c, 2, {WIDGET_X + BUTTON_W + 18, 258, BUTTON_W, CONTROL_H}, "Disabled", true)
	ui.label(c, WIDGET_X, 356, fmt.tprintf("Button pressed %d times", button_count), 24)
	ui.label(c, WIDGET_X, 400, "Hover, press and release to explore each state.", 17)
}
