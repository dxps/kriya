#+build !wasm32
package ui
import "core:testing"

@(test)
card_draws_border_and_inset_surface_and_returns_content_rect :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	inner := card(&c, {10, 20, 200, 120})

	// Two boxes: outer border + inset fill. Same recipe as badge
	// (subtle) and input, so a card shares that family's look.
	testing.expect(t, len(c.commands) == 2)

	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.color == DARK_PALETTE.border)

	fill := c.commands[1].variant.(Box_Command)
	testing.expect(t, fill.color == DARK_PALETTE.surface_raised)
	testing.expect(t, fill.rect.x == 11 && fill.rect.y == 21)

	// Default pad = 20, so the content rect sits that far inside
	// the outer rect on every side.
	testing.expect(t, inner.x == 30 && inner.y == 40)
	testing.expect(t, inner.w == 160 && inner.h == 80)
}

@(test)
card_custom_pad_returns_matching_inset :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	inner := card(&c, {0, 0, 100, 100}, pad = 4)
	testing.expect(t, inner.x == 4 && inner.y == 4)
	testing.expect(t, inner.w == 92 && inner.h == 92)
}

@(test)
card_zero_pad_returns_the_outer_rect :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	inner := card(&c, {0, 0, 100, 100}, pad = 0)
	testing.expect(t, inner.x == 0 && inner.y == 0)
	testing.expect(t, inner.w == 100 && inner.h == 100)
}

@(test)
card_over_padding_collapses_content_to_zero :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	// A pad bigger than half the width would produce a negative
	// inner size; card clamps it to 0 instead so callers never
	// reason about negative rects.
	inner := card(&c, {0, 0, 40, 40}, pad = 50)
	testing.expect(t, inner.w == 0 && inner.h == 0)
}
