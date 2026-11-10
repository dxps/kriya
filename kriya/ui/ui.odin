package ui

import "core:unicode/utf8"

Color :: [4]f32
Font :: enum {
	Body,
	Mono,
}
DEFAULT_CORNER_RADIUS :: 6.0
Rect :: struct {
	x, y, w, h: f32,
}
// Base covers the normal widget drawing order. Overlay commands are rendered
// after every Base command in the same frame, so popup menus and tooltips
// paint on top of anything drawn after them.
Command_Layer :: enum u8 {
	Base,
	Overlay,
}
Box_Command :: struct {
	rect:   Rect,
	color:  Color,
	radius: f32,
}
Line_Command :: struct {
	x1, y1, x2, y2, width: f32,
	color:                 Color,
}
Triangle_Command :: struct {
	x1, y1, x2, y2, x3, y3: f32,
	color:                  Color,
}
Text_Command :: struct {
	x, y:  f32,
	text:  string,
	size:  f32,
	font:  Font,
	color: Color,
}
Command_Variant :: union {
	Box_Command,
	Line_Command,
	Triangle_Command,
	Text_Command,
}
Command :: struct {
	clip:    Rect,
	clipped: bool,
	layer:   Command_Layer,
	variant: Command_Variant,
}
Context :: struct {
	commands:                [dynamic]Command,
	mx, my:                  f32,
	pressed, released, down: bool,
	active:                  u64,
	measure_text:            proc(text: string, size: f32) -> f32,
	pointer_cursor:          bool,
	moved:                   bool,
	wheel_y:                 f32,
	offset_y:                f32,
	clip:                    Rect,
	clipped:                 bool,
	input_blocked:           bool,
	focused:                 u64,
	typed:                   [32]u8,
	typed_len:               int,
	backspace:               bool,
	corner_radius:           Maybe(f32),
	layer:                   Command_Layer,
	content_bottom:          f32,
}
begin :: proc(c: ^Context) {clear(&c.commands); c.pointer_cursor = false; c.offset_y = 0
	c.clipped = false
	c.input_blocked = false
	c.layer = .Base
	c.content_bottom = 0}
end :: proc(c: ^Context) {c.pressed = false; c.released = false; c.moved = false; c.wheel_y = 0
	c.typed_len = 0
	c.backspace = false}
set_corner_radius :: proc(c: ^Context, radius: f32) {c.corner_radius = max(0, radius)}
resolve_corner_radius :: proc(c: ^Context, radius: Maybe(f32)) -> f32 {
	if r, ok := radius.?; ok {return r}
	if r, ok := c.corner_radius.?; ok {return r}
	return DEFAULT_CORNER_RADIUS
}
// Derives a unique auxiliary id for a secondary hit region inside a widget
// (dropdown items, password-reveal eye). The golden-ratio stride spreads
// derived ids across the 64-bit space so neighboring user ids don't collide.
sub_id :: proc(id, n: u64) -> u64 {return id ~ ((n + 1) * 0x9e3779b97f4a7c15)}
// Standard hover/press/active/release plumbing shared by every clickable
// widget. Returns both hover (for color selection) and clicked (for the
// widget's action).
pressable :: proc(c: ^Context, id: u64, hit: Rect) -> (hover, clicked: bool) {
	hover = contains(c, hit)
	if hover {c.pointer_cursor = true}
	if hover && c.pressed {c.active = id}
	clicked = hover && c.released && c.active == id
	if c.released && c.active == id {c.active = 0}
	return
}
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
button :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	text: string,
	disabled := false,
	radius: Maybe(f32) = nil,
) -> bool {
	corner_radius := resolve_corner_radius(c, radius)
	hover, clicked: bool
	if !disabled {hover, clicked = pressable(c, id, r)}
	color := DEFAULT_PALETTE.primary
	if hover {color = DEFAULT_PALETTE.primary_hover}
	if c.active == id && c.down {color = DEFAULT_PALETTE.primary_pressed}
	if disabled {color = DEFAULT_PALETTE.disabled}
	box(
		c,
		r,
		color,
		corner_radius,
	); label(c, r.x + 18, r.y + 28, text, 18, DEFAULT_PALETTE.text_on_primary)
	return clicked
}
checkbox :: proc(
	c: ^Context,
	id: u64,
	x, y: f32,
	text: string,
	value: ^bool,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	r := Rect{x, y, 18, 18}
	hit := r
	if len(text) > 0 {
		assert(c.measure_text != nil, "Checkbox labels require a text measurement callback")
		hit.w = 28 + c.measure_text(text, 18)
	}
	hover, clicked := pressable(c, id, hit)
	if clicked {value^ = !value^}
	border := DEFAULT_PALETTE.primary
	if hover {border = DEFAULT_PALETTE.primary_hover}
	if c.active == id && c.down {border = DEFAULT_PALETTE.primary_pressed}
	box(c, r, border, corner_radius)
	// One logical pixel of border, independent of the checked indicator.
	box(c, {x + 1, y + 1, 16, 16}, DEFAULT_PALETTE.surface_raised, max(0, corner_radius - 1))
	if value^ {box(c, {x + 3, y + 3, 12, 12}, border, max(0, corner_radius - 3))}
	label(c, x + 28, y + 14, text)
}
// Pill-shaped on/off switch. Track is 44x24; the 18x18 thumb slides between a
// 3px inset on either side. Clicking anywhere on the track or its label flips
// the value, matching checkbox's hit model.
toggle :: proc(c: ^Context, id: u64, x, y: f32, text: string, value: ^bool) {
	track := Rect{x, y, 44, 24}
	hit := track
	if len(text) > 0 {
		assert(c.measure_text != nil, "Toggle labels require a text measurement callback")
		hit.w = 54 + c.measure_text(text, 18)
	}
	hover, clicked := pressable(c, id, hit)
	if clicked {value^ = !value^}
	track_color := DEFAULT_PALETTE.border
	if value^ {
		track_color = DEFAULT_PALETTE.primary
		if hover {track_color = DEFAULT_PALETTE.primary_hover}
		if c.active == id && c.down {track_color = DEFAULT_PALETTE.primary_pressed}
	} else if hover {
		track_color = DEFAULT_PALETTE.border_hover
	}
	box(c, track, track_color, 12)
	thumb_x := value^ ? x + 23 : x + 3
	box(c, {thumb_x, y + 3, 18, 18}, DEFAULT_PALETTE.text, 9)
	label(c, x + 54, y + 17, text)
}

Text_Input :: struct {
	data:     [128]u8,
	len:      int,
	revealed: bool,
}

set_text :: proc(value: ^Text_Input, text: string) {
	value.len = min(len(text), len(value.data))
	copy(value.data[:value.len], transmute([]u8)text[:value.len])
}

input :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	placeholder: string,
	value: ^Text_Input,
	password := false,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	hover := contains(c, r)
	eye_w: f32 = password ? 44 : 0
	text_hit := Rect{r.x, r.y, r.w - eye_w, r.h}
	if hover {c.pointer_cursor = true}
	if c.pressed {
		if contains(c, text_hit) {c.focused = id} else if c.focused == id && !hover {c.focused = 0}
	}
	focused := c.focused == id
	if focused {
		if c.backspace && value.len > 0 {
			// Drop one whole rune, not one byte: step back past UTF-8
			// continuation bytes (top two bits == 10).
			value.len -= 1
			for value.len > 0 && (value.data[value.len] & 0xC0) == 0x80 {value.len -= 1}
		}
		for ch in c.typed[:c.typed_len] {
			if value.len < len(value.data) {value.data[value.len] = ch; value.len += 1}
		}
		c.typed_len = 0
		c.backspace = false
	}
	border := DEFAULT_PALETTE.border
	if hover {border = DEFAULT_PALETTE.border_hover}
	if focused {border = DEFAULT_PALETTE.primary_bright}
	box(c, r, border, corner_radius)
	box(
		c,
		{r.x + 1, r.y + 1, r.w - 2, r.h - 2},
		DEFAULT_PALETTE.surface,
		max(0, corner_radius - 1),
	)
	shown := placeholder
	masked := password && !value.revealed && value.len > 0
	color := DEFAULT_PALETTE.text_muted
	if value.len > 0 {
		color = DEFAULT_PALETTE.text
		if !masked {
			shown = string(value.data[:value.len])
		}
	}
	rune_count := utf8.rune_count_in_string(string(value.data[:value.len]))
	if masked {
		// Draw round password bullets independently of the text font so their
		// shape remains circular at every display scale. One bullet per rune,
		// not per UTF-8 byte.
		bullet_x := r.x + 14
		for _ in 0 ..< rune_count {
			box(c, {bullet_x, r.y + r.h / 2 - 4, 8, 8}, color, 4)
			bullet_x += 14
		}
	} else {
		label(c, r.x + 14, r.y + 29, shown, 17, color)
	}
	if focused {
		caret_x := r.x + 14 + f32(rune_count) * 14
		if !masked {
			assert(c.measure_text != nil, "Focused inputs require a text measurement callback")
			caret_x = r.x + 14 + c.measure_text(shown, 17)
		}
		box(
			c,
			{min(caret_x, r.x + r.w - eye_w - 12), r.y + 11, 1, r.h - 22},
			DEFAULT_PALETTE.primary_bright,
		)
	}
	if password {
		divider_x := r.x + r.w - eye_w
		box(c, {divider_x, r.y + 8, 1, r.h - 16}, DEFAULT_PALETTE.divider)
		eye := Rect{divider_x + 12, r.y + 16, 20, 12}
		eye_hover, eye_clicked := pressable(c, sub_id(id, 1), {divider_x, r.y, eye_w, r.h})
		if eye_clicked {value.revealed = !value.revealed}
		eye_color := eye_hover ? DEFAULT_PALETTE.primary_bright : DEFAULT_PALETTE.text_subtle
		// Four short segments per lid retain a gentle curve while keeping the
		// left and right corners pointed like a conventional eye glyph.
		line(c, eye.x, eye.y + 6, eye.x + 5, eye.y + 2, 1.4, eye_color)
		line(c, eye.x + 5, eye.y + 2, eye.x + 10, eye.y + 1, 1.4, eye_color)
		line(c, eye.x + 10, eye.y + 1, eye.x + 15, eye.y + 2, 1.4, eye_color)
		line(c, eye.x + 15, eye.y + 2, eye.x + 20, eye.y + 6, 1.4, eye_color)
		line(c, eye.x, eye.y + 6, eye.x + 5, eye.y + 10, 1.4, eye_color)
		line(c, eye.x + 5, eye.y + 10, eye.x + 10, eye.y + 11, 1.4, eye_color)
		line(c, eye.x + 10, eye.y + 11, eye.x + 15, eye.y + 10, 1.4, eye_color)
		line(c, eye.x + 15, eye.y + 10, eye.x + 20, eye.y + 6, 1.4, eye_color)
		box(c, {eye.x + 7, eye.y + 3, 6, 6}, eye_color, 3)
		if !value.revealed {
			// Hidden is visually distinct by default: the eye is struck through.
			line(
				c,
				eye.x - 2,
				eye.y + eye.h + 3,
				eye.x + eye.w + 2,
				eye.y - 3,
				2.5,
				DEFAULT_PALETTE.surface,
			)
			line(c, eye.x - 2, eye.y + eye.h + 3, eye.x + eye.w + 2, eye.y - 3, 1.25, eye_color)
		}
	}
}

Dropdown :: struct {
	selected: int,
	open:     bool,
}

dropdown :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	options: []string,
	value: ^Dropdown,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	assert(len(options) > 0, "Dropdowns require at least one option")
	value.selected = clamp(value.selected, 0, len(options) - 1)
	menu := Rect{r.x, r.y + r.h, r.w, f32(len(options)) * 40 + 2}
	if value.open && c.pressed && !contains(c, r) && !contains(c, menu) {
		value.open = false
	}
	hover, clicked := pressable(c, id, r)
	if clicked {value.open = !value.open}
	border := DEFAULT_PALETTE.border
	if hover || value.open {border = DEFAULT_PALETTE.primary_bright}
	box(c, r, border, corner_radius)
	box(
		c,
		{r.x + 1, r.y + 1, r.w - 2, r.h - 2},
		DEFAULT_PALETTE.surface,
		max(0, corner_radius - 1),
	)
	label(c, r.x + 14, r.y + 29, options[value.selected], 17)
	arrow_x := r.x + r.w - 22
	arrow_y := r.y + r.h / 2
	arrow_color := DEFAULT_PALETTE.text_subtle
	if value.open {
		triangle(
			c,
			arrow_x - 5,
			arrow_y + 3,
			arrow_x + 5,
			arrow_y + 3,
			arrow_x,
			arrow_y - 4,
			arrow_color,
		)
	} else {
		triangle(
			c,
			arrow_x - 5,
			arrow_y - 3,
			arrow_x + 5,
			arrow_y - 3,
			arrow_x,
			arrow_y + 4,
			arrow_color,
		)
	}
	if value.open {
		prev_layer := c.layer
		c.layer = .Overlay
		defer c.layer = prev_layer
		box(c, menu, DEFAULT_PALETTE.overlay_border, corner_radius)
		box(
			c,
			{menu.x + 1, menu.y + 1, menu.w - 2, menu.h - 2},
			DEFAULT_PALETTE.overlay,
			max(0, corner_radius - 1),
		)
		for option, i in options {
			item := Rect{menu.x + 1, menu.y + 1 + f32(i) * 40, menu.w - 2, 40}
			item_hover, item_clicked := pressable(c, sub_id(id, u64(i + 1)), item)
			if item_clicked {value.selected = i; value.open = false}
			item_color := DEFAULT_PALETTE.overlay
			if i == value.selected {item_color = DEFAULT_PALETTE.item_selected}
			if item_hover {item_color = DEFAULT_PALETTE.item_hover}
			item_radius: f32 = 0
			if i == 0 || i == len(options) - 1 {item_radius = max(0, corner_radius - 1)}
			box(c, item, item_color, item_radius)
			// Preserve the panel curves while keeping adjoining row edges square.
			if item_radius > 0 && i == 0 && len(options) > 1 {
				box(c, {item.x, item.y + item.h - item_radius, item.w, item_radius}, item_color)
			}
			if item_radius > 0 && i == len(options) - 1 && len(options) > 1 {
				box(c, {item.x, item.y, item.w, item_radius}, item_color)
			}
			label(c, item.x + 14, item.y + 26, option, 16)
		}
	}
}
