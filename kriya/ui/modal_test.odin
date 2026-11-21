#+build !wasm32
package ui
import "core:testing"

@(test)
modal_draws_nothing_when_closed :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = Rect{0, 0, 1000, 700}
	defer delete(c.commands)
	m := Modal{open = false}
	idx := modal(&c, 1, "T", "B", []string{"OK"}, &m)
	testing.expect(t, idx == -1)
	testing.expect(t, len(c.commands) == 0)
}

@(test)
modal_paints_on_overlay_layer_when_open :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = Rect{0, 0, 1000, 700}
	defer delete(c.commands)
	m := Modal{open = true}
	idx := modal(&c, 1, "Title", "Body goes here.", []string{"Cancel", "OK"}, &m)
	testing.expect(t, idx == -1)
	// At least the backdrop, dialog border, dialog fill, title text,
	// body line(s), two buttons' worth of boxes and labels.
	testing.expect(t, len(c.commands) > 5)
	// First few commands are overlay; backdrop is the first box.
	testing.expect(t, c.commands[0].layer == .Overlay)
	bg := c.commands[0].variant.(Box_Command)
	testing.expect(t, bg.rect == Rect{0, 0, 1000, 700})
}

@(test)
modal_esc_closes_without_picking_action :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = Rect{0, 0, 1000, 700}
	c.cancel = true
	defer delete(c.commands)
	m := Modal{open = true}
	idx := modal(&c, 1, "T", "B", []string{"Cancel", "OK"}, &m)
	testing.expect(t, idx == -1)
	testing.expect(t, m.open == false)
	// Esc short-circuited before any draw commands were emitted.
	testing.expect(t, len(c.commands) == 0)
}

@(test)
modal_drag_in_title_bar_moves_dialog :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = Rect{0, 0, 1000, 700}
	defer delete(c.commands)
	m := Modal{open = true}

	// Frame 1: press inside the title bar — top band of the centered
	// dialog. Width 400 centers at x=300..700; y=~247..~; title band
	// starts at y and is ~52 px tall. Press near the title's left.
	c.mx = 320; c.my = 260
	c.pressed = true; c.down = true
	_ = modal(&c, 1, "Title", "Body", []string{"OK"}, &m)
	testing.expect(t, m.dragging)

	// Frame 2: move mouse 80 px right, 50 px down while held.
	end(&c); begin(&c)
	c.viewport = Rect{0, 0, 1000, 700}
	c.measure_text = test_text_width
	c.mx = 400; c.my = 310
	c.down = true
	_ = modal(&c, 1, "Title", "Body", []string{"OK"}, &m)
	testing.expect(t, m.offset_x == 80)
	testing.expect(t, m.offset_y == 50)

	// Frame 3: release — drag ends but offset persists.
	end(&c); begin(&c)
	c.viewport = Rect{0, 0, 1000, 700}
	c.measure_text = test_text_width
	c.mx = 400; c.my = 310
	c.down = false; c.released = true
	_ = modal(&c, 1, "Title", "Body", []string{"OK"}, &m)
	testing.expect(t, !m.dragging)
	testing.expect(t, m.offset_x == 80)
	testing.expect(t, m.offset_y == 50)
}

@(test)
modal_drag_clamps_at_viewport_edges :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = Rect{0, 0, 1000, 700}
	defer delete(c.commands)
	m := Modal{open = true}

	// Start a drag.
	c.mx = 320; c.my = 260
	c.pressed = true; c.down = true
	_ = modal(&c, 1, "T", "B", []string{"OK"}, &m)
	testing.expect(t, m.dragging)

	// Try to drag way past the left edge; offset should clamp so dialog.x
	// does not go negative. With width 400 the maximum leftward offset
	// is -(1000 - 400)/2 = -300.
	end(&c); begin(&c)
	c.viewport = Rect{0, 0, 1000, 700}
	c.measure_text = test_text_width
	c.mx = -2000; c.my = 260
	c.down = true
	_ = modal(&c, 1, "T", "B", []string{"OK"}, &m)
	testing.expect(t, m.offset_x == -300)
}

@(test)
modal_clicking_action_closes_and_returns_index :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = Rect{0, 0, 1000, 700}
	defer delete(c.commands)
	m := Modal{open = true}
	// Frame 1: register state; measure where the second ("OK") button
	// lands so frame 2 can press it.
	_ = modal(&c, 1, "T", "B", []string{"Cancel", "OK"}, &m)
	// The last two button commands are the "OK" button's main box and
	// its label; the box command before them belongs to Cancel. Walk
	// backward until we find the Text_Command for "OK" and the preceding
	// Box_Command — that's OK's own rect.
	ok_rect: Rect
	#reverse for cmd in c.commands {
		if tc, is_text := cmd.variant.(Text_Command); is_text && tc.text == "OK" {
			continue
		}
		if box_cmd, is_box := cmd.variant.(Box_Command); is_box {
			ok_rect = box_cmd.rect
			break
		}
	}
	testing.expect(t, ok_rect.w > 0)

	// Frame 2: click in the middle of the OK button.
	end(&c); begin(&c)
	c.mx = ok_rect.x + ok_rect.w / 2
	c.my = ok_rect.y + ok_rect.h / 2
	c.pressed = true
	c.down = true
	_ = modal(&c, 1, "T", "B", []string{"Cancel", "OK"}, &m)
	end(&c); begin(&c)
	c.mx = ok_rect.x + ok_rect.w / 2
	c.my = ok_rect.y + ok_rect.h / 2
	c.down = false
	c.released = true
	idx := modal(&c, 1, "T", "B", []string{"Cancel", "OK"}, &m)
	testing.expect(t, idx == 1)
	testing.expect(t, m.open == false)
}
