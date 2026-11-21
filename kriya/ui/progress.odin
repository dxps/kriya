package ui

import "core:math"

// Horizontal progress bar. 'value' nil means indeterminate: a 35%-wide
// chunk slides from off-left to off-right over 1.5 seconds and repeats.
// A value in [0, 1] draws a left-anchored fill of that fraction; outside
// that range is clamped. Widgets like upload/download indicators pair
// this with a caption and a numeric percent in their own layout slot.
//
// The inner geometry insets by 1 px on all sides so the fill never
// paints over the outer border — the "track" below the fill is the
// surface_raised band between the 1 px frame and the fill.
progress_bar :: proc(c: ^Context, r: Rect, value: Maybe(f32) = nil, radius: Maybe(f32) = nil) {
	corner_radius := resolve_corner_radius(c, radius)
	inner_r := Rect{r.x + 1, r.y + 1, max(0, r.w - 2), max(0, r.h - 2)}
	inner_radius := max(0, corner_radius - 1)

	box(c, r, palette(c).border, corner_radius)
	box(c, inner_r, palette(c).surface_raised, inner_radius)
	if inner_r.w <= 0 || inner_r.h <= 0 {return}

	if v, ok := value.?; ok {
		frac := clamp(v, 0, 1)
		fill_w := inner_r.w * frac
		if fill_w > 0 {
			box(c, {inner_r.x, inner_r.y, fill_w, inner_r.h}, palette(c).primary, inner_radius)
		}
		return
	}

	// Indeterminate. Chunk width stays proportional to the bar so the
	// animation's speed feels consistent regardless of the bar's size.
	CHUNK_FRAC :: f32(0.35)
	CYCLE :: f32(1.5)
	chunk_w := inner_r.w * CHUNK_FRAC
	t := f32(math.mod(c.now, f64(CYCLE)) / f64(CYCLE))
	travel := inner_r.w + chunk_w
	chunk_x := inner_r.x - chunk_w + t * travel
	left := max(chunk_x, inner_r.x)
	right := min(chunk_x + chunk_w, inner_r.x + inner_r.w)
	if right > left {
		box(c, {left, inner_r.y, right - left, inner_r.h}, palette(c).primary, inner_radius)
	}
}

// Rotating dot spinner inside r. Eight dots arranged on a circle with
// opacity trailing behind a head that completes a full rotation per
// second — the classic "loading" ring. No state and no interaction:
// animation derives from c.now, so it runs whenever the widget is
// drawn. Sizing follows min(r.w, r.h) so a square bounding rect gives a
// centered spinner that fills its slot.
spinner :: proc(c: ^Context, r: Rect, color: Maybe(Color) = nil) {
	DOT_COUNT :: 8
	base := color.? or_else palette(c).primary

	d := min(r.w, r.h)
	if d <= 0 {return}
	center_x := r.x + r.w / 2
	center_y := r.y + r.h / 2
	ring_radius := d / 2 * 0.72
	dot_size := d * 0.18
	phase := f32(math.mod(c.now, 1.0))

	for i in 0 ..< DOT_COUNT {
		// Dot's static position on the ring.
		angle := f32(i) * (2 * math.PI / f32(DOT_COUNT)) - math.PI / 2
		dx := center_x + math.cos(angle) * ring_radius - dot_size / 2
		dy := center_y + math.sin(angle) * ring_radius - dot_size / 2

		// Trail fade: the "head" at phase t has alpha 1; other dots
		// taper off with distance from the head along the ring, with
		// quadratic easing for a crisp leading edge.
		t := f32(i) / f32(DOT_COUNT) - phase
		t = t - math.floor(t)
		alpha := (1 - t) * (1 - t)

		col := base
		col[3] *= alpha
		box(c, {dx, dy, dot_size, dot_size}, col, dot_size / 2)
	}
}
