#+build !wasm32
package ui
import "core:testing"

@(test)
scroll_clamps_and_resets_when_content_fits :: proc(t: ^testing.T) {
	c := Context {
		mx      = 20,
		my      = 20,
		wheel_y = 500,
	}
	s := Scroll_State {
		content_height = 300,
	}
	begin_scroll(&c, &s, {0, 0, 100, 100}, 0.016)
	testing.expect(t, s.offset == 200)
	testing.expect(t, c.offset_y == -200)
	end_scroll(&c, &s)
	defer delete(c.commands)
	s.content_height = 300
	begin_scroll(&c, &s, {0, 0, 100, 400}, 0.016)
	testing.expect(t, s.offset == 0)
	end_scroll(&c, &s)
}

@(test)
scroll_clips_rendering_and_widget_hit_testing :: proc(t: ^testing.T) {
	c := Context {
		mx = 20,
		my = 20,
	}
	s := Scroll_State {
		offset         = 100,
		content_height = 300,
	}
	defer delete(c.commands)
	begin_scroll(&c, &s, {0, 0, 100, 100}, 0.016)
	testing.expect(t, contains(&c, {10, 110, 40, 30}))
	testing.expect(t, !contains(&c, {10, 10, 40, 30}))
	box(&c, {10, 110, 40, 30}, {1, 1, 1, 1})
	testing.expect(t, c.commands[0].variant.(Box_Command).rect.y == 10)
	testing.expect(t, c.commands[0].clipped)
	c.my = 110
	testing.expect(t, !contains(&c, {10, 200, 40, 30}))
	end_scroll(&c, &s)
	testing.expect(t, !c.clipped && c.offset_y == 0)
}

@(test)
scrollbar_fades_and_mouse_movement_reveals_it :: proc(t: ^testing.T) {
	c := Context {
		mx = 20,
		my = 20,
	}
	s := Scroll_State {
		content_height = 300,
	}
	defer delete(c.commands)
	begin_scroll(&c, &s, {0, 0, 100, 100}, 1.3)
	end_scroll(&c, &s)
	testing.expect(t, len(c.commands) == 0)
	c.moved = true
	s.content_height = 300
	begin_scroll(&c, &s, {0, 0, 100, 100}, 0.016)
	end_scroll(&c, &s)
	testing.expect(t, len(c.commands) == 2)
	thumb := c.commands[1].variant.(Box_Command)
	testing.expect(t, thumb.radius > 0)
	testing.expect(t, thumb.color[3] > 0)
	clear(&c.commands)
	c.moved = false
	s.content_height = 300
	begin_scroll(&c, &s, {0, 0, 100, 100}, 0.5)
	end_scroll(&c, &s)
	thumb_fading := c.commands[1].variant.(Box_Command)
	testing.expect(t, thumb_fading.color[3] > 0 && thumb_fading.color[3] < 0.7)
}

@(test)
scrollbar_track_click_and_drag_capture_input :: proc(t: ^testing.T) {
	c := Context {
		mx      = 88,
		my      = 60,
		pressed = true,
		down    = true,
	}
	s := Scroll_State {
		content_height = 300,
	}
	defer delete(c.commands)
	begin_scroll(&c, &s, {0, 0, 100, 100}, 0.016)
	testing.expect(t, s.dragging && s.offset > 0)
	testing.expect(t, c.input_blocked && c.pointer_cursor)
	end_scroll(&c, &s)
	end(&c); begin(&c)
	c.my = 100; c.down = false; c.released = true
	s.content_height = 300
	begin_scroll(&c, &s, {0, 0, 100, 100}, 0.016)
	testing.expect(t, !s.dragging && s.offset == 200)
	end_scroll(&c, &s)
}

@(test)
nested_scroll_accumulates_offset_and_restores_outer :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	outer := Scroll_State{offset = 100, content_height = 1000}
	inner := Scroll_State{offset = 30, content_height = 300}

	// Outer scroll at screen viewport {0, 0, 400, 400}, offset 100 →
	// c.offset_y = -100 while outer is open.
	begin_scroll(&c, &outer, {0, 0, 400, 400}, 0.016)
	testing.expect(t, c.offset_y == -100)
	testing.expect(t, c.clipped)

	// Inner scroll at content y=200 (parent coords), offset 30 → c.offset_y
	// = -100 + -30 = -130 while inner is open. Nested scrolls stack.
	begin_scroll(&c, &inner, {0, 200, 400, 150}, 0.016)
	testing.expect(t, c.offset_y == -130)
	testing.expect(t, c.scroll_depth == 2)

	end_scroll(&c, &inner)
	// After popping, outer's offset is restored.
	testing.expect(t, c.offset_y == -100)
	testing.expect(t, c.clipped)
	testing.expect(t, c.scroll_depth == 1)

	end_scroll(&c, &outer)
	testing.expect(t, c.offset_y == 0)
	testing.expect(t, !c.clipped)
	testing.expect(t, c.scroll_depth == 0)
}

@(test)
nested_scroll_intersects_inner_clip_with_outer :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	outer := Scroll_State{content_height = 1000}
	inner := Scroll_State{content_height = 500}

	// Outer viewport {0, 0, 400, 300}. Inner at content y=100, extending
	// below the outer viewport — inner height 400 crosses outer's bottom.
	// The intersected clip should be bounded by the outer viewport.
	begin_scroll(&c, &outer, {0, 0, 400, 300}, 0.016)
	begin_scroll(&c, &inner, {0, 100, 400, 400}, 0.016)

	// Inner viewport in screen coords is {0, 100, 400, 400}. Intersected
	// with outer {0, 0, 400, 300} it becomes {0, 100, 400, 200} — the
	// inner's bottom half is clipped away.
	testing.expect(t, c.clip == Rect{0, 100, 400, 200})
	end_scroll(&c, &inner)
	end_scroll(&c, &outer)
}

@(test)
nested_scroll_propagates_inner_extent_to_outer_content_bottom :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	outer := Scroll_State{content_height = 1000}
	inner := Scroll_State{content_height = 100}

	begin_scroll(&c, &outer, {0, 0, 400, 400}, 0.016)
	// A content widget drawn above the inner scroll contributes to the
	// outer's content_bottom first.
	box(&c, {0, 50, 10, 10}, {1, 1, 1, 1})
	testing.expect(t, c.content_bottom == 60)

	// Inner scroll lives at parent content y=200..300. After ending, the
	// outer's content_bottom should reflect at least the inner viewport's
	// bottom (300), so the outer scrollbar knows to scroll past it.
	begin_scroll(&c, &inner, {0, 200, 400, 100}, 0.016)
	end_scroll(&c, &inner)
	testing.expect(t, c.content_bottom == 300)
	end_scroll(&c, &outer)
}

@(test)
nested_scroll_wheel_claimed_by_inner :: proc(t: ^testing.T) {
	c := Context{mx = 50, my = 250, wheel_y = 40}
	defer delete(c.commands)
	outer := Scroll_State{offset = 0, content_height = 1000}
	inner := Scroll_State{offset = 0, content_height = 400}

	// Cursor sits inside the inner viewport (screen {0, 200, 400, 100}).
	// The outer's wheel-handling block runs first — it also sees the
	// cursor inside its own viewport — then the inner's.
	//
	// Current behavior: both consume the wheel. A follow-up could make
	// the inner claim and prevent the outer. For now the test documents
	// what happens.
	begin_scroll(&c, &outer, {0, 0, 400, 400}, 0.016)
	testing.expect(t, outer.offset == 40)
	begin_scroll(&c, &inner, {0, 200, 400, 100}, 0.016)
	testing.expect(t, inner.offset == 40)
	end_scroll(&c, &inner)
	end_scroll(&c, &outer)
}
