package ui

// Transient corner notification — "Saved", "Could not connect", a
// three-second confirmation that lingers then fades. A Toast_Stack
// is the caller's queue: toast_push appends a message, the toasts()
// draw call decrements each item's remaining time by c.dt, removes
// expired ones, and paints the survivors stacked at the bottom-
// right of c.viewport on the overlay layer.
//
// Text is COPIED into fixed storage so a caller can toast_push a
// tprintf string without worrying about the temp allocator
// recycling it mid-fade.
//
// Each toast has a × hit area that force-expires it. No per-toast
// id is needed from the caller; ids are derived from the stack's
// own slot indices via sub_id.

TOAST_MAX_TEXT :: 120
TOAST_STACK_SIZE :: 5
TOAST_DURATION :: f32(3.0)
TOAST_FADE :: f32(0.3)
TOAST_PAD_X :: f32(14)
TOAST_PAD_Y :: f32(10)
TOAST_GAP :: f32(8)
TOAST_MARGIN :: f32(40)
TOAST_LABEL_GAP :: f32(6)
TOAST_SIZE :: f32(14)

Toast :: struct {
	text:      [TOAST_MAX_TEXT]u8,
	text_len:  int,
	remaining: f32,
}

Toast_Stack :: struct {
	items: [TOAST_STACK_SIZE]Toast,
	count: int,
}

// Queues a toast with 'text' at the stack's end. Text beyond
// TOAST_MAX_TEXT is dropped silently (toasts are one-line chrome,
// not an essay viewer). When the stack is full the oldest entry is
// shifted out so a fresh notification still lands.
toast_push :: proc(stack: ^Toast_Stack, text: string) {
	if stack.count >= TOAST_STACK_SIZE {
		for i in 0 ..< TOAST_STACK_SIZE - 1 {stack.items[i] = stack.items[i + 1]}
		stack.count = TOAST_STACK_SIZE - 1
	}
	t := &stack.items[stack.count]
	n := min(len(text), TOAST_MAX_TEXT)
	copy(t.text[:n], transmute([]u8)text[:n])
	t.text_len = n
	t.remaining = TOAST_DURATION
	stack.count += 1
}

// Decrements each item's remaining time, removes those that have
// expired, and paints the rest stacked at the bottom-right of
// c.viewport on the overlay layer. The newest toast sits at the
// bottom of the stack where a glance naturally lands.
toasts :: proc(c: ^Context, base_id: u64, stack: ^Toast_Stack) {
	assert(c.measure_text != nil, "toasts requires a text measurement callback")

	// Age every item and compact the array in place, keeping the
	// relative order so the newest (highest original index) still
	// lands at the bottom.
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

	prev_layer := c.layer
	c.layer = .Overlay
	h := TOAST_SIZE + 2 * TOAST_PAD_Y
	y := vp.y + vp.h - TOAST_MARGIN
	// Paint newest last (and thus at the bottom): walk indices high-
	// to-low, pushing y up by each toast's height + TOAST_GAP.
	for i := stack.count - 1; i >= 0; i -= 1 {
		t := &stack.items[i]
		text := string(t.text[:t.text_len])
		text_w := c.measure_text(text, TOAST_SIZE)
		w := text_w + 2 * TOAST_PAD_X + TOAST_LABEL_GAP + h
		x := vp.x + vp.w - TOAST_MARGIN - w
		y -= h
		toast_draw(c, sub_id(base_id, u64(i)), Rect{x, y, w, h}, text, t)
		y -= TOAST_GAP
	}
	c.layer = prev_layer
}

@(private)
toast_draw :: proc(c: ^Context, id: u64, r: Rect, text: string, t: ^Toast) {
	// Linear fade over the last TOAST_FADE seconds of life. Every
	// colored piece (border, fill, text, ×) multiplies its alpha by
	// the same factor so the toast dims uniformly rather than
	// decomposing into its parts.
	alpha := min(f32(1), t.remaining / TOAST_FADE)
	pal := palette(c)
	border := pal.overlay_border; border.a *= alpha
	fill := pal.overlay;          fill.a *= alpha
	text_color := pal.text;       text_color.a *= alpha

	box(c, r, border, 8)
	box(c, {r.x + 1, r.y + 1, r.w - 2, r.h - 2}, fill, 7)

	// × hit rect: a square the toast's height, anchored right.
	hit := Rect{r.x + r.w - r.h, r.y, r.h, r.h}
	hover, released := pressable(c, id, hit)
	if released {t.remaining = 0}

	label_in(
		c,
		Rect{r.x + TOAST_PAD_X, r.y, max(0, hit.x - r.x - TOAST_PAD_X - TOAST_LABEL_GAP), r.h},
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
