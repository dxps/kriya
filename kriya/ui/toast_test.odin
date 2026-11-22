#+build !wasm32
package ui
import "core:testing"

@(test)
toast_push_copies_text_and_queues_at_full_duration :: proc(t: ^testing.T) {
	c: Context
	stack: Toast_Stack
	toast_push(&c, &stack, "Saved")
	testing.expect(t, stack.count == 1)
	testing.expect(t, stack.items[0].text_len == 5)
	testing.expect(t, string(stack.items[0].text[:5]) == "Saved")
	testing.expect(t, stack.items[0].remaining == TOAST_DURATION)
	testing.expect(t, stack.items[0].kind == .Info) // default kind
}

@(test)
toast_push_records_kind_and_optional_per_call_duration :: proc(t: ^testing.T) {
	c: Context
	stack: Toast_Stack
	toast_push(&c, &stack, "Oops", kind = .Error, duration = 1.5)
	testing.expect(t, stack.items[0].kind == .Error)
	testing.expect(t, stack.items[0].remaining == 1.5)
}

@(test)
toast_push_uses_context_duration_when_set :: proc(t: ^testing.T) {
	c: Context
	set_toast_duration(&c, 7)
	stack: Toast_Stack
	toast_push(&c, &stack, "Saved")
	testing.expect(t, stack.items[0].remaining == 7)
}

@(test)
toast_push_drops_oldest_when_stack_is_full :: proc(t: ^testing.T) {
	c: Context
	stack: Toast_Stack
	for i in 0 ..< TOAST_STACK_SIZE + 2 {
		toast_push(&c, &stack, "x")
		stack.items[stack.count - 1].text[0] = u8('0' + i)
	}
	// Stack capped at its size; the oldest two pushes got shifted
	// out, so the surviving bottom entry is the 3rd push ('2').
	testing.expect(t, stack.count == TOAST_STACK_SIZE)
	testing.expect(t, stack.items[0].text[0] == '2')
	testing.expect(t, stack.items[TOAST_STACK_SIZE - 1].text[0] == u8('0' + TOAST_STACK_SIZE + 1))
}

@(test)
toasts_decrements_remaining_by_dt_and_removes_expired :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	stack: Toast_Stack
	toast_push(&c, &stack, "Saved")
	toast_push(&c, &stack, "Pending")
	stack.items[1].remaining = 0.05 // about to expire

	c.dt = 0.1 // one 100 ms frame — the pending toast ages out
	toasts(&c, 1, &stack)

	testing.expect(t, stack.count == 1)
	testing.expect(t, string(stack.items[0].text[:stack.items[0].text_len]) == "Saved")
	testing.expect(t, stack.items[0].remaining == TOAST_DURATION - 0.1)
}

@(test)
toasts_release_over_x_hit_zeroes_remaining :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	stack: Toast_Stack
	toast_push(&c, &stack, "Saved")

	// First frame to figure out where the toast's × hit rect lands,
	// without any input.
	toasts(&c, 1, &stack)
	// Last two Line_Commands are the × strokes; take their midpoint
	// from the first stroke endpoints.
	leg := c.commands[len(c.commands) - 2].variant.(Line_Command)
	mx := (leg.x1 + leg.x2) / 2
	my := (leg.y1 + leg.y2) / 2
	end(&c); begin(&c)

	// Press frame over ×.
	c.mx = mx; c.my = my
	c.pressed = true; c.down = true
	toasts(&c, 1, &stack)
	end(&c); begin(&c)

	// Release frame.
	c.mx = mx; c.my = my
	c.down = false; c.released = true
	toasts(&c, 1, &stack)

	// The × click zeros remaining, so the toast sits at or below 0
	// and the next draw call purges it; one more frame confirms
	// removal.
	testing.expect(t, stack.items[0].remaining <= 0)
	end(&c); begin(&c)
	c.dt = 0
	toasts(&c, 1, &stack)
	testing.expect(t, stack.count == 0)
}

@(test)
toasts_fade_alpha_scales_in_last_fade_window :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	stack: Toast_Stack
	toast_push(&c, &stack, "Saved")
	// Park the toast half-way through its fade window.
	stack.items[0].remaining = TOAST_FADE / 2 + 0.00001 // offset avoids the removal path
	c.dt = 0
	toasts(&c, 1, &stack)

	// First box is the border, drawn with overlay_border scaled by
	// alpha. Expected alpha ≈ remaining / TOAST_FADE ≈ 0.5.
	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.color.a > 0.4 && border.color.a < 0.6)
}

@(test)
toasts_anchor_at_top_right_by_default :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	stack: Toast_Stack
	toast_push(&c, &stack, "Saved")
	toasts(&c, 1, &stack)

	// Border box of the (single) toast. test_text_width always
	// returns 140 → w = 14 + 14 + 10 + 140 + 6 + 34 = 218.
	// Top_Right: x ends at 1024 - 40 = 984, top starts at 40.
	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.rect.x + border.rect.w == 984)
	testing.expect(t, border.rect.y == 40)
}

@(test)
toasts_anchor_moves_with_set_toast_corner :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	set_toast_corner(&c, .Bottom_Left)
	stack: Toast_Stack
	toast_push(&c, &stack, "Saved")
	toasts(&c, 1, &stack)

	// Bottom_Left: x starts at 40, bottom ends at 720 - 40 = 680.
	border := c.commands[0].variant.(Box_Command)
	testing.expect(t, border.rect.x == 40)
	testing.expect(t, border.rect.y + border.rect.h == 680)
}

@(test)
toasts_newest_sits_closest_to_top_anchor :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = test_text_width
	c.viewport = {0, 0, 1024, 720}
	defer delete(c.commands)
	stack: Toast_Stack
	toast_push(&c, &stack, "Old")
	toast_push(&c, &stack, "New")
	toasts(&c, 1, &stack)

	// Two toasts, each 2 box + 3 icon commands + ... — grab the
	// first box of each toast. Newest draws first (index count-1
	// walks first), so commands[0] is the new toast's border.
	new_border := c.commands[0].variant.(Box_Command)
	// Older toast's border starts after the new toast's full draw.
	// Count commands belonging to one toast: 2 (border+fill) + icon
	// commands (3 for Info) + label (1) + × (2 lines) = 8.
	old_border := c.commands[8].variant.(Box_Command)
	// Newest (last pushed) lands closest to the top anchor = smaller
	// y than the older one, which stacks below it.
	testing.expect(t, new_border.rect.y < old_border.rect.y)
}
