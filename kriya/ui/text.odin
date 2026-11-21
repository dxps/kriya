package ui

import "core:unicode/utf8"

// Text-layout helpers that run on the current measure_text width-only
// signature. Widening measure_text to return ascent and descent would
// let the baseline heuristic (size * 0.75 / 0.25) go away, but it's a
// separate PR that touches every widget. For now the heuristic stays
// and these helpers build wrap and ellipsis on top of it.

// Span addresses a slice of a source string by byte offsets. wrap_text
// returns one Span per visual line; callers slice into the original
// string with text[span.start:span.end] to draw or measure a single
// line. Spans don't include trailing whitespace.
Span :: struct {
	start, end: int,
}

// Common line-stride derived from font size. 1.2× matches the ratio
// most body-text UIs use for Latin scripts; dense specimens can pass
// an explicit stride to label_wrap.
line_height :: #force_inline proc(size: f32) -> f32 {return size * 1.2}

// Greedy word-wrap. Breaks at ASCII space / tab and at explicit '\n'.
// A single word wider than max_width goes on its own line and overflows
// — that matches browser behavior and keeps the wrap deterministic.
// Line spans exclude their trailing whitespace so a drawn line doesn't
// paint invisible trailing spaces (and so measurement callers get the
// visually-correct width).
//
// Output lives in the temp allocator; the returned slice is valid only
// until the next free_all on that allocator, which the host clears per
// frame — this matches every other temp use in the library.
wrap_text :: proc(
	c: ^Context,
	text: string,
	max_width: f32,
	size: f32,
	font: Font = .Body,
) -> []Span {
	assert(c.measure_text != nil, "wrap_text requires measure_text")
	lines := make([dynamic]Span, 0, 8, context.temp_allocator)

	line_start := 0
	i := 0
	for i < len(text) {
		word_start := i
		for i < len(text) && text[i] != ' ' && text[i] != '\t' && text[i] != '\n' {
			i += 1
		}
		word_end := i
		for i < len(text) && (text[i] == ' ' || text[i] == '\t') {
			i += 1
		}

		// Check if the line up to word_end fits. The first word of a
		// line always goes in (even if it overflows on its own), so the
		// guard word_start > line_start skips the "break before the
		// very first word" case.
		if word_start > line_start {
			trial := text[line_start:word_end]
			if c.measure_text(trial, size) > max_width {
				end := word_start
				for end > line_start && (text[end - 1] == ' ' || text[end - 1] == '\t') {
					end -= 1
				}
				append(&lines, Span{line_start, end})
				line_start = word_start
			}
		}

		// Explicit newline closes the current line regardless of width.
		if i < len(text) && text[i] == '\n' {
			end := i
			for end > line_start && (text[end - 1] == ' ' || text[end - 1] == '\t') {
				end -= 1
			}
			append(&lines, Span{line_start, end})
			i += 1
			line_start = i
		}
	}

	// Trailing partial line, if any — or an empty final span so callers
	// drawing a text that ends in '\n' still get a terminal line.
	end := len(text)
	for end > line_start && (text[end - 1] == ' ' || text[end - 1] == '\t') {
		end -= 1
	}
	append(&lines, Span{line_start, end})
	return lines[:]
}

// Multi-line label inside r. Each line sits on a baseline advanced by
// 'stride' (defaults to line_height(size)). Lines whose baseline would
// fall below r.y + r.h are skipped — the visible extent is implicit in
// the rect, not in the wrap. Horizontal start-alignment only; use
// label_in with truncate for center / end alignment on one line.
label_wrap :: proc(
	c: ^Context,
	r: Rect,
	text: string,
	size: f32 = 18,
	color: Maybe(Color) = nil,
	font: Font = .Body,
	stride: Maybe(f32) = nil,
) {
	lines := wrap_text(c, text, r.w, size, font)
	step := stride.? or_else line_height(size)
	baseline := r.y + size * 0.75
	bottom := r.y + r.h
	for span in lines {
		if baseline > bottom {break}
		label(c, r.x, baseline, text[span.start:span.end], size, color, font)
		baseline += step
	}
}

// Longest prefix of 'text' that fits within max_width once "…" is
// appended, at rune boundaries. Returns "" when even the ellipsis
// doesn't fit. Caller receives a temp-allocated string; identical to
// 'text' when no truncation was needed.
truncate_fit :: proc(
	c: ^Context,
	text: string,
	max_width: f32,
	size: f32,
	font: Font = .Body,
) -> string {
	assert(c.measure_text != nil, "truncate_fit requires measure_text")
	if c.measure_text(text, size) <= max_width {return text}
	ELLIPSIS: string : "…"
	ellipsis_w := c.measure_text(ELLIPSIS, size)
	if ellipsis_w >= max_width {return ""}
	budget := max_width - ellipsis_w

	best_end := 0
	byte_offset := 0
	for byte_offset < len(text) {
		r, rune_size := utf8.decode_rune_in_string(text[byte_offset:])
		if r == utf8.RUNE_ERROR || rune_size == 0 {break}
		next := byte_offset + rune_size
		if c.measure_text(text[:next], size) > budget {break}
		best_end = next
		byte_offset = next
	}
	if best_end == 0 {return ""}

	result := make([]u8, best_end + len(ELLIPSIS), context.temp_allocator)
	copy(result[:best_end], transmute([]u8)text[:best_end])
	copy(result[best_end:], transmute([]u8)ELLIPSIS)
	return string(result)
}
