#+build !wasm32
package ui
import "core:testing"

@(test)
tabs_click_selects_hit_tab :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width // 140 for any text
	defer delete(c.commands)
	// Each tab is 140 + 2*18 = 176 wide. Three tabs span 0..528.
	// Click at x=250 lands inside the middle tab (176..352).
	c.mx = 250
	c.my = 20
	c.pressed = true
	c.down = true
	selected := 0
	tabs(&c, 1, {0, 0, 600, 40}, []string{"A", "B", "C"}, &selected)
	testing.expect(t, selected == 1)
}

@(test)
tabs_arrow_keys_walk_selection :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 1
	opts := []string{"A", "B", "C"}

	begin(&c)
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	end(&c)

	c.nav_tab = true
	begin(&c)
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	end(&c)
	testing.expect(t, c.focused == 1)

	c.nav_right = true
	begin(&c)
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	end(&c)
	testing.expect(t, selected == 2)

	// Right again at the end: clamps.
	c.nav_right = true
	begin(&c)
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	end(&c)
	testing.expect(t, selected == 2)

	c.nav_left = true
	begin(&c)
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	end(&c)
	testing.expect(t, selected == 1)
}

@(test)
tabs_read_only_ignores_interaction :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 0
	opts := []string{"A", "B", "C"}
	c.mx = 250
	c.my = 20
	c.pressed = true
	c.focused = 1
	c.nav_right = true
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected, read_only = true)
	testing.expect(t, selected == 0)
	testing.expect(t, !c.pointer_cursor)
}

@(test)
tabs_read_only_skips_focus_registration :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 0
	opts := []string{"A", "B", "C"}
	begin(&c)
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected, read_only = true)
	testing.expect(t, c.focus_count == 0)
	end(&c)
}

@(test)
tabs_selected_tab_emits_underline_box :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 2
	opts := []string{"A", "B", "C"}
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	// Last box emitted is the selected tab's underline. Each tab is 176
	// wide, selected is index 2 (cx = 352), underline sits at
	// cx + 18 = 370, with width 176 - 2*18 = 140, height 2.
	n := len(c.commands)
	last := c.commands[n - 1].variant.(Box_Command)
	testing.expect(t, last.rect.x == 370)
	testing.expect(t, last.rect.w == 140)
	testing.expect(t, last.rect.h == 2)
}

@(test)
tabs_clamps_out_of_range_selected :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	opts := []string{"A", "B", "C"}

	selected := 10
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	testing.expect(t, selected == 2)

	clear(&c.commands)
	selected = -5
	tabs(&c, 1, {0, 0, 600, 40}, opts, &selected)
	testing.expect(t, selected == 0)
}
