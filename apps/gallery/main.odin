package main

import web "../../backends/web"
import "../../routes"
import "base:runtime"
import "core:mem"
import ui "kriya:ui"
import sapp "sokol:app"
import sg "sokol:gfx"
import sgl "sokol:gl"
import glue "sokol:glue"
import slog "sokol:log"

ctx: ui.Context
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
frame :: proc "c" () {
	context = app_context
	ui.begin(&ctx)
	ctx.measure_text = measure_text
	ctx.set_clipboard = app_set_clipboard
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
	preview_h := view.preview_h > 0 ? view.preview_h : PREVIEW_H
	ui.box(
		&ctx,
		{PREVIEW_X, PREVIEW_Y, max(PREVIEW_MIN_W, w - PREVIEW_X - PREVIEW_MARGIN_RIGHT), preview_h},
		ui.DEFAULT_PALETTE.surface_raised,
	)
	ui.label(&ctx, WIDGET_X, PREVIEW_HEADER_Y, "INTERACTIVE PREVIEW", 12, ui.DEFAULT_PALETTE.text_muted)
	view.draw(&ctx)
	draw_source_hint(&ctx, view.source, PREVIEW_Y + preview_h + SOURCE_HINT_GAP)
	ui.end_scroll(&ctx, scroll)
	sapp.set_mouse_cursor(ctx.pointer_cursor ? .POINTING_HAND : .DEFAULT)
	render(); ui.end(&ctx)
	free_all(context.temp_allocator)
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
	init_textarea_examples()
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
			sample_count = 4,
			enable_clipboard = true,
			clipboard_size = 1024,
			window_title = "Kriya",
			html5 = {canvas_selector = "#canvas"},
			logger = {func = slog.func},
		},
	)
}
main :: proc() {kriya_start()}
