#+build !wasm32
package ui
import "core:testing"

@(test)
context_menu_closed_draws_nothing_and_returns_minus_one :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	defer delete(c.commands)
	m: Context_Menu
	idx := context_menu(&c, 1, []string{"Open", "Delete"}, &m)
	testing.expect(t, idx == -1)
	testing.expect(t, len(c.commands) == 0)
}

@(test)
open_context_menu_sets_open_and_anchor :: proc(t: ^testing.T) {
	m: Context_Menu
	open_context_menu(&m, 200, 150)
	testing.expect(t, m.open)
	testing.expect(t, m.x == 200)
	testing.expect(t, m.y == 150)
}

@(test)
context_menu_open_draws_border_fill_and_one_label_per_item :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	c.mx = 220; c.my = 170 // inside the popup, no close
	defer delete(c.commands)
	m: Context_Menu
	open_context_menu(&m, 200, 150)
	_ = context_menu(&c, 1, []string{"Open", "Copy", "Delete"}, &m)

	// border box + fill box + 3 label texts = 5 commands (no hover
	// backgrounds because cursor is away from the exact item rects,
	// and no dividers in this list).
	testing.expect(t, len(c.commands) >= 5)
	border := c.commands[0].variant.(Box_Command)
	fill := c.commands[1].variant.(Box_Command)
	testing.expect(t, border.color == DARK_PALETTE.overlay_border)
	testing.expect(t, fill.color == DARK_PALETTE.overlay)

	last_text := c.commands[len(c.commands) - 1].variant.(Text_Command)
	testing.expect(t, last_text.text == "Delete")
}

@(test)
context_menu_empty_string_renders_as_divider :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	c.mx = 220; c.my = 170
	defer delete(c.commands)
	m: Context_Menu
	open_context_menu(&m, 200, 150)
	_ = context_menu(&c, 1, []string{"Open", "", "Delete"}, &m)

	// Find the divider box among the commands: a 1 px tall box in
	// the divider token lives between "Open" and "Delete".
	found_divider := false
	for cmd in c.commands {
		b, ok := cmd.variant.(Box_Command)
		if !ok {continue}
		if b.color == DARK_PALETTE.divider && b.rect.h == 1 {
			found_divider = true
			break
		}
	}
	testing.expect(t, found_divider)
}

@(test)
context_menu_press_outside_closes :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	m: Context_Menu
	open_context_menu(&m, 200, 150)
	// Press far from the popup's bounds.
	c.mx = 10; c.my = 10
	c.pressed = true; c.down = true
	idx := context_menu(&c, 1, []string{"Open", "Delete"}, &m)
	testing.expect(t, idx == -1)
	testing.expect(t, !m.open)
}

@(test)
context_menu_escape_closes :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	m: Context_Menu
	open_context_menu(&m, 200, 150)
	c.cancel = true
	idx := context_menu(&c, 1, []string{"Open", "Delete"}, &m)
	testing.expect(t, idx == -1)
	testing.expect(t, !m.open)
}

@(test)
context_menu_click_on_item_returns_index_and_closes :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	m: Context_Menu
	open_context_menu(&m, 200, 150)
	// First draw to find the second item's rect, with no input yet.
	_ = context_menu(&c, 1, []string{"Open", "Delete"}, &m)
	// The second label is the last Text_Command; its y is its
	// baseline. The item rect top sits ~ size*0.75 above.
	last_label := c.commands[len(c.commands) - 1].variant.(Text_Command)
	item_y := last_label.y - CONTEXT_MENU_SIZE * 0.5
	mx := last_label.x + 8
	my := item_y + CONTEXT_MENU_ITEM_H / 2
	end(&c); begin(&c)

	// Press frame.
	c.mx = mx; c.my = my
	c.pressed = true; c.down = true
	_ = context_menu(&c, 1, []string{"Open", "Delete"}, &m)
	end(&c); begin(&c)

	// Release frame → click fires on index 1.
	c.mx = mx; c.my = my
	c.down = false; c.released = true
	idx := context_menu(&c, 1, []string{"Open", "Delete"}, &m)
	testing.expect(t, idx == 1)
	testing.expect(t, !m.open)
}

@(test)
context_menu_clamps_to_the_viewport :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 400, 300}
	c.mx = -50; c.my = -50 // keep outside_press from firing before draw
	defer delete(c.commands)
	m: Context_Menu
	// Open deep in the corner so the popup would otherwise spill
	// past the bottom-right of the viewport.
	open_context_menu(&m, 380, 290)
	_ = context_menu(&c, 1, []string{"Open", "Copy", "Delete"}, &m)

	// With viewport {0,0,400,300}, the popup fits inside it. The
	// outer border box is drawn first; its rect = popup_rect
	// expanded by 1 px, so popup fits within {-1, -1, 402, 302}.
	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.rect.x + border.rect.w <= 401)
	testing.expect(t, border.rect.y + border.rect.h <= 301)
}
