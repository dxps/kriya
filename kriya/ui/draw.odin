package ui

// Low-level drawing primitives that append to the command buffer. Every
// higher-level widget composes these; this is also where offset / clip are
// stamped onto each command and content_bottom is advanced so scroll views
// know how far their content extends.

box :: proc(c: ^Context, r: Rect, color: Color, radius: f32 = 0) {
	c.content_bottom = max(c.content_bottom, r.y + r.h)
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
	c.content_bottom = max(c.content_bottom, max(y1, y2) + width * 0.5)
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
	c.content_bottom = max(c.content_bottom, max(y1, max(y2, y3)))
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
	color: Color = DEFAULT_PALETTE.text,
	font: Font = .Body,
) {
	// y is the baseline; add a modest descender allowance for content measurement.
	c.content_bottom = max(c.content_bottom, y + size * 0.3)
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
				color = color,
			},
		},
	)
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
