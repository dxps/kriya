package ui

// Small pill-shaped status label — "new", "beta", "3 unread", a role tag
// next to a name. Purely informational: it takes no id and reads no
// input, so a caller never worries about focus or hit-testing around it.
//
// Always fully rounded regardless of the configured corner radius, the
// same way toggle's track stays a fixed pill — the capsule shape is part
// of what reads as a badge rather than a button.
//
// emphasis switches between the two looks shared with the rest of the
// library (button, segmented and toggle all draw this same subtle/primary
// pair) rather than introducing a separate status-color palette: subtle
// is a surface-raised fill behind a 1px border, emphasis is a solid
// primary fill with text_on_primary text.
badge :: proc(c: ^Context, r: Rect, text: string, emphasis := false) {
	corner_radius := r.h / 2
	if emphasis {
		box(c, r, palette(c).primary, corner_radius)
		label_in(c, r, text, 13, .Center, .Center, color = palette(c).text_on_primary)
		return
	}
	box(c, r, palette(c).border, corner_radius)
	inner := Rect{r.x + 1, r.y + 1, max(0, r.w - 2), max(0, r.h - 2)}
	box(c, inner, palette(c).surface_raised, max(0, corner_radius - 1))
	label_in(c, r, text, 13, .Center, .Center, color = palette(c).text_muted)
}

BADGE_PAD_X :: f32(10)

// badge_size measures the pill a given label needs: text width plus
// horizontal padding, at a caller-chosen height (22 matches a compact tag
// sitting inline with 17pt body text). Callers build the Rect the same
// way modal sizes its action buttons — measure, then hand the rect to
// the widget.
badge_size :: proc(c: ^Context, text: string, height: f32 = 22) -> (w, h: f32) {
	assert(c.measure_text != nil, "badge_size requires a text measurement callback")
	return c.measure_text(text, 13) + 2 * BADGE_PAD_X, height
}
