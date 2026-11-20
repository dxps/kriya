package ui

import "core:fmt"
import "core:math"

// Horizontal or vertical slider: thumb on a track with a filled prefix,
// plus a value label (to the right in horizontal mode, centered below in
// vertical mode). Caller passes [min_val, max_val] and a step; the stored
// value stays in that range. step defaults to 1 so the stored value and
// the label both read as whole numbers.
Slider :: struct {
	value:    f32,
	dragging: bool,
}

Slider_Orientation :: enum {
	Horizontal,
	Vertical,
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
	orientation: Slider_Orientation = .Horizontal,
) {
	assert(max_val > min_val, "Slider max_val must exceed min_val")
	assert(c.measure_text != nil, "Slider labels require a text measurement callback")

	thumb_r: f32 = 10
	track_thickness: f32 = 4

	// Widest string the label will ever show at this precision drives the
	// reserved label area so the thumb's travel doesn't shift as the digit
	// count changes.
	format :: proc(v: f32, precision: int) -> string {
		if precision <= 0 {return fmt.tprintf("%d", int(math.round(v)))}
		return fmt.tprintf("%.*f", precision, v)
	}
	max_str := format(max_val, precision)
	min_str := format(min_val, precision)
	label_text_w := max(c.measure_text(max_str, 17), c.measure_text(min_str, 17))

	// Clamp whatever the caller's model holds before computing geometry.
	value.value = clamp(value.value, min_val, max_val)

	// Shared geometry: track_start/track_len are the thumb's travel span
	// along its axis; cross_center is the perpendicular center the track
	// and thumb sit on. In horizontal mode the thumb moves along x and
	// cross_center is a y; in vertical mode it's the other way around,
	// with min at the bottom and max at the top — standard fader
	// behavior.
	vertical := orientation == .Vertical
	label_gap_h: f32 = 14
	label_area_h: f32 = vertical ? 26 : label_text_w + label_gap_h
	track_start, track_len, cross_center: f32
	if vertical {
		track_start = r.y + thumb_r
		track_end := r.y + r.h - label_area_h - thumb_r
		track_len = max(0, track_end - track_start)
		cross_center = r.x + r.w / 2
	} else {
		track_start = r.x + thumb_r
		track_end := r.x + r.w - label_area_h - thumb_r
		track_len = max(0, track_end - track_start)
		cross_center = r.y + r.h / 2
	}

	// Hit rect: extends a thumb-radius past each end, and spans enough on
	// the cross axis to be forgiving at the thumb's natural size.
	hit_rect: Rect
	if vertical {
		hit_w := thumb_r * 2 + 8
		hit_rect = {cross_center - hit_w / 2, track_start - thumb_r, hit_w, track_len + thumb_r * 2}
	} else {
		hit_rect = {track_start - thumb_r, r.y, track_len + thumb_r * 2, r.h}
	}
	hover := contains(c, hit_rect)
	if hover || value.dragging {c.pointer_cursor = true}

	// Registers for Tab order and handles click-to-focus. Arrow keys when
	// focused nudge the value by one step on the matching axis: left /
	// right for horizontal, down / up for vertical (fader convention —
	// up increases, down decreases).
	focused := focusable(c, id, hit_rect)
	if focused && step > 0 {
		delta: f32 = 0
		if vertical {
			if c.nav_up {delta = step}
			if c.nav_down {delta = -step}
		} else {
			if c.nav_left {delta = -step}
			if c.nav_right {delta = step}
		}
		if delta != 0 {value.value = clamp(value.value + delta, min_val, max_val)}
	}

	if c.pressed && hover {
		value.dragging = true
		c.active = id
	}
	if value.dragging {
		if c.down {
			new_norm: f32
			if vertical {
				// Top = max, bottom = min — invert the normalized position.
				local_y := c.my - track_start
				new_norm = 1 - clamp(local_y / max(1, track_len), 0, 1)
			} else {
				local_x := c.mx - track_start
				new_norm = clamp(local_x / max(1, track_len), 0, 1)
			}
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
	thumb_color := palette(c).text
	if hover || value.dragging || focused {thumb_color = palette(c).primary_bright}
	display := format(value.value, precision)

	if vertical {
		track_x := cross_center - track_thickness / 2
		// Full track background runs the full length, filled prefix runs
		// from the thumb down to the bottom (so the fill reads as "the
		// value above zero / min").
		box(
			c,
			{track_x, track_start, track_thickness, track_len},
			palette(c).border,
			track_thickness / 2,
		)
		thumb_y := track_start + (1 - norm) * track_len
		fill_top := thumb_y
		fill_h := max(0, track_start + track_len - fill_top)
		if fill_h > 0 {
			box(
				c,
				{track_x, fill_top, track_thickness, fill_h},
				palette(c).primary,
				track_thickness / 2,
			)
		}
		box(
			c,
			{cross_center - thumb_r, thumb_y - thumb_r, thumb_r * 2, thumb_r * 2},
			thumb_color,
			thumb_r,
		)
		// Label centered below the track area.
		display_w := c.measure_text(display, 17)
		label_y := r.y + r.h - 6
		label(c, cross_center - display_w / 2, label_y, display, 17, palette(c).text)
	} else {
		track_y := cross_center - track_thickness / 2
		box(
			c,
			{track_start, track_y, track_len, track_thickness},
			palette(c).border,
			track_thickness / 2,
		)
		thumb_x := track_start + norm * track_len
		fill_w := max(0, thumb_x - track_start)
		if fill_w > 0 {
			box(
				c,
				{track_start, track_y, fill_w, track_thickness},
				palette(c).primary,
				track_thickness / 2,
			)
		}
		box(
			c,
			{thumb_x - thumb_r, cross_center - thumb_r, thumb_r * 2, thumb_r * 2},
			thumb_color,
			thumb_r,
		)
		// Label right-aligned against r.x + r.w.
		display_w := c.measure_text(display, 17)
		label(c, r.x + r.w - display_w, cross_center + 6, display, 17, palette(c).text)
	}
}
