#+build !wasm32
package ui
import "core:testing"

// A measurement callback that pretends every glyph is 7 px wide,
// independent of font size. Lets wrap / truncate tests compute expected
// widths deterministically without pulling in a real atlas.
text_per_char_7 :: proc(text: string, size: f32) -> f32 {
	return f32(len(text)) * 7
}

@(test)
wrap_text_breaks_on_word_boundaries :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	// "hello world foo" — widest line that fits 80 px at 7 px/char is 11
	// chars → "hello world" (11). "foo" overflows onto the next line.
	spans := wrap_text(&c, "hello world foo", 80, 17)
	testing.expect(t, len(spans) == 2)
	testing.expect(t, spans[0] == Span{0, 11})
	testing.expect(t, spans[1] == Span{12, 15})
}

@(test)
wrap_text_respects_explicit_newlines :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	spans := wrap_text(&c, "a\nbc", 400, 17)
	testing.expect(t, len(spans) == 2)
	testing.expect(t, spans[0] == Span{0, 1})
	testing.expect(t, spans[1] == Span{2, 4})
}

@(test)
wrap_text_puts_oversized_word_on_its_own_line :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	// "verylongword" at 7 px/char = 84 px, doesn't fit 50 px. Goes on
	// its own line regardless.
	spans := wrap_text(&c, "verylongword next", 50, 17)
	testing.expect(t, len(spans) == 2)
	testing.expect(t, spans[0] == Span{0, 12})
	testing.expect(t, spans[1] == Span{13, 17})
}

@(test)
wrap_text_single_line_when_everything_fits :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	spans := wrap_text(&c, "short line", 200, 17)
	testing.expect(t, len(spans) == 1)
	testing.expect(t, spans[0] == Span{0, 10})
}

@(test)
truncate_fit_returns_text_unchanged_when_it_fits :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	out := truncate_fit(&c, "short", 100, 17)
	testing.expect(t, out == "short")
}

@(test)
truncate_fit_appends_ellipsis_at_rune_boundary :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	// "…" is 3 UTF-8 bytes = 21 px under per-char measurement.
	// Budget for prefix at max_width 50 → 50 - 21 = 29 → 4 chars (28 px).
	out := truncate_fit(&c, "abcdefghij", 50, 17)
	testing.expect(t, out == "abcd…")
}

@(test)
truncate_fit_returns_empty_when_even_ellipsis_cannot_fit :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	// Ellipsis alone is 21 px; budget 10 is less, so nothing fits.
	out := truncate_fit(&c, "anything", 10, 17)
	testing.expect(t, out == "")
}

@(test)
label_wrap_draws_one_label_per_line :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	defer delete(c.commands)
	label_wrap(&c, {0, 0, 80, 200}, "hello world foo", 17)
	testing.expect(t, len(c.commands) == 2)
	testing.expect(t, c.commands[0].variant.(Text_Command).text == "hello world")
	testing.expect(t, c.commands[1].variant.(Text_Command).text == "foo")
}

@(test)
label_wrap_stops_at_rect_bottom :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	defer delete(c.commands)
	// Three wrapped lines at size 17 with stride 17*1.2=20.4: baselines
	// at 12.75, 33.15, 53.55. A rect 40 tall ends at y=40, so only the
	// first two baselines (12.75, 33.15) fit.
	label_wrap(&c, {0, 0, 80, 40}, "one two three four five six", 17)
	testing.expect(t, len(c.commands) == 2)
}

@(test)
label_in_truncate_applies_ellipsis_to_long_text :: proc(t: ^testing.T) {
	c: Context
	c.measure_text = text_per_char_7
	defer delete(c.commands)
	label_in(&c, {0, 0, 50, 24}, "abcdefghij", 17, truncate = true)
	cmd := c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.text == "abcd…")
}
