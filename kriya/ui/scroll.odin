package ui

Scroll_State :: struct {
	offset:         f32,
	idle:           f32,
	dragging:       bool,
	grab_y:         f32,
	content_height: f32,
}

// Scroll viewport. Supports nesting: an inner begin_scroll opening
// inside an outer one pushes the outer's clip / offset / content_bottom /
// input_blocked onto Context.scroll_stack, intersects the new viewport
// with the outer clip, and ADDS the new scroll offset onto the outer's,
// so widgets inside still draw at logical content y values. end_scroll
// pops and restores; the inner scrollbar renders in screen coords under
// the outer clip so it clips away cleanly when the inner is scrolled
// out of view.
//
// 'viewport' is in the CURRENT coordinate space — screen coords at the
// top level, parent-content coords inside another scroll view.
//
// content_height is measured over the frame that drew it (end_scroll
// writes it back from c.content_bottom); the first frame renders at 0
// so scrolling becomes available from the second frame onward.
begin_scroll :: proc(c: ^Context, s: ^Scroll_State, viewport: Rect, dt: f32) {
	assert(c.scroll_depth < MAX_SCROLL_DEPTH, "Scroll nesting too deep")

	maximum := max(0, s.content_height - viewport.h)
	s.offset = clamp(s.offset, 0, maximum)
	s.idle += dt

	// Viewport in screen coordinates: shift by the current offset_y so a
	// nested scroll's screen clip accounts for the outer scroll's
	// position.
	screen_viewport := Rect{viewport.x, viewport.y + c.offset_y, viewport.w, viewport.h}

	// Mouse interactions use screen coords. The outer clip (if any) also
	// has to cover the cursor — a nested scroll whose viewport is partly
	// hidden behind an outer scroll shouldn't accept wheel events in the
	// hidden region.
	inside := point_in_rect(c.mx, c.my, screen_viewport)
	if c.clipped && !point_in_rect(c.mx, c.my, c.clip) {inside = false}

	// Overlay claim (e.g. dropdown popup) wins over any scroll view.
	claimed := c.scroll_claim_id != 0 && point_in_rect(c.mx, c.my, c.scroll_claim)
	if inside && !claimed && (c.moved || c.wheel_y != 0 || c.pressed) {s.idle = 0}
	if inside && !claimed {s.offset = clamp(s.offset + c.wheel_y, 0, maximum)}

	if maximum > 0 && screen_viewport.h > 28 && screen_viewport.w > 20 {
		track := Rect {
			screen_viewport.x + screen_viewport.w - 20,
			screen_viewport.y + 14,
			16,
			screen_viewport.h - 28,
		}
		thumb_h := min(track.h, max(32, track.h * screen_viewport.h / s.content_height))
		travel := track.h - thumb_h
		thumb_y := track.y + travel * s.offset / maximum
		over_track := point_in_rect(c.mx, c.my, track)
		if c.clipped && !point_in_rect(c.mx, c.my, c.clip) {over_track = false}
		if over_track && c.pressed {
			s.dragging = true
			c.active = 0
			if c.my >= thumb_y &&
			   c.my < thumb_y + thumb_h {s.grab_y = c.my - thumb_y} else {s.grab_y = thumb_h / 2}
		}
		if s.dragging {
			if travel > 0 {s.offset = clamp(
					(c.my - track.y - s.grab_y) / travel * maximum,
					0,
					maximum,
				)}
			s.idle = 0
			if !c.down {s.dragging = false}
		}
		if over_track || s.dragging {c.pointer_cursor = true; c.input_blocked = true; s.idle = 0}
	} else {s.dragging = false}

	// Push outer state and the current scroll's screen viewport.
	c.scroll_stack[c.scroll_depth] = Scroll_Frame {
		outer_clip           = c.clip,
		outer_clipped        = c.clipped,
		outer_offset_y       = c.offset_y,
		outer_content_bottom = c.content_bottom,
		outer_input_blocked  = c.input_blocked,
		screen_viewport      = screen_viewport,
	}
	c.scroll_depth += 1

	// Intersect clips so a nested viewport can't paint outside its parent.
	new_clip := screen_viewport
	if c.clipped {new_clip = intersect(screen_viewport, c.clip)}
	c.clip = new_clip
	c.clipped = true
	// ADD to outer offset rather than replace, so content inside a
	// nested scroll translates through both scrolls' offsets.
	c.offset_y += -s.offset
	// content_bottom is measured in current content coords. Seed with
	// the viewport's top so widgets drawing at that y and below extend
	// the measurement cleanly.
	c.content_bottom = viewport.y
}

end_scroll :: proc(c: ^Context, s: ^Scroll_State) {
	assert(c.scroll_depth > 0, "end_scroll without a matching begin_scroll")
	c.scroll_depth -= 1
	f := c.scroll_stack[c.scroll_depth]

	// Original viewport in current (parent) content coords: the screen
	// viewport unshifted by the outer offset.
	viewport := Rect {
		f.screen_viewport.x,
		f.screen_viewport.y - f.outer_offset_y,
		f.screen_viewport.w,
		f.screen_viewport.h,
	}

	// Measure content height — only update when something actually drew
	// in this region so a transient empty frame doesn't reset the state.
	measured := max(0, c.content_bottom - viewport.y)
	if measured > 0 {s.content_height = measured}
	content_height := s.content_height

	// Restore outer state. content_bottom bubbles up so an outer scroll's
	// own measurement includes this viewport's extent.
	c.clip = f.outer_clip
	c.clipped = f.outer_clipped
	c.offset_y = f.outer_offset_y
	c.input_blocked = f.outer_input_blocked
	c.content_bottom = max(f.outer_content_bottom, viewport.y + viewport.h)

	if content_height <= f.screen_viewport.h ||
	   f.screen_viewport.h <= 28 ||
	   f.screen_viewport.w <= 20 {return}

	// Hold briefly, then fade smoothly to transparent over 0.5 seconds.
	t := clamp((s.idle - 0.25) / 0.5, 0, 1)
	alpha := 1 - t * t * (3 - 2 * t)
	if alpha <= 0 {return}

	// Scrollbar overlay. Screen coords, so zero offset_y for the two box
	// calls; the outer clip stays active so an inner scrollbar clips
	// away when the outer scrolls it out of view.
	saved_offset := c.offset_y
	c.offset_y = 0
	track := Rect {
		f.screen_viewport.x + f.screen_viewport.w - 20,
		f.screen_viewport.y + 14,
		16,
		f.screen_viewport.h - 28,
	}
	thumb_h := min(track.h, max(32, track.h * f.screen_viewport.h / content_height))
	thumb_y := track.y + (track.h - thumb_h) * s.offset / (content_height - f.screen_viewport.h)
	hover := point_in_rect(c.mx, c.my, track) || s.dragging
	width: f32 = hover ? 7 : 5
	tr := palette(c).scroll_track
	th := palette(c).scroll_thumb
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
	c.offset_y = saved_offset
}
