package ui

// Immediate-mode stack layout for widgets that take a Rect. Two entry points:
//
//   col/row/begin_stack(bounds, [axis,] pad, gap) -> Stack
//   next(&s, main, cross?) -> Rect
//     Stateful cursor. Each call hands out the next rect of the requested
//     main-axis size, inset by pad and separated from its predecessor by
//     gap. Prefer when the child count isn't known up front, or when a
//     later rect depends on an earlier one. 'peek' returns what 'next'
//     would hand out without advancing the cursor.
//
//   distribute(bounds, axis, pad, gap, sizes[], out[])
//     Pure function. Fixed slots take their pixels first; the remaining
//     main-axis space is split across Flex slots in proportion to weight.
//     Prefer for toolbars, button rows, columns of fields — anywhere the
//     child set is fixed and you want a one-liner.
//
// Both leave the widget vocabulary alone: widgets still take a Rect, so a
// gallery view can mix layout-produced rects and hand-placed ones during
// the migration. 'align_in' places a fixed-size child inside a container
// rect — use it on a full-cross slot to center or right-align a button
// without doing the math at the call site.

Axis :: enum u8 {
	X,
	Y,
}

Size_Kind :: enum u8 {
	Fixed,
	Flex,
}

Size :: struct {
	kind:  Size_Kind,
	value: f32, // pixels for Fixed; weight (>= 0) for Flex
}

px :: #force_inline proc(v: f32) -> Size {return Size{.Fixed, max(0, v)}}
flex :: #force_inline proc(weight: f32 = 1) -> Size {return Size{.Flex, max(0, weight)}}

// ---------------- Stateful stack ----------------

Stack :: struct {
	axis:   Axis,
	bounds: Rect,
	pad:    f32,
	gap:    f32,
	cursor: f32, // world-space position along the main axis
	count:  int, // slots handed out so far; gap only applies after the first
}

begin_stack :: proc(bounds: Rect, axis: Axis, pad: f32 = 0, gap: f32 = 0) -> Stack {
	s := Stack {
		axis   = axis,
		bounds = bounds,
		pad    = max(0, pad),
		gap    = max(0, gap),
		count  = 0,
	}
	s.cursor = axis == .X ? bounds.x + s.pad : bounds.y + s.pad
	return s
}

// Hands out the next rect. 'main' is the size along the stack's main axis;
// 'cross' pins the cross-axis size (nil fills bounds minus padding).
next :: proc(s: ^Stack, main: f32, cross: Maybe(f32) = nil) -> Rect {
	if s.count > 0 {s.cursor += s.gap}
	m := max(0, main)
	r: Rect
	if s.axis == .X {
		cross_h := cross.? or_else max(0, s.bounds.h - 2 * s.pad)
		r = Rect{s.cursor, s.bounds.y + s.pad, m, cross_h}
	} else {
		cross_w := cross.? or_else max(0, s.bounds.w - 2 * s.pad)
		r = Rect{s.bounds.x + s.pad, s.cursor, cross_w, m}
	}
	s.cursor += m
	s.count += 1
	return r
}

// Returns what the next call to 'next' would hand out, without advancing
// the cursor. Lets a widget see the rect before committing to draw.
peek :: proc(s: Stack, main: f32, cross: Maybe(f32) = nil) -> Rect {
	tmp := s
	return next(&tmp, main, cross)
}

// Signed main-axis space left after accounting for the gap that would
// precede the next slot. Negative when the stack has overflowed its bounds
// — callers watching for "does my toolbar fit" branch on sign.
space_left :: proc(s: Stack) -> f32 {
	end := s.axis == .X ? s.bounds.x + s.bounds.w - s.pad : s.bounds.y + s.bounds.h - s.pad
	gap := s.count > 0 ? s.gap : 0
	return end - s.cursor - gap
}

// Non-negative "how much is still available" view of space_left. Prefer
// this when sizing a .Fixed slot from the remainder; prefer space_left
// when you need to detect overflow.
remaining :: proc(s: Stack) -> f32 {return max(0, space_left(s))}

overflowed :: proc(s: Stack) -> bool {return space_left(s) < 0}

// Advance the cursor without producing a rect — useful for spacer gaps that
// shouldn't look like a slot (so the next 'next' still applies 'gap' only
// if it already would have).
skip :: proc(s: ^Stack, amount: f32) {
	s.cursor += max(0, amount)
}

// Convenience aliases for the common axis cases. 'row' lays children out
// along x; 'col' along y. Use begin_stack when the axis is in a variable.
row :: #force_inline proc(bounds: Rect, pad: f32 = 0, gap: f32 = 0) -> Stack {
	return begin_stack(bounds, .X, pad, gap)
}
col :: #force_inline proc(bounds: Rect, pad: f32 = 0, gap: f32 = 0) -> Stack {
	return begin_stack(bounds, .Y, pad, gap)
}

// ---------------- Pure distribute ----------------

// Writes len(sizes) rects to 'out', laid along 'axis' inside 'bounds' after
// insetting by 'pad' and separating consecutive slots by 'gap'. 'out' must
// be at least as long as 'sizes'.
//
// Sizing: Fixed slots take their pixels first; the remaining main-axis
// space is split across Flex slots by weight. When flex_total is 0 the
// remainder is dropped. When fixed+gaps already exceed the available main
// axis, Flex slots get 0 and Fixed slots keep their declared size — slots
// may overflow bounds, and the caller is expected to notice.
distribute :: proc(bounds: Rect, axis: Axis, pad, gap: f32, sizes: []Size, out: []Rect) {
	assert(len(out) >= len(sizes), "distribute: out slice shorter than sizes slice")
	p := max(0, pad)
	g := max(0, gap)
	inner_main := max(0, (axis == .X ? bounds.w : bounds.h) - 2 * p)
	inner_cross := max(0, (axis == .X ? bounds.h : bounds.w) - 2 * p)

	fixed_total: f32 = 0
	flex_total: f32 = 0
	for s in sizes {
		switch s.kind {
		case .Fixed:
			fixed_total += s.value
		case .Flex:
			flex_total += s.value
		}
	}
	gap_total := g * f32(max(0, len(sizes) - 1))
	free_main := max(0, inner_main - fixed_total - gap_total)

	main_cursor := (axis == .X ? bounds.x : bounds.y) + p
	cross_origin := (axis == .X ? bounds.y : bounds.x) + p

	for s, i in sizes {
		if i > 0 {main_cursor += g}
		slot_main: f32
		switch s.kind {
		case .Fixed:
			slot_main = s.value
		case .Flex:
			slot_main = flex_total > 0 ? free_main * s.value / flex_total : 0
		}
		if axis == .X {
			out[i] = Rect{main_cursor, cross_origin, slot_main, inner_cross}
		} else {
			out[i] = Rect{cross_origin, main_cursor, inner_cross, slot_main}
		}
		main_cursor += slot_main
	}
}

// ---------------- Rect utilities ----------------

// Inset returns r shrunk by 'pad' on every side. Negative dimensions are
// clamped to 0 so downstream widgets don't see nonsense rects.
inset :: proc(r: Rect, pad: f32) -> Rect {
	return Rect{r.x + pad, r.y + pad, max(0, r.w - 2 * pad), max(0, r.h - 2 * pad)}
}

// Split cuts 'r' along 'axis' at 'amount' pixels from the leading edge.
// Returns (leading, trailing). Useful for simple "icon + rest" rows
// without opening a full stack.
split :: proc(r: Rect, axis: Axis, amount: f32) -> (Rect, Rect) {
	a := clamp(amount, 0, axis == .X ? r.w : r.h)
	if axis == .X {
		return Rect{r.x, r.y, a, r.h}, Rect{r.x + a, r.y, r.w - a, r.h}
	}
	return Rect{r.x, r.y, r.w, a}, Rect{r.x, r.y + a, r.w, r.h - a}
}

// ---------------- Placement ----------------

Align :: enum u8 {
	Start,
	Center,
	End,
}

// Places a fixed-size child of size {w, h} inside 'bounds' with the given
// alignment on each axis. Pairs with 'next' when a slot is wider than the
// widget that sits in it — a BUTTON_W-wide button in a full-width Y-stack
// slot becomes ui.align_in(slot, {BUTTON_W, CONTROL_H}, .Center, .Start).
align_in :: proc(bounds: Rect, size: [2]f32, h: Align = .Start, v: Align = .Start) -> Rect {
	x, y: f32
	switch h {
	case .Start:
		x = bounds.x
	case .Center:
		x = bounds.x + (bounds.w - size.x) / 2
	case .End:
		x = bounds.x + bounds.w - size.x
	}
	switch v {
	case .Start:
		y = bounds.y
	case .Center:
		y = bounds.y + (bounds.h - size.y) / 2
	case .End:
		y = bounds.y + bounds.h - size.y
	}
	return Rect{x, y, size.x, size.y}
}
