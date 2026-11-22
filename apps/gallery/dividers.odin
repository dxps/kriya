package main
import ui "kriya:ui"

// Two shapes of the same primitive: a horizontal rule splitting stacked
// blocks, and a thin vertical rule between inline items. Both come from
// the single rect-taking ui.divider — the rect's aspect picks the
// orientation.
draw_dividers :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W, 260}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "HORIZONTAL", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)

	body := ui.type_scale(c).body
	ui.label_in(c, ui.next(&s, body), "General", body)
	ui.skip(&s, 12)
	ui.divider(c, ui.next(&s, 1))
	ui.skip(&s, 12)
	ui.label_in(c, ui.next(&s, body), "Account", body)
	ui.skip(&s, 12)
	ui.divider(c, ui.next(&s, 1))
	ui.skip(&s, 12)
	ui.label_in(c, ui.next(&s, body), "Billing", body)
	ui.skip(&s, 40)

	ui.label_in(c, ui.next(&s, 11), "VERTICAL", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)

	// A fixed-height row with inline items split by 1 px vertical rules.
	// Each label sizes itself from the measured text so the rules sit
	// snug against each item instead of floating in empty slots.
	inline_row := ui.row(ui.next(&s, 20), gap = 12)
	items := []string{"Edit", "Duplicate", "Share", "Delete"}
	for text, i in items {
		if i > 0 {ui.divider(c, ui.next(&inline_row, 1, 14))}
		w := c.measure_text(text, body)
		ui.label_in(c, ui.next(&inline_row, w), text, body, color = ui.palette(c).text_muted)
	}
}
