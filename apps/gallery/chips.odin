package main
import ui "kriya:ui"

chip_labels := [?]string{"Design", "Research", "Marketing", "Engineering", "Ops", "Sales"}
chip_visible := [len(chip_labels)]bool{true, true, true, true, true, true}

// A row of filter-token chips. Clicking × on one hides it (chip
// returns true, we flip its visibility bit). A compact Reset button
// below restores them all so the view can be re-played without a page
// reload — the row is persistent state kept in module-level slots the
// same way modal keeps its outcome counters.
draw_chips :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W + 60, 220}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "FILTERS", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)

	// Per-chip widths vary with their label, so drive ui.row's cursor
	// with chip_size the same way the badges view drives badge_size.
	row := ui.row(ui.next(&s, 24), gap = 8)
	for text, i in chip_labels {
		if !chip_visible[i] {continue}
		w, h := ui.chip_size(c, text)
		if ui.chip(c, u64(900 + i), ui.next(&row, w, h), text) {
			chip_visible[i] = false
		}
	}
	ui.skip(&s, 24)

	reset_slot := ui.next(&s, CONTROL_H)
	if ui.button(c, 910, {reset_slot.x, reset_slot.y, 120, reset_slot.h}, "Reset") {
		for _, i in chip_visible {chip_visible[i] = true}
	}
}
