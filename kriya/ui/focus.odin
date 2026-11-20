package ui

// Focus traversal primitives. A widget that wants to be reachable by Tab
// or by click calls 'focusable(c, id, hit)' once per frame: the id joins
// a per-frame registry in draw order, a press inside the hit region
// moves focus to this id, and the proc returns true when this widget
// currently owns focus. begin / end rotate the registry so the next
// frame's Tab handling sees the full list before any widget draws —
// strictly immediate-mode, no second pass.
//
// 'focus_ring' draws a 2 px outline just outside r in the palette's
// focus_ring color. Widgets call it BEFORE their main box so the main
// box masks the ring's interior; what remains is a hairline border
// around the widget's outer edge.

MAX_FOCUSABLE :: 128

focusable :: proc(c: ^Context, id: u64, hit: Rect) -> bool {
	if c.focus_count < MAX_FOCUSABLE {
		c.focus_ids[c.focus_count] = id
		c.focus_count += 1
	}
	if c.pressed && contains(c, hit) {c.focused = id}
	return c.focused == id
}

focus_ring :: proc(c: ^Context, r: Rect, radius: f32 = 0) {
	pad :: f32(2)
	box(
		c,
		{r.x - pad, r.y - pad, r.w + 2 * pad, r.h + 2 * pad},
		DEFAULT_PALETTE.focus_ring,
		radius + pad,
	)
}
