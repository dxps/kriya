#+build !wasm32
package ui
import "core:testing"

@(test)
avatar_subtle_draws_border_inset_fill_and_muted_initials :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	avatar(&c, {10, 10, 40, 40}, "Marius Ileana")
	testing.expect(t, len(c.commands) == 3)

	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.color == DARK_PALETTE.border)
	testing.expect(t, border.radius == 20)
	testing.expect(t, border.rect.x == 10 && border.rect.w == 40)

	fill := c.commands[1].variant.(Box_Command)
	testing.expect(t, fill.color == DARK_PALETTE.surface_raised)
	testing.expect(t, fill.radius == 19)
	testing.expect(t, fill.rect.x == 11 && fill.rect.y == 11)
	testing.expect(t, fill.rect.w == 38 && fill.rect.h == 38)

	text := c.commands[2].variant.(Text_Command)
	testing.expect(t, text.text == "MI")
	testing.expect(t, text.color == DARK_PALETTE.text_muted)
}

@(test)
avatar_emphasis_draws_a_single_solid_primary_fill :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	avatar(&c, {0, 0, 32, 32}, "Ana Popescu", emphasis = true)
	testing.expect(t, len(c.commands) == 2)

	fill := c.commands[0].variant.(Box_Command)
	testing.expect(t, fill.color == DARK_PALETTE.primary)
	testing.expect(t, fill.radius == 16)

	text := c.commands[1].variant.(Text_Command)
	testing.expect(t, text.text == "AP")
	testing.expect(t, text.color == DARK_PALETTE.text_on_primary)
}

@(test)
avatar_corner_radius_always_min_axis_half_regardless_of_global :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	set_corner_radius(&c, 0)
	avatar(&c, {0, 0, 60, 40}, "Ana")
	border := c.commands[0].variant.(Box_Command)
	// min(w, h) / 2 — the shorter axis sets the radius so a capsule
	// stays fully rounded on its ends instead of squaring off.
	testing.expect(t, border.radius == 20)
}

@(test)
initials_handles_empty_single_and_multi_word_names :: proc(t: ^testing.T) {
	testing.expect_value(t, initials(""), "?")
	testing.expect_value(t, initials("   "), "?")
	testing.expect_value(t, initials("Ana"), "A")
	testing.expect_value(t, initials("ana"), "A")
	testing.expect_value(t, initials("Marius Ileana"), "MI")
	testing.expect_value(t, initials("  ana  popescu "), "AP")
	// Three-word names take the first and the LAST, so middle names
	// don't shift the second initial off the family name.
	testing.expect_value(t, initials("Ana Maria Popescu"), "AP")
}

@(test)
initials_preserves_already_uppercase_non_ascii_glyphs :: proc(t: ^testing.T) {
	// ASCII-only uppercasing: Romanian names written with proper
	// capitalization stay as-is. A lowercase non-ASCII first rune
	// passes through unchanged, which is documented behavior.
	testing.expect_value(t, initials("Ștefan Ionescu"), "ȘI")
	testing.expect_value(t, initials("ștefan"), "ș")
}
