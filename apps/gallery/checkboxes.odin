package main
import ui "kriya:ui"

notifications_enabled := true
dark_appearance := true
checkboxes_read_only: bool

draw_checkboxes :: proc(c: ^ui.Context) {
	ui.checkbox(
		c,
		3,
		WIDGET_X,
		270,
		"Enable notifications",
		&notifications_enabled,
		read_only = checkboxes_read_only,
	)
	ui.checkbox(
		c,
		4,
		WIDGET_X,
		326,
		"Use dark appearance",
		&dark_appearance,
		read_only = checkboxes_read_only,
	)
	ui.label(c, WIDGET_X, 410, "Each checkbox owns an independent value.", 17)
	ui.toggle(c, 5, WIDGET_X, 446, "Read-only", &checkboxes_read_only)
}
