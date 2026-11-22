package ui

// Rounded surface panel — the box you drop stat tiles, forms, or
// any grouped content into. Draws a 1 px bordered rectangle in the
// surface_raised token, same recipe as input / dropdown / badge
// (subtle), and returns the inset rect the caller writes content
// into. 'pad' controls how far that inner rect is set in from the
// outer edge on every side, defaulting to CARD_PAD (20 px) — big
// enough to let a heading and a short body breathe without
// crowding the border.
//
// Purely visual: no id, no hit test, no focus. A clickable card
// wraps something like button(c, id, r, "") over the same rect
// and still draws its content inside the returned inset — a card
// is a box, not a behaviour.
card :: proc(c: ^Context, r: Rect, pad: f32 = CARD_PAD, radius: Maybe(f32) = nil) -> Rect {
	corner_radius := resolve_corner_radius(c, radius)
	pal := palette(c)

	box(c, r, pal.border, corner_radius)
	inner := Rect{r.x + 1, r.y + 1, max(0, r.w - 2), max(0, r.h - 2)}
	box(c, inner, pal.surface_raised, max(0, corner_radius - 1))

	p := max(0, pad)
	return Rect{r.x + p, r.y + p, max(0, r.w - 2 * p), max(0, r.h - 2 * p)}
}

CARD_PAD :: f32(20)
