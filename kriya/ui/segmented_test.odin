#+build !wasm32
package ui
import "core:testing"

@(test)
segmented_click_selects_hovered_segment :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 0
	opts := []string{"One", "Two", "Three"}
	// Rect width 300 / 3 segments = 100 each. Click at x=150 lands in
	// the middle segment (index 1).
	c.mx = 150
	c.my = 20
	c.pressed = true
	c.down = true
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	testing.expect(t, selected == 1)
}

@(test)
segmented_arrow_keys_cycle_when_focused :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 1
	opts := []string{"A", "B", "C"}

	// Frame 1: register for focus.
	begin(&c)
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	end(&c)

	// Tab to focus it.
	c.nav_tab = true
	begin(&c)
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	end(&c)
	testing.expect(t, c.focused == 1)

	// Left arrow: 1 → 0.
	c.nav_left = true
	begin(&c)
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	end(&c)
	testing.expect(t, selected == 0)

	// Left again at the start: clamps, no wrap.
	c.nav_left = true
	begin(&c)
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	end(&c)
	testing.expect(t, selected == 0)

	// Right arrow: 0 → 1.
	c.nav_right = true
	begin(&c)
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	end(&c)
	testing.expect(t, selected == 1)
}

@(test)
segmented_read_only_ignores_click_and_arrows :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 0
	opts := []string{"A", "B", "C"}
	c.mx = 150
	c.my = 20
	c.pressed = true
	c.nav_right = true

	// Pretend focus was held before the read_only flag was set — arrows
	// still shouldn't move the value.
	c.focused = 1
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected, read_only = true)
	testing.expect(t, selected == 0)
	testing.expect(t, !c.pointer_cursor)
}

@(test)
segmented_read_only_skips_focus_registration :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 0
	opts := []string{"A", "B", "C"}
	begin(&c)
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected, read_only = true)
	testing.expect(t, c.focus_count == 0)
	end(&c)
}

@(test)
segmented_clamps_out_of_range_selected :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	opts := []string{"A", "B", "C"}

	selected := 5
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	testing.expect(t, selected == 2)

	clear(&c.commands)
	selected = -3
	segmented(&c, 1, {0, 0, 300, 40}, opts, &selected)
	testing.expect(t, selected == 0)
}
