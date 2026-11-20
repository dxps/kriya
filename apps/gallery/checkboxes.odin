package main
import ui "kriya:ui"

notifications_enabled := true
dark_appearance := true
checkboxes_read_only: bool

// Container y=270 preserves the original first-checkbox top. Each control
// slot is the 18 px glyph box the widget draws into; skips carry the
// visual spacing between controls and the status / read-only block.
// checkbox / toggle still take (x, y), so each slot gets a named 'r' —
// a rect-taking variant of these widgets would tighten this further.
draw_checkboxes :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W, 220}, gap = 0)

	r := ui.next(&s, 18)
	ui.checkbox(c, 3, r.x, r.y, "Enable notifications", &notifications_enabled, read_only = checkboxes_read_only)
	ui.skip(&s, 38)

	r = ui.next(&s, 18)
	ui.checkbox(c, 4, r.x, r.y, "Use dark appearance", &dark_appearance, read_only = checkboxes_read_only)
	ui.skip(&s, 53)

	ui.label_in(c, ui.next(&s, 17), "Each checkbox owns an independent value.", 17)
	ui.skip(&s, 32)

	r = ui.next(&s, 18)
	ui.toggle(c, 5, r.x, r.y, "Read-only", &checkboxes_read_only)
}
