package main
import ui "kriya:ui"

name_input: ui.Text_Input
password_input: ui.Text_Input
inputs_read_only: bool

init_input_examples :: proc() {
	ui.set_text(&name_input, "Ada Lovelace")
	ui.set_text(&password_input, "analytical-engine")
}

// Two field groups (caption + input) share the setup.odin spacing idiom
// via field_group; the per-group trailing skip (31 / 36) stays here so
// each group can tune its own pre-footer spacing.
draw_inputs :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 242, INPUT_W, 300}, gap = 0)

	ui.input(c, 20, field_group(c, &s, "STANDARD"), "Enter a name", &name_input, read_only = inputs_read_only)
	ui.skip(&s, 31)

	ui.input(
		c,
		21,
		field_group(c, &s, "PASSWORD"),
		"Enter a password",
		&password_input,
		password = true,
		read_only = inputs_read_only,
	)
	ui.skip(&s, 36)

	ui.label_in(c, ui.next(&s, 17), "Click the eye to reveal or hide the password.", 17)
	ui.skip(&s, 32)

	ui.toggle(c, 22, ui.next(&s, 18), "Read-only", &inputs_read_only)
}
