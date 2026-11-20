package main
import ui "kriya:ui"

wifi_enabled := true
airplane_mode := false
toggles_read_only: bool

// Same shape as checkboxes.odin — two controls, paragraph, read-only
// toggle — but with tighter spacing between the two switches (22 px gap
// vs 38 px in checkboxes) and a correspondingly wider pre-paragraph gap.
// Container y=270 preserves the original first-toggle top.
draw_toggles :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W, 220}, gap = 0)

	r := ui.next(&s, 18)
	ui.toggle(c, 7, r.x, r.y, "Wi-Fi", &wifi_enabled, read_only = toggles_read_only)
	ui.skip(&s, 22)

	r = ui.next(&s, 18)
	ui.toggle(c, 8, r.x, r.y, "Airplane mode", &airplane_mode, read_only = toggles_read_only)
	ui.skip(&s, 69)

	ui.label_in(c, ui.next(&s, 17), "A pill-shaped on/off switch. Click track or label to flip.", 17)
	ui.skip(&s, 32)

	r = ui.next(&s, 18)
	ui.toggle(c, 9, r.x, r.y, "Read-only", &toggles_read_only)
}
