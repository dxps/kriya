package ui

import "core:fmt"
import "core:math"

// Horizontal slider: thumb on a track with a filled prefix, plus a value
// label on the right. Caller passes [min_val, max_val] and a step; the
// stored value stays in that range. step defaults to 1 so the stored
// value and the label both read as whole numbers.
Slider :: struct {
	value:    f32,
	dragging: bool,
}

slider :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	value: ^Slider,
	min_val: f32 = 0,
	max_val: f32 = 100,
	step: f32 = 1,
	precision: int = 0,
) {
	assert(max_val > min_val, "Slider max_val must exceed min_val")
	assert(c.measure_text != nil, "Slider labels require a text measurement callback")

	thumb_r: f32 = 10
	track_h: f32 = 4

	// Reserve the label area on the right. Measuring the min/max strings
	// at this precision gives the widest value the slider will ever show,
	// so the thumb never jumps as the number lengthens.
	format :: proc(v: f32, precision: int) -> string {
		if precision <= 0 {return fmt.tprintf("%d", int(math.round(v)))}
		return fmt.tprintf("%.*f", precision, v)
	}
	max_str := format(max_val, precision)
	min_str := format(min_val, precision)
	label_text_w := max(c.measure_text(max_str, 17), c.measure_text(min_str, 17))
	label_gap: f32 = 14
	label_w := label_text_w + label_gap

	// Track geometry. Inset by thumb_r on each end so the thumb's extremes
	// still sit inside r rather than hanging over its edges.
	track_x := r.x + thumb_r
	track_right := r.x + r.w - label_w - thumb_r
	track_w := max(0, track_right - track_x)
	track_y := r.y + r.h / 2 - track_h / 2
	center_y := r.y + r.h / 2

	// Clamp whatever the caller's model holds before computing geometry.
	value.value = clamp(value.value, min_val, max_val)

	// Drag starts on a press anywhere in the track row (the hit extends a
	// thumb-radius past each end so the user can grab the ends easily and
	// the full row height so it's forgiving).
	hit_rect := Rect{track_x - thumb_r, r.y, track_w + thumb_r * 2, r.h}
	hover := contains(c, hit_rect)
	if hover || value.dragging {c.pointer_cursor = true}

	if c.pressed && hover {
		value.dragging = true
		c.active = id
	}
	if value.dragging {
		if c.down {
			local_x := c.mx - track_x
			new_norm := clamp(local_x / max(1, track_w), 0, 1)
			new_val := min_val + new_norm * (max_val - min_val)
			if step > 0 {
				new_val = min_val + math.round((new_val - min_val) / step) * step
			}
			value.value = clamp(new_val, min_val, max_val)
		} else {
			value.dragging = false
			if c.active == id {c.active = 0}
		}
	}

	norm := (value.value - min_val) / (max_val - min_val)
	thumb_x := track_x + norm * track_w

	// Track background.
	box(c, {track_x, track_y, track_w, track_h}, DEFAULT_PALETTE.border, track_h / 2)
	// Filled prefix.
	fill_w := max(0, thumb_x - track_x)
	if fill_w > 0 {
		box(c, {track_x, track_y, fill_w, track_h}, DEFAULT_PALETTE.primary, track_h / 2)
	}
	// Thumb.
	thumb_color := DEFAULT_PALETTE.text
	if hover || value.dragging {thumb_color = DEFAULT_PALETTE.primary_bright}
	box(
		c,
		{thumb_x - thumb_r, center_y - thumb_r, thumb_r * 2, thumb_r * 2},
		thumb_color,
		thumb_r,
	)

	// Value label — right-aligned against r.x + r.w using its measured width
	// so the number sits flush with the right edge regardless of digit count.
	display := format(value.value, precision)
	label_x := r.x + r.w - c.measure_text(display, 17)
	label(c, label_x, center_y + 6, display, 17, DEFAULT_PALETTE.text)
}
