package ui

// Floating popup menu — the right-click drawer of items a caller
// drops at a chosen point. Rendered on the overlay layer so it
// sits above whatever base widget the cursor landed on.
//
// State is a small struct the caller owns: open flag plus the
// point to anchor at. open_context_menu sets both. Typical trigger:
//
//     if c.right_pressed && contains(c, zone) {
//         open_context_menu(&menu, c.mx, c.my)
//     }
//     switch ui.context_menu(c, 42, ITEMS, &menu) { ... }
//
// A left press anywhere outside the popup, or Escape, closes it.
// An empty string inside 'items' renders a divider instead of a
// clickable row — one list carries both kinds of entry.

Context_Menu :: struct {
	open: bool,
	x, y: f32,
}

CONTEXT_MENU_PAD_X :: f32(10)
CONTEXT_MENU_PAD_Y :: f32(6)
CONTEXT_MENU_ITEM_H :: f32(32)
CONTEXT_MENU_DIV_H :: f32(9) // 1 px line centred in 9 px of slack
CONTEXT_MENU_SIZE :: f32(15)
CONTEXT_MENU_MIN_W :: f32(160)

// Positions the popup at (x, y) and opens it. Re-calling while
// open just moves it — a right-click somewhere else tracks the
// cursor instead of orphaning the previous menu.
open_context_menu :: proc(state: ^Context_Menu, x, y: f32) {
	state.open = true
	state.x = x
	state.y = y
}

// Draws the popup when state.open is true. Returns the index of
// the item clicked this frame, or -1 when none was. An item whose
// string is "" renders as a divider line so the caller composes a
// grouped menu with one flat []string instead of a tagged union.
context_menu :: proc(c: ^Context, id: u64, items: []string, state: ^Context_Menu) -> int {
	if !state.open {return -1}
	assert(c.measure_text != nil, "context_menu requires a text measurement callback")

	pal := palette(c)

	// Size pass: widest text gives the popup's inner width, every
	// item adds its height (dividers short, labels tall).
	max_text_w: f32
	total_h: f32 = 2 * CONTEXT_MENU_PAD_Y
	for text in items {
		if text == "" {
			total_h += CONTEXT_MENU_DIV_H
			continue
		}
		w := c.measure_text(text, CONTEXT_MENU_SIZE)
		if w > max_text_w {max_text_w = w}
		total_h += CONTEXT_MENU_ITEM_H
	}
	popup_w := max(CONTEXT_MENU_MIN_W, max_text_w + 2 * CONTEXT_MENU_PAD_X)

	// Clamp to viewport so a menu opened near the right / bottom
	// edge still shows in full. Modal's smoke-test fallback kicks
	// in for a nil viewport.
	vp := c.viewport
	if vp.w == 0 && vp.h == 0 {vp = Rect{0, 0, 1024, 720}}
	px := state.x
	py := state.y
	if px + popup_w > vp.x + vp.w {px = vp.x + vp.w - popup_w}
	if py + total_h > vp.y + vp.h {py = vp.y + vp.h - total_h}
	if px < vp.x {px = vp.x}
	if py < vp.y {py = vp.y}
	popup_rect := Rect{px, py, popup_w, total_h}

	// Close conditions evaluated BEFORE drawing so the dismissing
	// frame doesn't flash the menu one last time. c.pressed covers
	// the usual left-click-away; c.right_pressed covers "right-
	// click moved elsewhere", so the caller's own open-on-right-
	// click handler re-opens at the new cursor on the next frame
	// (two frames after the original open is fine — no drift).
	outside_press :=
		(c.pressed || c.right_pressed) && !point_in_rect(c.mx, c.my, popup_rect)
	if c.cancel || outside_press {
		state.open = false
		return -1
	}

	prev_layer := c.layer
	c.layer = .Overlay

	// Border + fill, same recipe as tooltip and dropdown popup.
	box(
		c,
		{popup_rect.x - 1, popup_rect.y - 1, popup_rect.w + 2, popup_rect.h + 2},
		pal.overlay_border,
		7,
	)
	box(c, popup_rect, pal.overlay, 6)

	clicked := -1
	y := popup_rect.y + CONTEXT_MENU_PAD_Y
	for text, i in items {
		if text == "" {
			box(
				c,
				{
					popup_rect.x + CONTEXT_MENU_PAD_X,
					y + CONTEXT_MENU_DIV_H / 2,
					max(0, popup_rect.w - 2 * CONTEXT_MENU_PAD_X),
					1,
				},
				pal.divider,
			)
			y += CONTEXT_MENU_DIV_H
			continue
		}
		item_rect := Rect{popup_rect.x, y, popup_rect.w, CONTEXT_MENU_ITEM_H}
		hover, hit := pressable(c, sub_id(id, u64(i + 1)), item_rect)
		if hover {
			box(
				c,
				{item_rect.x + 2, item_rect.y, max(0, item_rect.w - 4), item_rect.h},
				pal.item_hover,
				4,
			)
		}
		label_in(
			c,
			Rect{
				item_rect.x + CONTEXT_MENU_PAD_X,
				item_rect.y,
				max(0, item_rect.w - 2 * CONTEXT_MENU_PAD_X),
				item_rect.h,
			},
			text,
			CONTEXT_MENU_SIZE,
			.Start,
			.Center,
		)
		if hit {
			clicked = i
			state.open = false
		}
		y += CONTEXT_MENU_ITEM_H
	}

	c.layer = prev_layer
	return clicked
}
