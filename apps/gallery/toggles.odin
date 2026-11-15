package main
import ui "kriya:ui"

wifi_enabled := true
airplane_mode := false
toggles_read_only: bool

draw_toggles :: proc(c: ^ui.Context) {
	ui.toggle(c, 7, WIDGET_X, 270, "Wi-Fi", &wifi_enabled, read_only = toggles_read_only)
	ui.toggle(c, 8, WIDGET_X, 310, "Airplane mode", &airplane_mode, read_only = toggles_read_only)
	ui.label(c, WIDGET_X, 410, "A pill-shaped on/off switch. Click track or label to flip.", 17)
	ui.toggle(c, 9, WIDGET_X, 446, "Read-only", &toggles_read_only)
}
