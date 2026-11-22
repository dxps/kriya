package ui

// Transient corner notification — "Saved", "Could not connect", a
// three-second confirmation that lingers then fades. A Toast_Stack
// is the caller's queue: toast_push appends a message, the toasts()
// draw call decrements each item's remaining time by c.dt, removes
// expired ones, and paints the survivors stacked at the viewport
// corner chosen via set_toast_corner (default: Bottom_Right) on the
// overlay layer, with the newest toast sitting closest to the
// anchor edge where a glance naturally lands.
//
// Text is COPIED into fixed storage so a caller can toast_push a
// tprintf string without worrying about the temp allocator
// recycling it mid-fade.
//
// Each toast has a × hit area that force-expires it. No per-toast
// id is needed from the caller; ids are derived from the stack's
// own slot indices via sub_id.
//
// A Toast_Kind picks one of three drawn icons (ring-with-dot,
// triangle, ×) rendered to the left of the text. All three share
// the text_subtle token — distinguishing by SHAPE rather than
// introducing a status-color palette keeps the library's "no
// separate status palette" stance (set first by badge).

TOAST_MAX_TEXT :: 120
TOAST_STACK_SIZE :: 5
TOAST_DURATION :: f32(3.0)
TOAST_FADE :: f32(0.3)
TOAST_PAD_X :: f32(14)
TOAST_PAD_Y :: f32(10)
TOAST_GAP :: f32(8)
TOAST_MARGIN :: f32(40)
TOAST_LABEL_GAP :: f32(6)
TOAST_ICON_GAP :: f32(10)
TOAST_ICON :: f32(14)
TOAST_SIZE :: f32(14)

Toast_Kind :: enum u8 {
	Info,
	Warn,
	Error,
}

Toast_Corner :: enum u8 {
	Top_Right,
	Top_Left,
	Bottom_Right,
	Bottom_Left,
}

Toast :: struct {
	text:      [TOAST_MAX_TEXT]u8,
	text_len:  int,
	remaining: f32,
	kind:      Toast_Kind,
}

Toast_Stack :: struct {
	items: [TOAST_STACK_SIZE]Toast,
	count: int,
}

// Global default corner; nil resolves to Top_Right, which puts a
// notification where most desktop app chrome does and keeps the
// bottom of the viewport clear for scroll content. Setting it
// re-anchors every stack drawn afterwards — no per-call plumbing.
set_toast_corner :: proc(c: ^Context, corner: Toast_Corner) {c.toast_corner = corner}

resolve_toast_corner :: proc(c: ^Context) -> Toast_Corner {
	if v, ok := c.toast_corner.?; ok {return v}
	return .Top_Right
}

// Global default duration in seconds; nil resolves to TOAST_DURATION.
// Negative values clamp to 0 so a mis-call can't produce immortal
// toasts.
set_toast_duration :: proc(c: ^Context, seconds: f32) {c.toast_duration = max(0, seconds)}

resolve_toast_duration :: proc(c: ^Context, duration: Maybe(f32) = nil) -> f32 {
	if v, ok := duration.?; ok {return max(0, v)}
	if v, ok := c.toast_duration.?; ok {return v}
	return TOAST_DURATION
}

// Queues a toast with 'text' at the stack's end. Text beyond
// TOAST_MAX_TEXT is dropped silently (toasts are one-line chrome,
// not an essay viewer). When the stack is full the oldest entry is
// shifted out so a fresh notification still lands. duration = nil
// uses the context default (set via set_toast_duration).
toast_push :: proc(
	c: ^Context,
	stack: ^Toast_Stack,
	text: string,
	kind: Toast_Kind = .Info,
	duration: Maybe(f32) = nil,
) {
	if stack.count >= TOAST_STACK_SIZE {
		for i in 0 ..< TOAST_STACK_SIZE - 1 {stack.items[i] = stack.items[i + 1]}
		stack.count = TOAST_STACK_SIZE - 1
	}
	t := &stack.items[stack.count]
	n := min(len(text), TOAST_MAX_TEXT)
	copy(t.text[:n], transmute([]u8)text[:n])
	t.text_len = n
	t.remaining = resolve_toast_duration(c, duration)
	t.kind = kind
	stack.count += 1
}

// Decrements each item's remaining time, removes those that have
// expired, and paints the rest stacked at the chosen viewport
// corner on the overlay layer. The newest toast sits closest to
// the anchor corner; older ones push further into the viewport.
toasts :: proc(c: ^Context, base_id: u64, stack: ^Toast_Stack) {
	assert(c.measure_text != nil, "toasts requires a text measurement callback")

	// Age every item and compact the array in place, keeping the
	// relative order so the newest (highest original index) still
	// lands closest to the anchor.
	write := 0
	for i in 0 ..< stack.count {
		stack.items[i].remaining -= c.dt
		if stack.items[i].remaining <= 0 {continue}
		if write != i {stack.items[write] = stack.items[i]}
		write += 1
	}
	stack.count = write
	if stack.count == 0 {return}

	// Modal uses the same viewport fallback when the host hasn't
	// set one; toasts default to the same inside-a-browser-tab
	// footprint so a smoke test without a frame still draws.
	vp := c.viewport
	if vp.w == 0 && vp.h == 0 {vp = Rect{0, 0, 1024, 720}}

	corner := resolve_toast_corner(c)
	is_top := corner == .Top_Left || corner == .Top_Right
	is_right := corner == .Bottom_Right || corner == .Top_Right

	prev_layer := c.layer
	c.layer = .Overlay
	h := TOAST_SIZE + 2 * TOAST_PAD_Y
	y := is_top ? vp.y + TOAST_MARGIN : vp.y + vp.h - TOAST_MARGIN
	// Walk high-index → low-index so the newest-pushed toast lands
	// first (closest to the anchor). The y cursor advances away
	// from the anchor as older toasts stack after it.
	for i := stack.count - 1; i >= 0; i -= 1 {
		t := &stack.items[i]
		text := string(t.text[:t.text_len])
		text_w := c.measure_text(text, TOAST_SIZE)
		w := TOAST_PAD_X + TOAST_ICON + TOAST_ICON_GAP + text_w + TOAST_LABEL_GAP + h
		x := is_right ? vp.x + vp.w - TOAST_MARGIN - w : vp.x + TOAST_MARGIN
		top_y: f32
		if is_top {
			top_y = y
			y += h + TOAST_GAP
		} else {
			y -= h
			top_y = y
			y -= TOAST_GAP
		}
		toast_draw(c, sub_id(base_id, u64(i)), Rect{x, top_y, w, h}, text, t)
	}
	c.layer = prev_layer
}

@(private)
toast_draw :: proc(c: ^Context, id: u64, r: Rect, text: string, t: ^Toast) {
	// Linear fade over the last TOAST_FADE seconds of life. Every
	// coloured piece multiplies its alpha by the same factor so the
	// toast dims uniformly rather than decomposing into its parts.
	alpha := min(f32(1), t.remaining / TOAST_FADE)
	pal := palette(c)
	border := pal.overlay_border; border.a *= alpha
	fill := pal.overlay;          fill.a *= alpha
	text_color := pal.text;       text_color.a *= alpha
	icon_color := pal.text_subtle; icon_color.a *= alpha
	bg_color := pal.overlay;      bg_color.a *= alpha

	box(c, r, border, 8)
	box(c, {r.x + 1, r.y + 1, r.w - 2, r.h - 2}, fill, 7)

	// Icon on the left, centered vertically in the pill.
	icon_cx := r.x + TOAST_PAD_X + TOAST_ICON / 2
	icon_cy := r.y + r.h / 2
	draw_toast_icon(c, icon_cx, icon_cy, t.kind, icon_color, bg_color)

	// × hit rect: a square the toast's height, anchored right.
	hit := Rect{r.x + r.w - r.h, r.y, r.h, r.h}
	hover, released := pressable(c, id, hit)
	if released {t.remaining = 0}

	label_x := r.x + TOAST_PAD_X + TOAST_ICON + TOAST_ICON_GAP
	label_in(
		c,
		Rect{label_x, r.y, max(0, hit.x - label_x - TOAST_LABEL_GAP), r.h},
		text,
		TOAST_SIZE,
		.Start,
		.Center,
		color = text_color,
	)

	cx := hit.x + hit.w / 2
	cy := hit.y + hit.h / 2
	arm := f32(4)
	x_color := hover ? pal.text : pal.text_subtle
	x_color.a *= alpha
	line(c, cx - arm, cy - arm, cx + arm, cy + arm, 1.5, x_color)
	line(c, cx - arm, cy + arm, cx + arm, cy - arm, 1.5, x_color)
}

// Three drawn glyphs that distinguish toast kinds by SHAPE, not
// colour — matching the library's "no separate status palette"
// stance. A caller wanting a different icon for a one-off toast
// uses a plain .Info and composes their own graphic on top.
@(private)
draw_toast_icon :: proc(c: ^Context, cx, cy: f32, kind: Toast_Kind, color, bg: Color) {
	switch kind {
	case .Info:
		// Filled ring with a centre dot — reads as ⓘ without the
		// typography complication of drawing a real "i".
		box(c, {cx - 7, cy - 7, 14, 14}, color, 7)
		box(c, {cx - 5, cy - 5, 10, 10}, bg, 5)
		box(c, {cx - 1.5, cy - 1.5, 3, 3}, color, 1.5)
	case .Warn:
		// Upward-pointing filled triangle, the same filled-triangle
		// idiom accordion / sidebar / dropdown already use.
		triangle(c, cx - 7, cy + 6, cx + 7, cy + 6, cx, cy - 7, color)
	case .Error:
		// Bold × made of two overlapping diagonal strokes — a bigger
		// sibling of the dismiss glyph on the right of every toast.
		line(c, cx - 6, cy - 6, cx + 6, cy + 6, 2, color)
		line(c, cx - 6, cy + 6, cx + 6, cy - 6, 2, color)
	}
}
