package main
import ui "kriya:ui"

name_input: ui.Text_Input
password_input: ui.Text_Input

init_input_examples :: proc() {
	ui.set_text(&name_input, "Ada Lovelace")
	ui.set_text(&password_input, "analytical-engine")
}

draw_inputs :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "STANDARD", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.input(c, 20, {WIDGET_X, 266, INPUT_W, CONTROL_H}, "Enter a name", &name_input)
	ui.label(c, WIDGET_X, 346, "PASSWORD", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.input(c, 21, {WIDGET_X, 362, INPUT_W, CONTROL_H}, "Enter a password", &password_input, true)
	ui.label(c, WIDGET_X, 452, "Click the eye to reveal or hide the password.", 17)
}
