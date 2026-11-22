package ui

// Dismissible pill tag — a filter token, a selected recipient, an item
// in a token-input. Reads as a subtle badge with a × on its right end;
// the pill paints the same way badge(subtle) does, so a row that mixes
// chips and badges stays visually one family.
//
// Only the × is hit-active: clicking the label area does nothing. A
// caller wanting the whole chip clickable (navigation, filter toggle)
// wraps a button around it instead — this widget is specifically "tag
// the user can remove".
//
// Returns true on the frame the × was released over its own hit rect.
chip :: proc(c: ^Context, id: u64, r: Rect, text: string) -> (dismissed: bool) {
	corner_radius := r.h / 2
	pal := palette(c)

	// Pill: 1px border + inner surface_raised fill, same recipe as
	// badge(subtle). The × hit area is layered on top.
	box(c, r, pal.border, corner_radius)
	inner := Rect{r.x + 1, r.y + 1, max(0, r.w - 2), max(0, r.h - 2)}
	box(c, inner, pal.surface_raised, max(0, corner_radius - 1))

	// × hit rect: a square the pill's height, anchored at the right
	// end. Overlaps the rounded cap, which is fine — the cap is
	// visually part of what a user clicks to dismiss.
	hit := Rect{r.x + r.w - r.h, r.y, r.h, r.h}
	hover, clicked := pressable(c, id, hit)

	// Label on the left of the ×, inset by CHIP_PAD_X. No truncation
	// here — chip_size already reserves the measured text width plus
	// CHIP_LABEL_GAP of visible breathing room before the × area, so
	// a correctly-sized chip never overflows. A caller passing a
	// too-narrow rect is on their own, same contract as badge.
	label_in(
		c,
		Rect{r.x + CHIP_PAD_X, r.y, hit.x - r.x - CHIP_PAD_X - CHIP_LABEL_GAP, r.h},
		text,
		13,
		.Start,
		.Center,
		color = pal.text_muted,
	)

	// × glyph — two 45° strokes through the centre of the hit area.
	// Hover brightens from text_muted to text so the dismiss affordance
	// matches the pointer cursor pressable() just claimed.
	cx := hit.x + hit.w / 2
	cy := hit.y + hit.h / 2
	arm := f32(3.5)
	x_color := hover ? pal.text : pal.text_muted
	line(c, cx - arm, cy - arm, cx + arm, cy + arm, 1.5, x_color)
	line(c, cx - arm, cy + arm, cx + arm, cy - arm, 1.5, x_color)

	return clicked
}

CHIP_PAD_X :: f32(12)
CHIP_LABEL_GAP :: f32(4) // visible gap between label end and × area

// chip_size measures the pill a given label needs: left pad + text
// width + the label/× gap + a square × area the pill's height, at a
// caller-chosen height (24 matches a compact chip sitting inline
// with 17pt body text; bigger chips scale the × with the rest).
chip_size :: proc(c: ^Context, text: string, height: f32 = 24) -> (w, h: f32) {
	assert(c.measure_text != nil, "chip_size requires a text measurement callback")
	return c.measure_text(text, 13) + CHIP_PAD_X + CHIP_LABEL_GAP + height, height
}
