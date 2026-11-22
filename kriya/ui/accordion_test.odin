#+build !wasm32
package ui
import "core:testing"

@(test)
accordion_idle_draws_triangle_and_title_without_background :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// Place the header away from (0, 0) so the default cursor
	// position isn't mistakenly inside its hit rect — the hover
	// path has its own test below.
	c.mx = -100
	c.my = -100
	open := false
	returned := accordion(&c, 1, {100, 100, 300, 36}, "General", &open)
	// 1 triangle + 1 label = 2 commands when idle.
	testing.expect(t, len(c.commands) == 2)
	// Return value echoes the final state of 'expanded'.
	testing.expect(t, !returned)

	tri := c.commands[0].variant.(Triangle_Command)
	testing.expect(t, tri.color == DARK_PALETTE.text_muted)

	text := c.commands[1].variant.(Text_Command)
	testing.expect(t, text.text == "General")
	testing.expect(t, text.color == DARK_PALETTE.text_muted)
}

@(test)
accordion_hover_adds_background_and_brightens_text :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	r := Rect{0, 0, 300, 36}
	c.mx = r.x + r.w / 2
	c.my = r.y + r.h / 2
	open := false
	_ = accordion(&c, 1, r, "General", &open)
	// bg box + triangle + label = 3 commands when hovering.
	testing.expect(t, len(c.commands) == 3)

	bg := c.commands[0].variant.(Box_Command)
	testing.expect(t, bg.color == DARK_PALETTE.item_hover)

	text := c.commands[2].variant.(Text_Command)
	testing.expect(t, text.color == DARK_PALETTE.text)
	testing.expect(t, c.pointer_cursor)
}

@(test)
accordion_press_then_release_flips_expanded :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	r := Rect{0, 0, 300, 36}
	c.mx = r.x + r.w / 2
	c.my = r.y + r.h / 2
	open := false
	c.pressed = true; c.down = true
	_ = accordion(&c, 1, r, "General", &open)
	end(&c); begin(&c)
	c.mx = r.x + r.w / 2
	c.my = r.y + r.h / 2
	c.down = false; c.released = true
	returned := accordion(&c, 1, r, "General", &open)
	// A full press+release over the header opens the section, and
	// returned mirrors the new state so the caller can gate its body
	// on the same bool.
	testing.expect(t, open)
	testing.expect(t, returned)
}

@(test)
accordion_open_triangle_points_down_closed_points_right :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	c.mx = -100; c.my = -100 // keep hover off so commands[0] is the triangle

	// Closed: triangle apex to the right. The two left points share
	// an x, so the apex x is strictly greater than both base xs.
	closed := false
	accordion(&c, 1, {100, 100, 300, 36}, "General", &closed)
	tri_closed := c.commands[0].variant.(Triangle_Command)
	testing.expect(t, tri_closed.x1 == tri_closed.x2)
	testing.expect(t, tri_closed.x3 > tri_closed.x1)

	clear(&c.commands)

	// Open: triangle apex down. The two upper points share a y, and
	// the apex y is strictly greater than both of them.
	open := true
	accordion(&c, 1, {100, 100, 300, 36}, "General", &open)
	tri_open := c.commands[0].variant.(Triangle_Command)
	testing.expect(t, tri_open.y1 == tri_open.y2)
	testing.expect(t, tri_open.y3 > tri_open.y1)
}
