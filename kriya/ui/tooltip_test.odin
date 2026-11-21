#+build !wasm32
package ui
import "core:testing"

@(test)
tooltip_hidden_before_delay :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.mx = 20; c.my = 20
	c.dt = 0.2
	defer delete(c.commands)
	tooltip(&c, 1, {0, 100, 100, 40}, "hint")
	// Hover started this frame; nothing drawn yet.
	testing.expect(t, len(c.commands) == 0)
	testing.expect(t, c.tooltip_id == 0) // not inside hit, so no id claim
}

@(test)
tooltip_shows_after_hover_hold_exceeds_delay :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	// Cursor sits inside the hit rect.
	c.mx = 50; c.my = 20
	c.dt = 0.6
	defer delete(c.commands)
	hit := Rect{0, 0, 100, 40}
	tooltip(&c, 1, hit, "hint")
	// First frame: 0 accumulated → under delay, nothing drawn yet.
	testing.expect(t, len(c.commands) == 0)

	// Second frame: accumulated 0.6s > default delay 0.5s → draws.
	tooltip(&c, 1, hit, "hint")
	testing.expect(t, len(c.commands) == 3) // border, fill, text
	testing.expect(t, c.commands[0].layer == .Overlay)
	testing.expect(t, c.commands[1].layer == .Overlay)
	testing.expect(t, c.commands[2].layer == .Overlay)
}

@(test)
tooltip_resets_when_cursor_leaves_hit :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.mx = 50; c.my = 20
	c.dt = 0.6
	defer delete(c.commands)
	hit := Rect{0, 0, 100, 40}
	tooltip(&c, 1, hit, "hint")
	tooltip(&c, 1, hit, "hint")
	// Tooltip id claimed, timer at >= 0.6.
	testing.expect(t, c.tooltip_id == 1)

	// Move cursor out of hit.
	c.mx = 500; c.my = 500
	clear(&c.commands)
	tooltip(&c, 1, hit, "hint")
	// Hover released; next hover will start a fresh timer.
	testing.expect(t, c.tooltip_id == 0)
	testing.expect(t, c.tooltip_hover_time == 0)
	testing.expect(t, len(c.commands) == 0)
}

@(test)
tooltip_positions_below_hit_when_above_would_clip :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.mx = 50; c.my = 20
	c.dt = 1
	defer delete(c.commands)
	// Hit near y=0 — tooltip above would land at negative y, so the
	// code flips it below the hit rect instead.
	hit := Rect{0, 10, 100, 40}
	tooltip(&c, 1, hit, "hint")
	tooltip(&c, 1, hit, "hint")
	border := c.commands[0].variant.(Box_Command)
	// tip_h = 13 + 12 = 25; tip_y above = 10 - 25 - 8 = -23 → flip to
	// hit.y + hit.h + gap = 10 + 40 + 8 = 58, border goes 1 px above.
	testing.expect(t, border.rect.y == 57)
}
