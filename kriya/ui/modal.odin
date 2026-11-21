package ui

// Monolithic titled dialog with a wrapped body paragraph and 1–3 action
// buttons. Open is toggled via value.open; modal draws when it's true.
// Returns the index of the action clicked this frame, or -1 when nothing
// (or Esc, which also sets value.open = false). Clicking any action
// closes the dialog — the caller usually matches on the returned index
// to run the chosen command.
//
// Sizing: width is caller-supplied (400 default). Height is derived
// from the title, the body wrapped to width - 2*MODAL_PAD_X, and the
// button strip. The dialog centers inside c.viewport.
//
// Known limitation: this modal does not block input to main-view widgets
// drawn before it in the same frame. Backdrop darkens visually but does
// not stop clicks from reaching the view below. A follow-up PR can
// propagate last-frame modal state via Context at frame begin to
// pre-block input.

Modal :: struct {
	open: bool,
}

MODAL_PAD_X :: f32(24)
MODAL_PAD_Y :: f32(24)
MODAL_TITLE_SIZE :: f32(20)
MODAL_TITLE_H :: f32(28)
MODAL_TITLE_BODY_GAP :: f32(14)
MODAL_BODY_ACTIONS_GAP :: f32(24)
MODAL_BUTTON_H :: f32(46)
MODAL_BUTTON_GAP :: f32(12)
MODAL_BUTTON_PAD_X :: f32(20)
MODAL_BUTTON_W_MIN :: f32(96)
MODAL_BACKDROP_ALPHA :: f32(0.5)

modal :: proc(
	c: ^Context,
	id: u64,
	title: string,
	body: string,
	actions: []string,
	value: ^Modal,
	width: f32 = 400,
	radius: Maybe(f32) = nil,
) -> int {
	if !value.open {return -1}
	assert(c.measure_text != nil, "Modal requires a text measurement callback")
	assert(len(actions) > 0, "Modal needs at least one action")

	corner_radius := resolve_corner_radius(c, radius)

	// Body wrap on the caller-supplied width to compute the final
	// dialog height.
	body_w := width - 2 * MODAL_PAD_X
	body_size := f32(17)
	body_lines := wrap_text(c, body, body_w, body_size)
	body_h := f32(len(body_lines)) * line_height(body_size)

	height :=
		MODAL_PAD_Y +
		MODAL_TITLE_H +
		MODAL_TITLE_BODY_GAP +
		body_h +
		MODAL_BODY_ACTIONS_GAP +
		MODAL_BUTTON_H +
		MODAL_PAD_Y

	viewport := c.viewport
	if viewport.w <= 0 || viewport.h <= 0 {viewport = Rect{0, 0, 1024, 720}}

	dialog := Rect {
		viewport.x + (viewport.w - width) / 2,
		viewport.y + (viewport.h - height) / 2,
		width,
		height,
	}

	// Esc closes without picking an action.
	if c.cancel {
		value.open = false
		return -1
	}

	// Paint on the overlay layer so the dialog sits above everything
	// the main view drew on Base.
	prev_layer := c.layer
	c.layer = .Overlay

	// Backdrop fills the viewport. Half-opaque black reads as a
	// darkening pass regardless of theme.
	box(c, viewport, Color{0, 0, 0, MODAL_BACKDROP_ALPHA}, 0)

	// Dialog frame: 1 px border via a slightly-larger box behind the fill.
	box(
		c,
		{dialog.x - 1, dialog.y - 1, dialog.w + 2, dialog.h + 2},
		palette(c).overlay_border,
		corner_radius + 1,
	)
	box(c, dialog, palette(c).overlay, corner_radius)

	// Layout: title at top, body below, buttons right-aligned at bottom.
	y := dialog.y + MODAL_PAD_Y
	title_rect := Rect{dialog.x + MODAL_PAD_X, y, body_w, MODAL_TITLE_H}
	label_in(c, title_rect, title, MODAL_TITLE_SIZE, .Start, .Center)
	y += MODAL_TITLE_H + MODAL_TITLE_BODY_GAP

	body_rect := Rect{dialog.x + MODAL_PAD_X, y, body_w, body_h}
	label_wrap(c, body_rect, body, body_size)
	y += body_h + MODAL_BODY_ACTIONS_GAP

	// Button widths: at least MODAL_BUTTON_W_MIN, growing with label.
	btn_widths := make([]f32, len(actions), context.temp_allocator)
	total_btn_w: f32 = 0
	for action, i in actions {
		w := c.measure_text(action, 18) + 2 * MODAL_BUTTON_PAD_X
		if w < MODAL_BUTTON_W_MIN {w = MODAL_BUTTON_W_MIN}
		btn_widths[i] = w
		total_btn_w += w
		if i > 0 {total_btn_w += MODAL_BUTTON_GAP}
	}

	clicked: int = -1
	btn_x := dialog.x + dialog.w - MODAL_PAD_X - total_btn_w
	for action, i in actions {
		rect := Rect{btn_x, y, btn_widths[i], MODAL_BUTTON_H}
		if button(c, sub_id(id, u64(i)), rect, action) {
			clicked = i
			value.open = false
		}
		btn_x += btn_widths[i] + MODAL_BUTTON_GAP
	}

	c.layer = prev_layer
	return clicked
}
