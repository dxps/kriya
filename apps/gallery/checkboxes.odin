package main
import ui "kriya:ui"

notifications_enabled := true
dark_appearance := true

draw_checkboxes :: proc(c: ^ui.Context) {
	ui.checkbox(c, 3, WIDGET_X, 270, "Enable notifications", &notifications_enabled)
	ui.checkbox(c, 4, WIDGET_X, 326, "Use dark appearance", &dark_appearance)
	ui.label(c, WIDGET_X, 410, "Each checkbox owns an independent value.", 17)
}
