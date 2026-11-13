package main

import tt "../../backends/font"
import "core:math"
import ui "kriya:ui"
import sapp "sokol:app"
import sg "sokol:gfx"
import sgl "sokol:gl"
import glue "sokol:glue"

pipeline: sgl.Pipeline

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
				if ch < FIRST_GLYPH || ch > LAST_GLYPH {continue}
				if a.glyphs[ch - FIRST_GLYPH].xadvance == 0 {continue}
				q: tt.aligned_quad
				tt.GetBakedQuad(
					&a.glyphs[0],
					a.dimension,
					a.dimension,
					i32(ch) - FIRST_GLYPH,
					&x,
					&y,
					&q,
					true,
				)
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
