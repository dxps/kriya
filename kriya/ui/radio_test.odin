#+build !wasm32
package ui
import "core:testing"

@(test)
radio_click_sets_selected_to_index :: proc(t: ^testing.T) {
	c := Context {
		mx           = 5,
		my           = 5,
		pressed      = true,
		down         = true,
		measure_text = test_text_width,
	}
	defer delete(c.commands)
	selected := 0
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1)
	testing.expect(t, c.pointer_cursor)

	end(&c); begin(&c)
	c.mx = 5; c.my = 5; c.released = true; c.down = false
	c.measure_text = test_text_width
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1)
	testing.expect(t, selected == 1)
}

@(test)
radio_release_outside_label_does_not_select :: proc(t: ^testing.T) {
	c := Context {
		mx           = 5,
		my           = 5,
		pressed      = true,
		down         = true,
		measure_text = test_text_width,
	}
	defer delete(c.commands)
	selected := 0
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1)

	end(&c); begin(&c)
	c.mx = 500; c.down = false; c.released = true
	c.measure_text = test_text_width
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1)
	testing.expect(t, selected == 0)
}

@(test)
radio_read_only_ignores_click :: proc(t: ^testing.T) {
	c := Context {
		mx           = 5,
		my           = 5,
		pressed      = true,
		down         = true,
		released     = true,
		measure_text = test_text_width,
	}
	defer delete(c.commands)
	selected := 0
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1, read_only = true)
	testing.expect(t, selected == 0)
	testing.expect(t, !c.pointer_cursor)
}

@(test)
radio_enter_selects_when_focused :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 0

	// Frame 1: register for Tab order.
	begin(&c)
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1)
	end(&c)

	// Frame 2: Tab → focus the radio.
	c.nav_tab = true
	begin(&c)
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1)
	end(&c)
	testing.expect(t, c.focused == 1)

	// Frame 3: Enter → selected moves to this radio's index.
	c.enter = true
	begin(&c)
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1)
	end(&c)
	testing.expect(t, selected == 1)
}

@(test)
radio_read_only_skips_focus_registration :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	selected := 0
	begin(&c)
	radio(&c, 1, {0, 0, 0, 0}, "Option B", &selected, 1, read_only = true)
	testing.expect(t, c.focus_count == 0)
	end(&c)
}

@(test)
radio_group_selects_mutually_exclusive :: proc(t: ^testing.T) {
	// Three radios share one 'selected' int; clicking one sets it, so
	// the other two automatically read as unchosen via selected^ == index.
	c := Context {
		mx           = 5,
		my           = 5,
		pressed      = true,
		down         = true,
		released     = true,
		measure_text = test_text_width,
	}
	defer delete(c.commands)
	selected := 0
	// Click at (5, 5) hits the first radio at y=0. The others are
	// rendered but out of click range, so selected moves to 0 (already
	// its value — asserts stability).
	radio(&c, 1, {0, 0, 0, 0}, "A", &selected, 0)
	radio(&c, 2, {0, 30, 0, 0}, "B", &selected, 1)
	radio(&c, 3, {0, 60, 0, 0}, "C", &selected, 2)
	testing.expect(t, selected == 0)

	end(&c); begin(&c)
	c.mx = 5; c.my = 35; c.pressed = true; c.down = true; c.released = true
	c.measure_text = test_text_width
	radio(&c, 1, {0, 0, 0, 0}, "A", &selected, 0)
	radio(&c, 2, {0, 30, 0, 0}, "B", &selected, 1)
	radio(&c, 3, {0, 60, 0, 0}, "C", &selected, 2)
	testing.expect(t, selected == 1)
}
