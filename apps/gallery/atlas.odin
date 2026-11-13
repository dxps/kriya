package main

import tt "../../backends/font"
import "core:math"
import ui "kriya:ui"
import sapp "sokol:app"
import sg "sokol:gfx"

// Atlas covers Basic Latin + Latin-1 Supplement + Latin Extended-A + part of
// Latin Extended-B — every European language including Romanian (ă â î ș ț).
// Runes outside this range are silently skipped. Larger sizes may not fit the
// full range in a 2048 atlas; unbaked glyphs have xadvance == 0 and are
// skipped by measure and render.
FIRST_GLYPH :: 0x20
LAST_GLYPH :: 0x24F
GLYPH_COUNT :: LAST_GLYPH - FIRST_GLYPH + 1

font := #load("../../web/fonts/WorkSans.ttf")
mono_font := #load("../../web/fonts/Hasklig-Regular.ttf")

Font_Atlas :: struct {
	physical_size: i32,
	font:          ui.Font,
	dimension:     i32,
	glyphs:        [GLYPH_COUNT]tt.bakedchar,
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
	for a.dimension < physical_size * 25 && a.dimension < 2048 {a.dimension *= 2}
	pixel_count := int(a.dimension * a.dimension)
	data := face == .Mono ? mono_font : font
	// stbtt_BakeFontBitmap may return a negative value at large sizes when not
	// every glyph fits. Unbaked slots stay zero-initialized (xadvance == 0),
	// which measure and render use as a skip sentinel.
	_ = tt.BakeFontBitmap(
		raw_data(data),
		0,
		f32(physical_size),
		raw_data(atlas_bitmap[:]),
		a.dimension,
		a.dimension,
		FIRST_GLYPH,
		GLYPH_COUNT,
		raw_data(a.glyphs[:]),
	)
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
measure_text :: proc(text: string, size: f32) -> f32 {
	return measure_font_text(text, size, .Body)
}
measure_font_text :: proc(text: string, size: f32, face: ui.Font) -> f32 {
	dpi := sapp.dpi_scale()
	a := font_atlas(size, dpi, face)
	advance: f32
	right: f32
	for ch in text {
		if ch < FIRST_GLYPH || ch > LAST_GLYPH {continue}
		glyph := a.glyphs[ch - FIRST_GLYPH]
		if glyph.xadvance == 0 {continue}
		right = max(right, advance + glyph.xoff + f32(glyph.x1 - glyph.x0))
		advance += glyph.xadvance
	}
	return max(right, advance) / dpi
}
