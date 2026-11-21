package ui

// Hover-triggered tooltip. Call tooltip(c, id, hit, text) somewhere in
// your frame — once the cursor has sat inside 'hit' for 'delay' seconds,
// a floating label paints at the next-higher overlay layer above (or
// below, if there's no room) the hit rect. Pointer leaving the hit
// resets the timer; the next hover starts fresh.
//
// 'id' is a per-tooltip identity so two tooltips next to each other
// don't share a timer — use the same id you'd use for the widget being
// decorated (so hovering the widget's own button area accumulates
// toward its tooltip).
tooltip :: proc(c: ^Context, id: u64, hit: Rect, text: string, delay: f32 = 0.5) {
	assert(c.measure_text != nil, "Tooltip requires a text measurement callback")

	inside := contains(c, hit)
	if inside {
		if c.tooltip_id != id {
			c.tooltip_id = id
			c.tooltip_hover_time = 0
		} else {
			c.tooltip_hover_time += c.dt
		}
	} else if c.tooltip_id == id {
		c.tooltip_id = 0
		c.tooltip_hover_time = 0
	}

	if c.tooltip_id != id || c.tooltip_hover_time < delay {return}

	TIP_PAD_X :: f32(10)
	TIP_PAD_Y :: f32(6)
	TIP_SIZE :: f32(13)
	TIP_GAP :: f32(8)

	text_w := c.measure_text(text, TIP_SIZE)
	tip_w := text_w + 2 * TIP_PAD_X
	tip_h := TIP_SIZE + 2 * TIP_PAD_Y

	// Prefer above; fall back to below if above would clip against y=0.
	tip_x := hit.x + hit.w / 2 - tip_w / 2
	tip_y := hit.y - tip_h - TIP_GAP
	if tip_y < 0 {tip_y = hit.y + hit.h + TIP_GAP}

	// Paint on the overlay layer so the tip sits above neighboring
	// widgets, mirroring how the dropdown popup escapes its parent's
	// base-layer painting order.
	prev_layer := c.layer
	c.layer = .Overlay

	// Border + fill. 1 px frame via a slightly larger box behind the
	// fill — same idiom button/checkbox/dropdown use.
	box(c, {tip_x - 1, tip_y - 1, tip_w + 2, tip_h + 2}, palette(c).overlay_border, 7)
	box(c, {tip_x, tip_y, tip_w, tip_h}, palette(c).overlay, 6)
	label_in(c, {tip_x, tip_y, tip_w, tip_h}, text, TIP_SIZE, .Center, .Center)

	c.layer = prev_layer
}
