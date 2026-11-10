package font
// Small C ABI surface; Emscripten supplies stb's C runtime.
bakedchar :: struct {
	x0, y0, x1, y1:       u16,
	xoff, yoff, xadvance: f32,
}
aligned_quad :: struct {
	x0, y0, s0, t0, x1, y1, s1, t1: f32,
}
foreign import lib "env.o"
@(default_calling_convention = "c", link_prefix = "stbtt_")
foreign lib {
	BakeFontBitmap :: proc(data: [^]u8, offset: i32, height: f32, pixels: [^]u8, w, h, first, count: i32, chars: [^]bakedchar) -> i32 ---
	GetBakedQuad :: proc(chars: ^bakedchar, w, h, index: i32, x, y: ^f32, q: ^aligned_quad, fill: b32) ---
}
