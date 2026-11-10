package main

import tt "../../backends/font"
import web "../../backends/web"
import "../../routes"
import "base:runtime"
import "core:math"
import "core:mem"
import ui "kriya:ui"
import sapp "sokol:app"
import sg "sokol:gfx"
import sgl "sokol:gl"
import glue "sokol:glue"
import slog "sokol:log"

font := #load("../../web/fonts/WorkSans.ttf")
mono_font := #load("../../web/fonts/Hasklig-Regular.ttf")
ctx: ui.Context
Font_Atlas :: struct {
	physical_size: i32,
	font:          ui.Font,
	dimension:     i32,
	glyphs:        [95]tt.bakedchar,
	image:         sg.Image,
	view:          sg.View,
}
atlases: [32]Font_Atlas
atlas_count: int
atlas_dpi: f32
// Scratch is reused for every atlas; GPU resources retain their own copy.
atlas_bitmap: [2048 * 2048]u8
atlas_pixels: [2048 * 2048]u32
sampler: sg.Sampler
pipeline: sgl.Pipeline
selected: int
sections := routes.SECTIONS
storage: [16 * 1024 * 1024]u8
arena: mem.Arena
temp_storage: [1024 * 1024]u8
temp_arena: mem.Arena
app_context: runtime.Context

init :: proc "c" () {
	context = app_context
	sg.setup({environment = glue.environment(), logger = {func = slog.func}})
	sgl.setup({logger = {func = slog.func}, max_vertices = 65536})
	pipeline = sgl.make_pipeline(
		{
			colors = {
				0 = {
					blend = {
						enabled = true,
						src_factor_rgb = .SRC_ALPHA,
						dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
						src_factor_alpha = .ONE,
						dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
					},
				},
			},
		},
	)
	sampler = sg.make_sampler(
		{
			min_filter = .LINEAR,
			mag_filter = .LINEAR,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
		},
	)
}
clear_atlases :: proc() {
	for i in 0 ..< atlas_count {
		sg.destroy_view(atlases[i].view)
		sg.destroy_image(atlases[i].image)
	}
	atlas_count = 0
}
font_atlas :: proc(size, dpi: f32, face: ui.Font = .Body) -> ^Font_Atlas {
	if dpi != atlas_dpi {clear_atlases(); atlas_dpi = dpi}
	physical_size := i32(math.round(size * dpi))
	for i in 0 ..< atlas_count {
		if atlases[i].physical_size == physical_size &&
		   atlases[i].font == face {return &atlases[i]}
	}
	assert(atlas_count < len(atlases), "Font atlas cache exhausted")
	a := &atlases[atlas_count]
	a.physical_size = physical_size
	a.font = face
	a.dimension = 128
	for a.dimension < physical_size * 12 && a.dimension < 2048 {a.dimension *= 2}
	pixel_count := int(a.dimension * a.dimension)
	data := face == .Mono ? mono_font : font
	used := tt.BakeFontBitmap(
		raw_data(data),
		0,
		f32(physical_size),
		raw_data(atlas_bitmap[:]),
		a.dimension,
		a.dimension,
		32,
		95,
		raw_data(a.glyphs[:]),
	)
	assert(used > 0, "Glyphs do not fit in the font atlas")
	for alpha, i in atlas_bitmap[:pixel_count] {atlas_pixels[i] = 0x00ffffff | (u32(alpha) << 24)}
	a.image = sg.make_image(
		{
			width = a.dimension,
			height = a.dimension,
			data = {ptr = &atlas_pixels[0], size = uint(pixel_count * 4)},
		},
	)
	a.view = sg.make_view({texture = {image = a.image}})
	atlas_count += 1
	return a
}
quad :: proc(r: ui.Rect) {
	sgl.v2f(
		r.x,
		r.y,
	); sgl.v2f(r.x + r.w, r.y); sgl.v2f(r.x + r.w, r.y + r.h); sgl.v2f(r.x, r.y + r.h)
}
rounded_box :: proc(r: ui.Rect, requested_radius: f32) {
	radius := min(requested_radius, min(r.w, r.h) / 2)
	// A triangle fan with six segments per corner makes a smooth pill thumb.
	centers := [4][2]f32 {
		{r.x + r.w - radius, r.y + radius},
		{r.x + r.w - radius, r.y + r.h - radius},
		{r.x + radius, r.y + r.h - radius},
		{r.x + radius, r.y + radius},
	}
	first, previous: [2]f32
	sgl.begin_triangles()
	for center, corner in centers {
		for step in 0 ..= 6 {
			angle := (-math.PI / 2 + f32(corner) * math.PI / 2) + f32(step) * math.PI / 12
			point := [2]f32 {
				center[0] + math.cos(angle) * radius,
				center[1] + math.sin(angle) * radius,
			}
			if corner == 0 &&
			   step ==
				   0 {first = point} else {sgl.v2f(r.x + r.w / 2, r.y + r.h / 2); sgl.v2f(previous[0], previous[1]); sgl.v2f(point[0], point[1])}
			previous = point
		}
	}
	sgl.v2f(
		r.x + r.w / 2,
		r.y + r.h / 2,
	); sgl.v2f(previous[0], previous[1]); sgl.v2f(first[0], first[1])
	sgl.end()
}
measure_text :: proc(text: string, size: f32) -> f32 {
	return measure_font_text(text, size, .Body)
}
measure_font_text :: proc(text: string, size: f32, face: ui.Font) -> f32 {
	dpi := sapp.dpi_scale()
	a := font_atlas(size, dpi, face)
	advance: f32
	right: f32
	for ch in text {
		if ch < 32 || ch > 126 {continue}
		glyph := a.glyphs[ch - 32]
		right = max(right, advance + glyph.xoff + f32(glyph.x1 - glyph.x0))
		advance += glyph.xadvance
	}
	return max(right, advance) / dpi
}
render :: proc() {
	dpi := sapp.dpi_scale()
	// Upload fonts before recording draw commands. Each font is rasterized at
	// its actual framebuffer size, avoiding reduction of a shared 40px bitmap.
	for c in ctx.commands {
		if t, ok := c.variant.(ui.Text_Command); ok {_ = font_atlas(t.size, dpi, t.font)}
	}
	sgl.defaults(); sgl.load_pipeline(pipeline)
	sgl.matrix_mode_projection(); sgl.ortho(0, sapp.widthf() / dpi, sapp.heightf() / dpi, 0, -1, 1)
	// Two passes: Base first, then Overlay. Everything an Overlay command draws
	// paints on top of every Base command, so popup menus survive sibling draws.
	for pass in ([2]ui.Command_Layer{.Base, .Overlay}) do for c in ctx.commands {
		if c.layer != pass {continue}
		if c.clipped {sgl.scissor_rectf(c.clip.x * dpi, c.clip.y * dpi, c.clip.w * dpi, c.clip.h * dpi, true)} else {sgl.scissor_rect(0, 0, sapp.width(), sapp.height(), true)}
		switch v in c.variant {
		case ui.Box_Command:
			sgl.c4f(v.color[0], v.color[1], v.color[2], v.color[3])
			sgl.disable_texture()
			if v.radius > 0 {rounded_box(v.rect, v.radius)} else {sgl.begin_quads(); quad(v.rect); sgl.end()}
		case ui.Triangle_Command:
			sgl.c4f(v.color[0], v.color[1], v.color[2], v.color[3])
			sgl.disable_texture()
			sgl.begin_triangles()
			sgl.v2f(v.x1, v.y1); sgl.v2f(v.x2, v.y2); sgl.v2f(v.x3, v.y3)
			sgl.end()
		case ui.Line_Command:
			sgl.c4f(v.color[0], v.color[1], v.color[2], v.color[3])
			sgl.disable_texture()
			dx := v.x2 - v.x1
			dy := v.y2 - v.y1
			length := math.sqrt(dx * dx + dy * dy)
			nx := -dy / length * v.width / 2
			ny := dx / length * v.width / 2
			sgl.begin_quads()
			sgl.v2f(v.x1 + nx, v.y1 + ny)
			sgl.v2f(v.x2 + nx, v.y2 + ny)
			sgl.v2f(v.x2 - nx, v.y2 - ny)
			sgl.v2f(v.x1 - nx, v.y1 - ny)
			sgl.end()
		case ui.Text_Command:
			sgl.c4f(v.color[0], v.color[1], v.color[2], v.color[3])
			a := font_atlas(v.size, dpi, v.font)
			sgl.enable_texture(); sgl.texture(a.view, sampler); sgl.begin_quads()
			// Snap the baseline and glyph quads in physical pixels. Advances retain
			// their fractional precision; only the final glyph origin is rounded.
			x := math.round(v.x * dpi)
			y := math.round(v.y * dpi)
			for ch in v.text {
				if ch < 32 || ch > 126 {continue}
				q: tt.aligned_quad
				tt.GetBakedQuad(&a.glyphs[0], a.dimension, a.dimension, i32(ch - 32), &x, &y, &q, true)
				sgl.v2f_t2f(q.x0 / dpi, q.y0 / dpi, q.s0, q.t0)
				sgl.v2f_t2f(q.x1 / dpi, q.y0 / dpi, q.s1, q.t0)
				sgl.v2f_t2f(q.x1 / dpi, q.y1 / dpi, q.s1, q.t1)
				sgl.v2f_t2f(q.x0 / dpi, q.y1 / dpi, q.s0, q.t1)
			}
			sgl.end()
		}
	}
	sg.begin_pass(
		{
			action = {
				colors = {
					0 = {
						load_action = .CLEAR,
						clear_value = {
							GALLERY_BACKGROUND[0],
							GALLERY_BACKGROUND[1],
							GALLERY_BACKGROUND[2],
							GALLERY_BACKGROUND[3],
						},
					},
				},
			},
			swapchain = glue.swapchain(),
		},
	)
	sgl.draw(); sg.end_pass(); sg.commit()
}
frame :: proc "c" () {
	context = app_context
	ui.begin(&ctx)
	ctx.measure_text = measure_text
	w := sapp.widthf() / sapp.dpi_scale()
	h := sapp.heightf() / sapp.dpi_scale()
	draw_sidebar(h)
	view := views[selected]
	scroll := &view_scroll[selected]
	ui.begin_scroll(
		&ctx,
		scroll,
		{SIDEBAR_W, 0, max(0, w - SIDEBAR_W), max(0, h - 28)},
		f32(sapp.frame_duration()),
	)
	ui.label(&ctx, CONTENT_X, PAGE_EYEBROW_Y, "LIBRARY / EXPLORER", 13, ui.DEFAULT_PALETTE.text_muted)
	ui.label(&ctx, CONTENT_X, PAGE_TITLE_Y, sections[selected].title, 40)
	ui.label(&ctx, CONTENT_X, PAGE_SUB_Y, "Small primitives. Shared behavior. Built in Odin.", 18)
	ui.box(
		&ctx,
		{PREVIEW_X, PREVIEW_Y, max(PREVIEW_MIN_W, w - PREVIEW_X - PREVIEW_MARGIN_RIGHT), PREVIEW_H},
		ui.DEFAULT_PALETTE.surface_raised,
	)
	ui.label(&ctx, WIDGET_X, PREVIEW_HEADER_Y, "INTERACTIVE PREVIEW", 12, ui.DEFAULT_PALETTE.text_muted)
	view.draw(&ctx)
	draw_source_hint(&ctx, view.source)
	ui.end_scroll(&ctx, scroll)
	sapp.set_mouse_cursor(ctx.pointer_cursor ? .POINTING_HAND : .DEFAULT)
	render(); ui.end(&ctx)
	free_all(context.temp_allocator)
}
event :: proc "c" (e: ^sapp.Event) {
	context = app_context
	ctx.mx = e.mouse_x / sapp.dpi_scale(); ctx.my = e.mouse_y / sapp.dpi_scale()
	#partial switch e.type {
	case .MOUSE_DOWN:
		if e.mouse_button == .LEFT {ctx.pressed = true; ctx.down = true}
	case .MOUSE_UP:
		if e.mouse_button == .LEFT {ctx.released = true; ctx.down = false}
	case .UNFOCUSED:
		ctx.down = false; ctx.active = 0
	case .MOUSE_LEAVE:
		ctx.mx = -1; ctx.my = -1
	case .MOUSE_MOVE:
		ctx.moved = true
	case .MOUSE_SCROLL:
		ctx.wheel_y -= e.scroll_y * 32
	case .CHAR:
		if e.char_code >= 32 && e.char_code <= 126 && ctx.typed_len < len(ctx.typed) {
			ctx.typed[ctx.typed_len] = u8(e.char_code)
			ctx.typed_len += 1
		}
	case .KEY_DOWN:
		if e.key_code == .BACKSPACE {ctx.backspace = true}
	case:
	}
}
cleanup :: proc "c" () {context = app_context; clear_atlases(); sg.destroy_sampler(sampler)
	sgl.shutdown()
	sg.shutdown()}
@(export)
kriya_route_changed :: proc "c" () {
	context = app_context
	for section, i in routes.SECTIONS {
		if web.kriya_path_matches(section.path) {selected = i; return}
	}
}
@(export)
kriya_start :: proc "c" () {
	context = runtime.default_context()
	runtime._startup_runtime()
	mem.arena_init(&arena, storage[:])
	mem.arena_init(&temp_arena, temp_storage[:])
	context.allocator = mem.arena_allocator(&arena)
	context.temp_allocator = mem.arena_allocator(&temp_arena)
	app_context = context
	init_input_examples()
	kriya_route_changed()
	sapp.run(
		{
			init_cb = init,
			frame_cb = frame,
			event_cb = event,
			cleanup_cb = cleanup,
			width = 1200,
			height = 760,
			high_dpi = true,
			window_title = "Kriya",
			html5 = {canvas_selector = "#canvas"},
			logger = {func = slog.func},
		},
	)
}
main :: proc() {kriya_start()}
