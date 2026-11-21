#+build !wasm32
package ui
import "core:testing"

@(test)
badge_subtle_draws_border_inset_fill_and_muted_label :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	badge(&c, {10, 10, 60, 22}, "New")
	testing.expect(t, len(c.commands) == 3)

	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.color == DARK_PALETTE.border)
	testing.expect(t, border.radius == 11)
	testing.expect(t, border.rect.x == 10 && border.rect.w == 60)

	fill := c.commands[1].variant.(Box_Command)
	testing.expect(t, fill.color == DARK_PALETTE.surface_raised)
	testing.expect(t, fill.radius == 10)
	testing.expect(t, fill.rect.x == 11 && fill.rect.y == 11)
	testing.expect(t, fill.rect.w == 58 && fill.rect.h == 20)

	text := c.commands[2].variant.(Text_Command)
	testing.expect(t, text.text == "New")
	testing.expect(t, text.color == DARK_PALETTE.text_muted)
}

@(test)
badge_emphasis_draws_a_single_solid_primary_fill :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	badge(&c, {0, 0, 50, 22}, "Beta", emphasis = true)
	testing.expect(t, len(c.commands) == 2)

	fill := c.commands[0].variant.(Box_Command)
	testing.expect(t, fill.color == DARK_PALETTE.primary)
	testing.expect(t, fill.radius == 11)

	text := c.commands[1].variant.(Text_Command)
	testing.expect(t, text.text == "Beta")
	testing.expect(t, text.color == DARK_PALETTE.text_on_primary)
}

@(test)
badge_corner_radius_always_half_height_regardless_of_global_setting :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	set_corner_radius(&c, 0)
	badge(&c, {0, 0, 40, 30}, "Tag")
	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.radius == 15)
}

@(test)
badge_size_adds_horizontal_padding_to_measured_width :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// test_text_width always returns 140, regardless of the string.
	w, h := badge_size(&c, "New")
	testing.expect(t, w == 160)
	testing.expect(t, h == 22)

	w2, h2 := badge_size(&c, "Long label text", height = 28)
	testing.expect(t, w2 == 160)
	testing.expect(t, h2 == 28)
}
