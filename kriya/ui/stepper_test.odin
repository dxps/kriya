#+build !wasm32
package ui
import "core:testing"

@(test)
stepper_idle_draws_pill_divider_glyphs_and_value :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	c.mx = -100; c.my = -100
	v := 5
	changed := stepper(&c, 1, {100, 100, 160, 46}, &v, min_val = 0, max_val = 10)
	testing.expect(t, !changed)

	// 2 pill boxes + 2 divider boxes + 3 glyph strokes (minus 1,
	// plus 2) + 1 value label = 8 commands when idle.
	testing.expect(t, len(c.commands) == 8)

	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.color == DARK_PALETTE.border)
	fill := c.commands[1].variant.(Box_Command)
	testing.expect(t, fill.color == DARK_PALETTE.surface_raised)

	left_div := c.commands[2].variant.(Box_Command)
	right_div := c.commands[3].variant.(Box_Command)
	testing.expect(t, left_div.color == DARK_PALETTE.border)
	testing.expect(t, right_div.color == DARK_PALETTE.border)

	value_text := c.commands[7].variant.(Text_Command)
	testing.expect(t, value_text.text == "5")
	testing.expect(t, value_text.color == DARK_PALETTE.text)
}

@(test)
stepper_minus_button_press_release_decrements :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	r := Rect{100, 100, 160, 46}
	// Minus region is on the left — square r.h wide, inset 0.
	c.mx = r.x + 23
	c.my = r.y + 23
	c.pressed = true; c.down = true
	v := 5
	_ = stepper(&c, 1, r, &v, min_val = 0, max_val = 10)
	end(&c); begin(&c)
	c.mx = r.x + 23
	c.my = r.y + 23
	c.down = false; c.released = true
	changed := stepper(&c, 1, r, &v, min_val = 0, max_val = 10)
	testing.expect(t, v == 4)
	testing.expect(t, changed)
}

@(test)
stepper_plus_button_press_release_increments :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	r := Rect{100, 100, 160, 46}
	// Plus region sits at r.x + r.w - btn_w. btn_w = min(r.h, r.w / 3)
	// = min(46, 53.3) = 46. Plus centre at r.x + 160 - 23 = r.x + 137.
	c.mx = r.x + 137
	c.my = r.y + 23
	c.pressed = true; c.down = true
	v := 5
	_ = stepper(&c, 1, r, &v, min_val = 0, max_val = 10)
	end(&c); begin(&c)
	c.mx = r.x + 137
	c.my = r.y + 23
	c.down = false; c.released = true
	changed := stepper(&c, 1, r, &v, min_val = 0, max_val = 10)
	testing.expect(t, v == 6)
	testing.expect(t, changed)
}

@(test)
stepper_clamps_to_min_and_max :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// Caller hands us a stale value above max; stepper clamps it
	// into range before anything else.
	v := 999
	_ = stepper(&c, 1, {0, 0, 160, 46}, &v, min_val = 0, max_val = 10)
	testing.expect(t, v == 10)

	v = -5
	clear(&c.commands)
	_ = stepper(&c, 1, {0, 0, 160, 46}, &v, min_val = 0, max_val = 10)
	testing.expect(t, v == 0)
}

@(test)
stepper_disabled_paints_in_disabled_token_and_ignores_press :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	r := Rect{100, 100, 160, 46}
	c.mx = r.x + 23
	c.my = r.y + 23
	c.pressed = true; c.down = true
	v := 5
	_ = stepper(&c, 1, r, &v, min_val = 0, max_val = 10, disabled = true)
	end(&c); begin(&c)
	c.mx = r.x + 23
	c.my = r.y + 23
	c.down = false; c.released = true
	changed := stepper(&c, 1, r, &v, min_val = 0, max_val = 10, disabled = true)
	// Disabled swallows the press without changing the value.
	testing.expect(t, v == 5)
	testing.expect(t, !changed)

	// Glyph strokes paint in the disabled token, not pal.text.
	// Command order: border + fill + 2 dividers + minus stroke +
	// 2 plus strokes + value label.
	minus_stroke := c.commands[4].variant.(Line_Command)
	testing.expect(t, minus_stroke.color == DARK_PALETTE.disabled)
	value_text := c.commands[7].variant.(Text_Command)
	testing.expect(t, value_text.color == DARK_PALETTE.disabled)
}

@(test)
stepper_arrow_keys_nudge_when_focused :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	c.mx = -100; c.my = -100
	v := 5

	// Give focus manually so the first draw already sees it.
	c.focused = 1
	c.focus_ids_prev[0] = 1
	c.focus_count_prev = 1

	c.nav_right = true
	_ = stepper(&c, 1, {0, 0, 160, 46}, &v, min_val = 0, max_val = 10, step = 2)
	testing.expect(t, v == 7)

	end(&c); begin(&c)
	c.focused = 1
	c.focus_ids_prev[0] = 1
	c.focus_count_prev = 1
	c.nav_left = true
	_ = stepper(&c, 1, {0, 0, 160, 46}, &v, min_val = 0, max_val = 10, step = 2)
	testing.expect(t, v == 5)
}
