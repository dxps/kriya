package main
import ui "kriya:ui"

// Three stat tiles in a row and a content card below them, like a
// miniature dashboard. Each card is just ui.card; the content it
// holds — caption, number, delta line, heading, body — is drawn
// into the inset rect ui.card returns.
draw_cards :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 258, INPUT_W + 80, 440}, gap = 0)

	// Row of three stat tiles. ui.row carves the horizontal slot
	// into equal thirds with a gap between them; each tile fills
	// its slot and ui.card insets padding from there.
	tiles := ui.row(ui.next(&s, 110), gap = 14)
	stat_tile(c, ui.next(&tiles, 142), "ACTIVE USERS", "1,284", "+12% this week")
	stat_tile(c, ui.next(&tiles, 142), "REVENUE", "$48,320", "+8% vs last month")
	stat_tile(c, ui.next(&tiles, 142), "CHURN", "0.9%", "-0.2 pt")
	ui.skip(&s, 20)

	// Content card: a heading + wrapped paragraph. label_wrap takes
	// the inner rect directly and breaks on word boundaries up to
	// the available height.
	outer := ui.next(&s, 180)
	inner := ui.card(c, outer)
	pal := ui.palette(c)
	ui.label_in(c, ui.Rect{inner.x, inner.y, inner.w, 24}, "What this is", 18, color = pal.text)
	body_rect := ui.Rect{inner.x, inner.y + 32, inner.w, inner.h - 32}
	ui.label_wrap(
		c,
		body_rect,
		"A card is the smallest visual container: a bordered rounded surface with an inset content rect. ui.card returns that rect, so the caller composes whatever heading, body, chart or form fits inside without the widget prescribing layout.",
		16,
		pal.text_muted,
	)
}

// One stat tile. Caption row (11 pt muted), big value (28 pt), delta
// line (13 pt subtle) stacked with fixed gaps so a row of them
// aligns naturally.
stat_tile :: proc(c: ^ui.Context, r: ui.Rect, caption, value, delta: string) {
	inner := ui.card(c, r, pad = 16)
	pal := ui.palette(c)
	ui.label_in(c, ui.Rect{inner.x, inner.y, inner.w, 11}, caption, 11, color = pal.text_muted)
	ui.label_in(c, ui.Rect{inner.x, inner.y + 22, inner.w, 32}, value, 28, color = pal.text)
	ui.label_in(c, ui.Rect{inner.x, inner.y + 62, inner.w, 13}, delta, 13, color = pal.text_subtle)
}
