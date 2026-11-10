package ui

Scroll_State :: struct {
	offset:         f32,
	idle:           f32,
	dragging:       bool,
	grab_y:         f32,
	content_height: f32,
}

// One scroll viewport at a time. Widgets declared between begin/end use content
// coordinates; drawing and hit testing are translated and clipped together.
// content_height is the measurement from the previous frame (end_scroll writes
// it back from c.content_bottom); first-frame value is 0, so scrolling becomes
// available from the second frame onward.
begin_scroll :: proc(c: ^Context, s: ^Scroll_State, viewport: Rect, dt: f32) {
	assert(!c.clipped, "Nested scroll views are not supported yet")
	maximum := max(0, s.content_height - viewport.h)
	s.offset = clamp(s.offset, 0, maximum)
	s.idle += dt
	inside := point_in_rect(c.mx, c.my, viewport)
	if inside && (c.moved || c.wheel_y != 0 || c.pressed) {s.idle = 0}
	if inside {s.offset = clamp(s.offset + c.wheel_y, 0, maximum)}
	if maximum > 0 && viewport.h > 28 && viewport.w > 20 {
		track := Rect{viewport.x + viewport.w - 20, viewport.y + 14, 16, viewport.h - 28}
		thumb_h := min(track.h, max(32, track.h * viewport.h / s.content_height))
		travel := track.h - thumb_h
		thumb_y := track.y + travel * s.offset / maximum
		over_track := point_in_rect(c.mx, c.my, track)
		if over_track && c.pressed {
			s.dragging = true
			c.active = 0
			if c.my >= thumb_y &&
			   c.my < thumb_y + thumb_h {s.grab_y = c.my - thumb_y} else {s.grab_y = thumb_h / 2}
		}
		if s.dragging {
			if travel >
			   0 {s.offset = clamp((c.my - track.y - s.grab_y) / travel * maximum, 0, maximum)}
			s.idle = 0
			if !c.down {s.dragging = false}
		}
		if over_track || s.dragging {c.pointer_cursor = true; c.input_blocked = true; s.idle = 0}
	} else {s.dragging = false}
	c.clip = viewport; c.clipped = true; c.offset_y = -s.offset
	c.content_bottom = viewport.y
}

end_scroll :: proc(c: ^Context, s: ^Scroll_State) {
	viewport := c.clip
	// Only refresh the remembered height when something actually drew in this
	// region. A frame that emits nothing keeps the previous measurement so
	// scroll state survives transient empty frames.
	measured := max(0, c.content_bottom - viewport.y)
	if measured > 0 {s.content_height = measured}
	content_height := s.content_height
	c.offset_y = 0; c.clipped = false; c.input_blocked = false
	if content_height <= viewport.h || viewport.h <= 28 || viewport.w <= 20 {return}
	// Hold briefly, then fade smoothly to transparent over 0.5 seconds.
	t := clamp((s.idle - 0.25) / 0.5, 0, 1)
	alpha := 1 - t * t * (3 - 2 * t)
	if alpha <= 0 {return}
	track := Rect{viewport.x + viewport.w - 20, viewport.y + 14, 16, viewport.h - 28}
	thumb_h := min(track.h, max(32, track.h * viewport.h / content_height))
	thumb_y := track.y + (track.h - thumb_h) * s.offset / (content_height - viewport.h)
	hover := point_in_rect(c.mx, c.my, track) || s.dragging
	width: f32 = hover ? 7 : 5
	tr := DEFAULT_PALETTE.scroll_track
	th := DEFAULT_PALETTE.scroll_thumb
	box(
		c,
		{track.x + 8 - width / 2, track.y, width, track.h},
		{tr[0], tr[1], tr[2], 0.16 * alpha},
		width / 2,
	)
	box(
		c,
		{track.x + 8 - width / 2, thumb_y, width, thumb_h},
		{th[0], th[1], th[2], (hover ? 0.95 : 0.7) * alpha},
		width / 2,
	)
}
