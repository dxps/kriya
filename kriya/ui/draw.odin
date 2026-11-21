package ui

// Low-level drawing primitives that append to the command buffer. Every
// higher-level widget composes these; this is also where offset / clip are
// stamped onto each command and content_bottom is advanced so scroll views
// know how far their content extends.

box :: proc(c: ^Context, r: Rect, color: Color, radius: f32 = 0) {
	// Overlay draws (dropdown popups, tooltips) sit on top of the base
	// content and must not grow the scrollable area underneath them —
	// otherwise opening a popup lengthens the page scroll by its own
	// height.
	if c.layer != .Overlay {c.content_bottom = max(c.content_bottom, r.y + r.h)}
	translated := r; translated.y += c.offset_y
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Box_Command{rect = translated, color = color, radius = radius},
		},
	)
}
line :: proc(c: ^Context, x1, y1, x2, y2, width: f32, color: Color) {
	if c.layer != .Overlay {
		c.content_bottom = max(c.content_bottom, max(y1, y2) + width * 0.5)
	}
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Line_Command {
				x1 = x1,
				y1 = y1 + c.offset_y,
				x2 = x2,
				y2 = y2 + c.offset_y,
				width = width,
				color = color,
			},
		},
	)
}
triangle :: proc(c: ^Context, x1, y1, x2, y2, x3, y3: f32, color: Color) {
	if c.layer != .Overlay {
		c.content_bottom = max(c.content_bottom, max(y1, max(y2, y3)))
	}
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Triangle_Command {
				x1 = x1,
				y1 = y1 + c.offset_y,
				x2 = x2,
				y2 = y2 + c.offset_y,
				x3 = x3,
				y3 = y3 + c.offset_y,
				color = color,
			},
		},
	)
}
label :: proc(
	c: ^Context,
	x, y: f32,
	text: string,
	size: f32 = 18,
	color: Maybe(Color) = nil,
	font: Font = .Body,
) {
	// y is the baseline; add a modest descender allowance for content measurement.
	if c.layer != .Overlay {c.content_bottom = max(c.content_bottom, y + size * 0.3)}
	// nil color resolves to the active theme's primary text color so
	// label output follows a theme switch without every caller passing
	// an explicit color.
	resolved := color.? or_else palette(c).text
	append(
		&c.commands,
		Command {
			clip = c.clip,
			clipped = c.clipped,
			layer = c.layer,
			variant = Text_Command {
				x = x,
				y = y + c.offset_y,
				text = text,
				size = size,
				font = font,
				color = resolved,
			},
		},
	)
}

// Rect-anchored label: aligns text inside r on both axes. v defaults to
// Center because that matches what a widget slot wants most of the time
// (a label sitting inside a row slot centered vertically). Only Center
// and End horizontal alignment need measure_text — Start skips the call
// so a context without a measurement callback can still emit Start text.
//
// Baseline model: cap height + descender ≈ size, with the baseline a bit
// below the em top. The 0.75 ascender / 0.25 descender split matches what
// the hand-placed labels in the gallery have been using (button text at
// r.y + 28 for size 18 in a 46 px tall button is Center; 28 ≈ 46/2 + 18/4).
label_in :: proc(
	c: ^Context,
	r: Rect,
	text: string,
	size: f32 = 18,
	h: Align = .Start,
	v: Align = .Center,
	color: Maybe(Color) = nil,
	font: Font = .Body,
	truncate: bool = false,
) {
	ASCENDER :: f32(0.75)
	DESCENDER :: f32(0.25)
	// When truncate is on, shorten text to fit r.w with a trailing "…"
	// before measuring for alignment, so horizontal centering / end-
	// alignment work on the post-truncation width.
	display := text
	if truncate {display = truncate_fit(c, text, r.w, size, font)}
	x: f32 = r.x
	if h != .Start {
		assert(c.measure_text != nil, "label_in non-start alignment requires measure_text")
		w := c.measure_text(display, size)
		switch h {
		case .Start:
		case .Center:
			x = r.x + (r.w - w) / 2
		case .End:
			x = r.x + r.w - w
		}
	}
	y: f32
	switch v {
	case .Start:
		y = r.y + size * ASCENDER
	case .Center:
		y = r.y + r.h / 2 + size * DESCENDER
	case .End:
		y = r.y + r.h - size * DESCENDER
	}
	label(c, x, y, display, size, color, font)
}
point_in_rect :: proc(x, y: f32, r: Rect) -> bool {return(
		x >= r.x &&
		x < r.x + r.w &&
		y >= r.y &&
		y < r.y + r.h \
	)}
contains :: proc(c: ^Context, r: Rect) -> bool {
	translated := r; translated.y += c.offset_y
	return(
		!c.input_blocked &&
		(!c.clipped || point_in_rect(c.mx, c.my, c.clip)) &&
		point_in_rect(c.mx, c.my, translated) \
	)
}
