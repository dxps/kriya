package main
import ui "kriya:ui"

notifications_enabled := true
dark_appearance := true

draw_checkboxes :: proc(c: ^ui.Context) {
	ui.checkbox(c, 3, 302, 270, "Enable notifications", &notifications_enabled)
	ui.checkbox(c, 4, 302, 326, "Use dark appearance", &dark_appearance)
	ui.label(c, 302, 410, "Each checkbox owns an independent value.", 17)
}
