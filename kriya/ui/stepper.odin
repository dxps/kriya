package ui

import "core:fmt"

// Numeric nudger: [−] value [+] in one bordered pill. The two end
// regions are pressable sub-areas that nudge the caller-owned
// 'value' by 'step', clamped to [min_val, max_val]. Hovering a
// button side lights its background, pressing shows the item-
// selected tint so the control reads as a single composite widget
// rather than two detached buttons.
//
// Focus-traversable like slider: Tab reaches the whole stepper,
// Left / Right arrows nudge by one step when focused. A focus ring
// paints around the whole pill, not around either button.
//
// Returns true on the frame value changed, so a caller can run a
// single downstream effect (persist, re-fetch) per press without
// diffing against a cached previous value.
stepper :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	value: ^int,
	min_val: int = 0,
	max_val: int = 100,
	step: int = 1,
	disabled := false,
	radius: Maybe(f32) = nil,
) -> bool {
	assert(c.measure_text != nil, "stepper requires a text measurement callback")
	corner_radius := resolve_corner_radius(c, radius)
	pal := palette(c)

	// Pre-clamp in case the caller handed us a value outside the
	// range or changed min/max between frames. A caller passing
	// max < min collapses the range to a single point at min.
	hi := max(max_val, min_val)
	value^ = clamp(value^, min_val, hi)
	old := value^

	// Focus ring goes BEFORE the pill so the pill masks its
	// interior — the comment on focus_ring spells out the order.
	// 'focused' is computed below (inside the !disabled branch);
	// we do a cheap peek here to decide whether to paint the ring.
	if !disabled && c.focused == id {focus_ring(c, r, corner_radius)}

	// Pill: 1px border + inset surface_raised, same recipe as
	// input / dropdown / badge(subtle).
	box(c, r, pal.border, corner_radius)
	inner := Rect{r.x + 1, r.y + 1, max(0, r.w - 2), max(0, r.h - 2)}
	box(c, inner, pal.surface_raised, max(0, corner_radius - 1))

	// Button regions take square ends; the middle holds the value
	// label. Narrower rects would crowd the glyph strokes.
	btn_w := min(r.h, r.w / 3)
	minus_rect := Rect{r.x, r.y, btn_w, r.h}
	plus_rect := Rect{r.x + r.w - btn_w, r.y, btn_w, r.h}

	focused: bool
	if !disabled {
		focused = focusable(c, id, r)

		minus_id := sub_id(id, 0)
		m_hover, m_clicked := pressable(c, minus_id, minus_rect)
		if m_hover {
			bg := pal.item_hover
			if c.active == minus_id && c.down {bg = pal.item_selected}
			box(
				c,
				{minus_rect.x + 1, minus_rect.y + 1, minus_rect.w - 1, minus_rect.h - 2},
				bg,
				max(0, corner_radius - 1),
			)
		}
		if m_clicked {value^ = clamp(value^ - step, min_val, hi)}

		plus_id := sub_id(id, 1)
		p_hover, p_clicked := pressable(c, plus_id, plus_rect)
		if p_hover {
			bg := pal.item_hover
			if c.active == plus_id && c.down {bg = pal.item_selected}
			box(
				c,
				{plus_rect.x, plus_rect.y + 1, plus_rect.w - 1, plus_rect.h - 2},
				bg,
				max(0, corner_radius - 1),
			)
		}
		if p_clicked {value^ = clamp(value^ + step, min_val, hi)}

		// Keyboard nudge when the stepper itself has focus — same
		// left / right convention a horizontal slider uses.
		if focused && step > 0 {
			if c.nav_left {value^ = clamp(value^ - step, min_val, hi)}
			if c.nav_right {value^ = clamp(value^ + step, min_val, hi)}
		}
	}

	// Vertical hairlines framing the value area, so the three
	// sections read as one segmented pill. 1 px, inset by 1 on top
	// and bottom to leave the outer border visually unbroken.
	box(c, {r.x + btn_w, r.y + 1, 1, max(0, r.h - 2)}, pal.border)
	box(c, {r.x + r.w - btn_w - 1, r.y + 1, 1, max(0, r.h - 2)}, pal.border)

	// − and + drawn as crisp line strokes rather than ASCII text —
	// the atlas's hyphen-minus (0x2D) reads short and off-centre
	// next to the plus, and the real minus sign (0x2212) is above
	// the atlas's glyph range.
	stroke_color := disabled ? pal.disabled : pal.text
	m_cx := minus_rect.x + minus_rect.w / 2
	m_cy := minus_rect.y + minus_rect.h / 2
	line(c, m_cx - 6, m_cy, m_cx + 6, m_cy, 2, stroke_color)
	p_cx := plus_rect.x + plus_rect.w / 2
	p_cy := plus_rect.y + plus_rect.h / 2
	line(c, p_cx - 6, p_cy, p_cx + 6, p_cy, 2, stroke_color)
	line(c, p_cx, p_cy - 6, p_cx, p_cy + 6, 2, stroke_color)

	// Value label, centered in the middle section.
	text := fmt.tprintf("%d", value^)
	value_color := disabled ? pal.disabled : pal.text
	label_in(
		c,
		Rect{r.x + btn_w, r.y, max(0, r.w - 2 * btn_w), r.h},
		text,
		18,
		.Center,
		.Center,
		color = value_color,
	)

	_ = focused
	return value^ != old
}
