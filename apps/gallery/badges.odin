package main
import ui "kriya:ui"

// A row of subtle status tags followed by a row of emphasis ones — the
// two looks badge() chooses between. Widths vary per label, so each row
// drives ui.row's stateful cursor with a per-call size from
// ui.badge_size rather than a uniform slot width.
draw_badges :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W, 160}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "SUBTLE", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)
	subtle_row := ui.row(ui.next(&s, 22), gap = 10)
	subtle_labels := []string{"New", "Beta", "3 unread", "Draft"}
	for text in subtle_labels {
		w, h := ui.badge_size(c, text)
		ui.badge(c, ui.next(&subtle_row, w, h), text)
	}
	ui.skip(&s, 40)

	ui.label_in(c, ui.next(&s, 11), "EMPHASIS", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)
	emphasis_row := ui.row(ui.next(&s, 22), gap = 10)
	emphasis_labels := []string{"Active", "Verified", "Pro"}
	for text in emphasis_labels {
		w, h := ui.badge_size(c, text)
		ui.badge(c, ui.next(&emphasis_row, w, h), text, emphasis = true)
	}
}
