#+build !wasm32
package ui
import "core:testing"

@(test)
stack_hands_out_fixed_rects_along_x :: proc(t: ^testing.T) {
	s := begin_stack({10, 20, 300, 40}, .X, 0, 8)
	a := next(&s, 100)
	b := next(&s, 50)
	testing.expect(t, a == Rect{10, 20, 100, 40})
	testing.expect(t, b == Rect{118, 20, 50, 40}) // 10 + 100 + 8
}

@(test)
stack_insets_by_padding_on_both_axes :: proc(t: ^testing.T) {
	s := begin_stack({0, 0, 200, 60}, .Y, 12, 0)
	r := next(&s, 24)
	testing.expect(t, r == Rect{12, 12, 176, 24}) // x+pad, y+pad, w-2pad, 24
	testing.expect(t, remaining(s) == 60 - 12 - 12 - 24)
}

@(test)
stack_cross_override_pins_cross_axis :: proc(t: ^testing.T) {
	s := begin_stack({0, 0, 400, 80}, .X, 0, 0)
	r := next(&s, 100, f32(40))
	testing.expect(t, r == Rect{0, 0, 100, 40})
}

@(test)
distribute_splits_flex_remainder_by_weight :: proc(t: ^testing.T) {
	out: [3]Rect
	sizes := []Size{px(100), flex(1), flex(3)}
	distribute({0, 0, 500, 40}, .X, 0, 20, sizes, out[:])
	// Fixed = 100, gaps = 2*20 = 40, free = 500 - 100 - 40 = 360.
	// weights 1:3 → 90 and 270.
	testing.expect(t, out[0] == Rect{0, 0, 100, 40})
	testing.expect(t, out[1] == Rect{120, 0, 90, 40}) // 100 + 20
	testing.expect(t, out[2] == Rect{230, 0, 270, 40}) // 120 + 90 + 20
}

@(test)
distribute_drops_remainder_when_no_flex_slots :: proc(t: ^testing.T) {
	out: [2]Rect
	distribute({0, 0, 500, 40}, .X, 0, 0, []Size{px(100), px(100)}, out[:])
	testing.expect(t, out[0].w == 100 && out[1].w == 100)
}

@(test)
distribute_overflow_keeps_fixed_sizes :: proc(t: ^testing.T) {
	// Fixed total (300) exceeds bounds (200); flex gets 0, fixed unchanged,
	// slots run past the right edge. Caller is expected to notice.
	out: [3]Rect
	distribute({0, 0, 200, 40}, .X, 0, 0, []Size{px(150), px(150), flex(1)}, out[:])
	testing.expect(t, out[0].w == 150)
	testing.expect(t, out[1].w == 150)
	testing.expect(t, out[2].w == 0)
}

@(test)
distribute_respects_padding :: proc(t: ^testing.T) {
	out: [2]Rect
	distribute({0, 0, 200, 100}, .Y, 10, 0, []Size{px(30), flex(1)}, out[:])
	testing.expect(t, out[0] == Rect{10, 10, 180, 30})
	testing.expect(t, out[1] == Rect{10, 40, 180, 50}) // 100 - 2*10 - 30
}

@(test)
split_cuts_along_axis :: proc(t: ^testing.T) {
	a, b := split(Rect{0, 0, 100, 40}, .X, 30)
	testing.expect(t, a == Rect{0, 0, 30, 40})
	testing.expect(t, b == Rect{30, 0, 70, 40})
	c, d := split(Rect{0, 0, 100, 40}, .Y, 100)
	testing.expect(t, c == Rect{0, 0, 100, 40})
	testing.expect(t, d == Rect{0, 40, 100, 0})
}

@(test)
row_and_col_alias_begin_stack :: proc(t: ^testing.T) {
	a := row({0, 0, 100, 40}, gap = 8)
	b := begin_stack({0, 0, 100, 40}, .X, 0, 8)
	testing.expect(t, a == b)
	c := col({0, 0, 100, 40}, pad = 12)
	d := begin_stack({0, 0, 100, 40}, .Y, 12, 0)
	testing.expect(t, c == d)
}

@(test)
peek_does_not_advance_cursor :: proc(t: ^testing.T) {
	s := row({0, 0, 200, 40}, gap = 8)
	a := peek(s, 60)
	b := next(&s, 60)
	testing.expect(t, a == b)
	c := next(&s, 60)
	testing.expect(t, c == Rect{68, 0, 60, 40})
}

@(test)
space_left_is_signed_and_overflow_detects :: proc(t: ^testing.T) {
	s := row({0, 0, 100, 40}, gap = 10)
	_ = next(&s, 60)
	testing.expect(t, space_left(s) == 30) // 100 - 60 - 10
	testing.expect(t, !overflowed(s))
	_ = next(&s, 50)
	testing.expect(t, space_left(s) < 0)
	testing.expect(t, overflowed(s))
	testing.expect(t, remaining(s) == 0) // clamped
}

@(test)
align_in_places_fixed_child_inside_bounds :: proc(t: ^testing.T) {
	r := align_in({0, 0, 200, 40}, {120, 30}, .Center, .Center)
	testing.expect(t, r == Rect{40, 5, 120, 30})
	r = align_in({10, 10, 200, 40}, {50, 30}, .End, .Start)
	testing.expect(t, r == Rect{160, 10, 50, 30})
	r = align_in({0, 0, 200, 40}, {50, 30}, .Start, .End)
	testing.expect(t, r == Rect{0, 10, 50, 30})
}

label_in_test_measure :: proc(text: string, size: f32) -> f32 {return 120}

@(test)
label_in_computes_baseline_from_alignment :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = label_in_test_measure
	defer delete(c.commands)

	// Vertical Center in a 46-tall rect with 18pt text: 0 + 23 + 18*0.25 = 27.5
	label_in(&c, {0, 0, 200, 46}, "Hi", 18, .Start, .Center)
	cmd := c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.x == 0)
	testing.expect(t, cmd.y == 27.5)

	// Vertical Start: baseline sits size*0.75 below rect top.
	clear(&c.commands)
	label_in(&c, {10, 10, 200, 46}, "Hi", 20, .Start, .Start)
	cmd = c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.y == 10 + 20 * 0.75)

	// Vertical End: baseline sits size*0.25 above rect bottom.
	clear(&c.commands)
	label_in(&c, {0, 0, 200, 46}, "Hi", 20, .Start, .End)
	cmd = c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.y == 46 - 20 * 0.25)
}

@(test)
label_in_horizontal_alignment_uses_measure_text :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = label_in_test_measure // returns 120 for anything
	defer delete(c.commands)

	// Center in a 200-wide rect with 120-wide text: (200 - 120)/2 = 40.
	label_in(&c, {0, 0, 200, 46}, "Hello", 18, .Center, .Center)
	cmd := c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.x == 40)

	clear(&c.commands)
	label_in(&c, {10, 0, 200, 46}, "Hello", 18, .End, .Center)
	cmd = c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.x == 10 + 200 - 120)
}
