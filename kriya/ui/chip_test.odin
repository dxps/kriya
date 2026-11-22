#+build !wasm32
package ui
import "core:testing"

@(test)
chip_draws_border_inset_fill_muted_label_and_two_x_strokes :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	chip(&c, 1, {10, 10, 80, 24}, "Design")
	// 2 boxes (border + inner) + 1 label + 2 × lines = 5 commands.
	testing.expect(t, len(c.commands) == 5)

	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.color == DARK_PALETTE.border)
	testing.expect(t, border.radius == 12)

	fill := c.commands[1].variant.(Box_Command)
	testing.expect(t, fill.color == DARK_PALETTE.surface_raised)
	testing.expect(t, fill.rect.x == 11 && fill.rect.y == 11)
	testing.expect(t, fill.rect.w == 78 && fill.rect.h == 22)

	text := c.commands[2].variant.(Text_Command)
	testing.expect(t, text.color == DARK_PALETTE.text_muted)

	// Idle × strokes paint in the same muted token as the label so
	// the chip reads as one piece until the pointer enters.
	leg_a := c.commands[3].variant.(Line_Command)
	leg_b := c.commands[4].variant.(Line_Command)
	testing.expect(t, leg_a.color == DARK_PALETTE.text_muted)
	testing.expect(t, leg_b.color == DARK_PALETTE.text_muted)
}

@(test)
chip_x_hover_brightens_from_muted_to_text :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// × hit rect lives at the right end of the pill — a square
	// r.h wide. Point the cursor into its centre.
	r := Rect{0, 0, 80, 24}
	c.mx = r.x + r.w - r.h / 2
	c.my = r.y + r.h / 2
	chip(&c, 1, r, "Design")
	leg_a := c.commands[3].variant.(Line_Command)
	testing.expect(t, leg_a.color == DARK_PALETTE.text)
	testing.expect(t, c.pointer_cursor)
}

@(test)
chip_press_then_release_over_x_reports_dismissed :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	r := Rect{0, 0, 80, 24}
	c.mx = r.x + r.w - r.h / 2
	c.my = r.y + r.h / 2
	c.pressed = true; c.down = true
	_ = chip(&c, 1, r, "Design")
	end(&c); begin(&c)
	c.mx = r.x + r.w - r.h / 2
	c.my = r.y + r.h / 2
	c.down = false; c.released = true
	testing.expect(t, chip(&c, 1, r, "Design"))
}

@(test)
chip_press_on_label_area_does_not_dismiss :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	r := Rect{0, 0, 80, 24}
	// Cursor on the label side — outside the × hit square on the right.
	c.mx = r.x + 20
	c.my = r.y + r.h / 2
	c.pressed = true; c.down = true
	_ = chip(&c, 1, r, "Design")
	end(&c); begin(&c)
	c.mx = r.x + 20
	c.my = r.y + r.h / 2
	c.down = false; c.released = true
	testing.expect(t, !chip(&c, 1, r, "Design"))
}

@(test)
chip_size_covers_left_pad_text_and_square_x_region :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// test_text_width always returns 140. 140 + 12 (left pad) + 4
	// (label/× gap) + 24 (× area at default height) = 180.
	w, h := chip_size(&c, "Design")
	testing.expect(t, w == 180)
	testing.expect(t, h == 24)

	// A taller chip grows the × area with the height, so w grows too.
	w2, h2 := chip_size(&c, "Design", height = 32)
	testing.expect(t, w2 == 188)
	testing.expect(t, h2 == 32)
}
