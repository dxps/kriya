#+build !wasm32
package ui
import "core:testing"

@(test)
divider_draws_a_single_divider_colored_rect :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	divider(&c, {10, 20, 180, 1})
	testing.expect(t, len(c.commands) == 1)

	strip := c.commands[0].variant.(Box_Command)
	testing.expect(t, strip.color == DARK_PALETTE.divider)
	// Sharp edges — a divider isn't a rounded shape.
	testing.expect(t, strip.radius == 0)
	testing.expect(t, strip.rect.x == 10 && strip.rect.y == 20)
	testing.expect(t, strip.rect.w == 180 && strip.rect.h == 1)
}

@(test)
divider_ignores_the_global_corner_radius :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	set_corner_radius(&c, 10)
	divider(&c, {0, 0, 1, 40})
	strip := c.commands[0].variant.(Box_Command)
	// A vertical rule still has 0 radius — a corner on a 1 px strip
	// would just erase the strip's ends.
	testing.expect(t, strip.radius == 0)
}
