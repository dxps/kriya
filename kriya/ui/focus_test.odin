#+build !wasm32
package ui
import "core:testing"

@(test)
focus_registry_captures_focusable_ids :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	begin(&c)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	testing.expect(t, c.focus_count == 2)
	testing.expect(t, c.focus_ids[0] == 1)
	testing.expect(t, c.focus_ids[1] == 2)
	end(&c)
	testing.expect(t, c.focus_count_prev == 2)
}

@(test)
tab_walks_registered_focus_order_and_wraps :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	// Frame 1 just populates the previous-frame registry.
	begin(&c)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	end(&c)

	// Frame 2: Tab from no focus → first registered.
	c.nav_tab = true
	begin(&c)
	testing.expect(t, c.focused == 1)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	end(&c)

	// Frame 3: Tab from 1 → 2.
	c.nav_tab = true
	begin(&c)
	testing.expect(t, c.focused == 2)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	end(&c)

	// Frame 4: Tab from 2 → wraps to 1.
	c.nav_tab = true
	begin(&c)
	testing.expect(t, c.focused == 1)
	end(&c)
}

@(test)
shift_tab_walks_backward :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	begin(&c)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	_ = focusable(&c, 3, {0, 100, 100, 40})
	end(&c)

	c.focused = 2
	c.nav_tab = true
	c.nav_shift = true
	begin(&c)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	_ = focusable(&c, 3, {0, 100, 100, 40})
	testing.expect(t, c.focused == 1)
	end(&c)

	// Wrap at the start.
	c.nav_tab = true
	c.nav_shift = true
	begin(&c)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	_ = focusable(&c, 3, {0, 100, 100, 40})
	testing.expect(t, c.focused == 3)
	end(&c)
}

@(test)
click_inside_hit_region_sets_focus :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	c.mx = 50; c.my = 20; c.pressed = true
	begin(&c)
	_ = focusable(&c, 1, {0, 0, 100, 40})
	_ = focusable(&c, 2, {0, 50, 100, 40})
	testing.expect(t, c.focused == 1)
	end(&c)
}

@(test)
enter_activates_focused_button :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)

	// Frame 1: register the button.
	begin(&c)
	_ = button(&c, 1, {0, 0, 100, 40}, "OK")
	end(&c)

	// Frame 2: Tab → focused.
	c.nav_tab = true
	begin(&c)
	_ = button(&c, 1, {0, 0, 100, 40}, "OK")
	testing.expect(t, c.focused == 1)
	end(&c)

	// Frame 3: Enter → clicked.
	c.enter = true
	begin(&c)
	clicked := button(&c, 1, {0, 0, 100, 40}, "OK")
	testing.expect(t, clicked)
	end(&c)
}

@(test)
enter_toggles_focused_checkbox :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	value := false

	// Register the checkbox and focus it.
	begin(&c)
	checkbox(&c, 1, {0, 0, 0, 0}, "Option", &value)
	end(&c)
	c.nav_tab = true
	begin(&c)
	checkbox(&c, 1, {0, 0, 0, 0}, "Option", &value)
	end(&c)
	testing.expect(t, c.focused == 1)

	// Enter flips the value.
	c.enter = true
	begin(&c)
	checkbox(&c, 1, {0, 0, 0, 0}, "Option", &value)
	end(&c)
	testing.expect(t, value)
}

@(test)
disabled_button_does_not_register_for_focus :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	begin(&c)
	_ = button(&c, 1, {0, 0, 100, 40}, "Save", true)
	testing.expect(t, c.focus_count == 0)
	end(&c)
}
