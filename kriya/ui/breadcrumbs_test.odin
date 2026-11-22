#+build !wasm32
package ui
import "core:testing"

@(test)
breadcrumbs_idle_draws_a_label_per_crumb_and_a_triangle_between_them :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	c.mx = -100; c.my = -100 // keep hover off
	idx := breadcrumbs(&c, 1, {0, 0, 800, 24}, []string{"Home", "Settings", "Profile"})
	testing.expect(t, idx == -1)
	// 3 labels + 2 separators = 5 commands.
	testing.expect(t, len(c.commands) == 5)

	a := c.commands[0].variant.(Text_Command)
	sep1 := c.commands[1].variant.(Triangle_Command)
	b := c.commands[2].variant.(Text_Command)
	sep2 := c.commands[3].variant.(Triangle_Command)
	last := c.commands[4].variant.(Text_Command)

	// Earlier crumbs use muted text, last crumb uses the base text
	// color to read as the current page.
	testing.expect(t, a.color == DARK_PALETTE.text_muted)
	testing.expect(t, b.color == DARK_PALETTE.text_muted)
	testing.expect(t, last.color == DARK_PALETTE.text)

	// Separators are the subtle text token so they don't out-shout
	// the crumbs themselves.
	testing.expect(t, sep1.color == DARK_PALETTE.text_subtle)
	testing.expect(t, sep2.color == DARK_PALETTE.text_subtle)
}

@(test)
breadcrumbs_hovered_crumb_brightens_to_base_text :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// First crumb spans from x=0 for test_text_width = 140. Centre it.
	c.mx = 70; c.my = 12
	_ = breadcrumbs(&c, 1, {0, 0, 800, 24}, []string{"Home", "Settings", "Profile"})
	a := c.commands[0].variant.(Text_Command)
	testing.expect(t, a.color == DARK_PALETTE.text)
	testing.expect(t, c.pointer_cursor)
}

@(test)
breadcrumbs_last_crumb_is_inert :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// test_text_width returns 140 per label; 2 separators add
	// 2 * (16 + 6) = 44 px. So the Profile (last) crumb starts at
	// 140 + 22 + 140 + 22 = 324 and spans 140 px — centre at 394.
	c.mx = 394; c.my = 12
	c.pressed = true; c.down = true
	_ = breadcrumbs(&c, 1, {0, 0, 800, 24}, []string{"Home", "Settings", "Profile"})
	end(&c); begin(&c)
	c.mx = 394; c.my = 12
	c.down = false; c.released = true
	idx := breadcrumbs(&c, 1, {0, 0, 800, 24}, []string{"Home", "Settings", "Profile"})
	// A full press+release over the last crumb still returns -1 —
	// the current page isn't a navigable target.
	testing.expect(t, idx == -1)
	// And the last crumb reads as base text even while the pointer
	// sits on it (no hover bump), since there's no interactive state.
	last := c.commands[4].variant.(Text_Command)
	testing.expect(t, last.color == DARK_PALETTE.text)
}

@(test)
breadcrumbs_press_then_release_returns_clicked_index :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	// Settings (index 1) starts at 140 + 22 = 162 and spans 140,
	// so its centre is at 232.
	c.mx = 232; c.my = 12
	c.pressed = true; c.down = true
	_ = breadcrumbs(&c, 1, {0, 0, 800, 24}, []string{"Home", "Settings", "Profile"})
	end(&c); begin(&c)
	c.mx = 232; c.my = 12
	c.down = false; c.released = true
	idx := breadcrumbs(&c, 1, {0, 0, 800, 24}, []string{"Home", "Settings", "Profile"})
	testing.expect(t, idx == 1)
}
