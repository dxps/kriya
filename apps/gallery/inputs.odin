package main
import ui "kriya:ui"

name_input: ui.Text_Input
password_input: ui.Text_Input
inputs_read_only: bool

init_input_examples :: proc() {
	ui.set_text(&name_input, "Ada Lovelace")
	ui.set_text(&password_input, "analytical-engine")
}

// Two field groups (caption + input) share the setup.odin spacing idiom:
// caption slot = font height, skip 8 to the field, skip 31/36 between
// groups and before the help line. Container y=242 places the first
// caption baseline on the original 250.
draw_inputs :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 242, INPUT_W, 300}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "STANDARD", 11, color = ui.DEFAULT_PALETTE.text_muted)
	ui.skip(&s, 8)
	ui.input(c, 20, ui.next(&s, field_h()), "Enter a name", &name_input, read_only = inputs_read_only)
	ui.skip(&s, 31)

	ui.label_in(c, ui.next(&s, 11), "PASSWORD", 11, color = ui.DEFAULT_PALETTE.text_muted)
	ui.skip(&s, 8)
	ui.input(
		c,
		21,
		ui.next(&s, field_h()),
		"Enter a password",
		&password_input,
		password = true,
		read_only = inputs_read_only,
	)
	ui.skip(&s, 36)

	ui.label_in(c, ui.next(&s, 17), "Click the eye to reveal or hide the password.", 17)
	ui.skip(&s, 32)

	r := ui.next(&s, 18)
	ui.toggle(c, 22, r.x, r.y, "Read-only", &inputs_read_only)
}
