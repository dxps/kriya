package main
import ui "kriya:ui"

// One bool per section, same shape as the modal view's outcome
// counters. Account starts open so the view lands with at least one
// body visible; the other two open on click.
account_open: bool = true
general_open: bool
billing_open: bool

ACCORDION_H :: f32(40)

// Three stacked accordions separated by 1 px dividers. The col walks
// the y-axis itself, so an open section's body just adds more rows
// between its header and the next divider; a closed one skips
// straight to the divider.
draw_accordions :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 258, INPUT_W + 80, 420}, gap = 0)

	draw_section(c, &s, 1101, "Account", &account_open, []string{"Email · ana@example.ro", "Password · ********", "Two-factor · Enabled"})
	ui.divider(c, ui.next(&s, 1))
	draw_section(c, &s, 1102, "General", &general_open, []string{"Language · Română", "Timezone · Europe/Bucharest"})
	ui.divider(c, ui.next(&s, 1))
	draw_section(c, &s, 1103, "Billing", &billing_open, []string{"Plan · Pro", "Next invoice · 2026-12-01"})
}

// Draws one section: header row, and if open, an indented body of
// muted body-size labels. Body items sit 32 px in from the left
// edge so they line up under the accordion's title text (which
// starts at the same inset past the triangle).
draw_section :: proc(c: ^ui.Context, s: ^ui.Stack, id: u64, title: string, open: ^bool, items: []string) {
	ui.accordion(c, id, ui.next(s, ACCORDION_H), title, open)
	if open^ {
		body := ui.type_scale(c).body
		ui.skip(s, 4)
		for text in items {
			slot := ui.next(s, body + 10)
			ui.label_in(
				c,
				ui.Rect{slot.x + 32, slot.y, max(0, slot.w - 32), slot.h},
				text,
				body,
				color = ui.palette(c).text_muted,
			)
		}
		ui.skip(s, 10)
	}
}
