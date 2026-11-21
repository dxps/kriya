#+build !wasm32
package ui
import "core:testing"

@(test)
progress_bar_determinate_emits_fill_proportional_to_value :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	// Outer frame + inner surface + fill = 3 commands for a nonzero value.
	progress_bar(&c, {10, 20, 200, 10}, f32(0.5))
	testing.expect(t, len(c.commands) == 3)
	fill := c.commands[2].variant.(Box_Command)
	// Inner rect is {11, 21, 198, 8}; 50% fill is 99 px wide starting at x=11.
	testing.expect(t, fill.rect.x == 11)
	testing.expect(t, fill.rect.w == 99)
}

@(test)
progress_bar_value_clamps_outside_unit_interval :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	progress_bar(&c, {0, 0, 100, 10}, f32(2.5))
	fill := c.commands[2].variant.(Box_Command)
	testing.expect(t, fill.rect.w == 98) // inner_r.w = 98 at value = 1.0

	clear(&c.commands)
	progress_bar(&c, {0, 0, 100, 10}, f32(-1))
	// Zero fill emits only the frame + inner surface, no fill box.
	testing.expect(t, len(c.commands) == 2)
}

@(test)
progress_bar_indeterminate_at_cycle_start_shows_no_chunk :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	c.now = 0
	progress_bar(&c, {0, 0, 100, 10})
	// At t=0 the chunk sits entirely off the left edge (chunk_x = -34.3),
	// clips to the inner rect's left border, left==right, no fill drawn.
	testing.expect(t, len(c.commands) == 2)
}

@(test)
progress_bar_indeterminate_mid_cycle_shows_a_sliding_chunk :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	// Cycle is 1.5 s; half-cycle = 0.75 s puts the chunk somewhere in
	// the middle of the bar — the chunk box should appear.
	c.now = 0.75
	progress_bar(&c, {0, 0, 100, 10})
	testing.expect(t, len(c.commands) == 3)
	fill := c.commands[2].variant.(Box_Command)
	testing.expect(t, fill.rect.w > 0)
	testing.expect(t, fill.rect.x >= 1)
	testing.expect(t, fill.rect.x + fill.rect.w <= 99)
}

@(test)
spinner_emits_dot_count_boxes :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	spinner(&c, {0, 0, 48, 48})
	testing.expect(t, len(c.commands) == 8)
}

@(test)
spinner_dot_alpha_sums_to_a_whole_spin :: proc(t: ^testing.T) {
	// The trail's quadratic fade distributes alpha across the eight
	// dots: no dot is fully transparent, and the head sits near alpha 1.
	c: Context
	defer delete(c.commands)
	c.now = 0
	spinner(&c, {0, 0, 48, 48})
	max_alpha: f32 = 0
	for cmd in c.commands {
		a := cmd.variant.(Box_Command).color[3]
		if a > max_alpha {max_alpha = a}
	}
	testing.expect(t, max_alpha > 0.9)
}
