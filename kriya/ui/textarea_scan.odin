package ui

import "core:unicode/utf8"

// Pure byte-buffer scanning helpers the textarea uses to answer "where is
// the line break", "where is the next word", "which byte index does this
// pixel X belong to". No mutation, no widget state — just functions on
// the buffer so the main widget proc stays legible.

// Byte index of the start of the line containing caret. Walks forward
// because rune-aware edits only guarantee a valid caret on rune
// boundaries, not that we can scan backward one byte at a time.
textarea_line_start :: proc(data: []u8, caret: int) -> int {
	s := 0
	for i in 0 ..< caret {
		if data[i] == '\n' {s = i + 1}
	}
	return s
}

// Byte index of the newline terminating the line containing caret, or
// len(data) when the line has no trailing newline.
textarea_line_end :: proc(data: []u8, caret: int) -> int {
	for i in caret ..< len(data) {
		if data[i] == '\n' {return i}
	}
	return len(data)
}

// Classifies a byte as "word" (letters, digits, underscore and every
// non-ASCII byte — UTF-8 lead and continuation bytes are both >= 0x80, so
// multi-byte word characters stay grouped). Newlines, spaces and ASCII
// punctuation are not word bytes.
textarea_is_word_byte :: proc(b: u8) -> bool {
	if b >= 0x80 {return true}
	if b >= 'a' && b <= 'z' {return true}
	if b >= 'A' && b <= 'Z' {return true}
	if b >= '0' && b <= '9' {return true}
	return b == '_'
}

// Walks forward from pos past any run of non-word bytes, then past the
// following run of word bytes, and returns that stopping position. Used
// by Ctrl+Right to jump to the end of the next word. The scan is
// rune-safe because textarea_is_word_byte treats every UTF-8 lead and
// continuation byte as a word byte, so every multi-byte word rune is
// crossed whole.
textarea_next_word :: proc(data: []u8, pos: int) -> int {
	i := pos
	for i < len(data) && !textarea_is_word_byte(data[i]) {i += 1}
	for i < len(data) && textarea_is_word_byte(data[i]) {i += 1}
	return i
}

// Mirror of textarea_next_word for Ctrl+Left: steps backward past any
// run of non-word bytes, then past the preceding run of word bytes.
textarea_prev_word :: proc(data: []u8, pos: int) -> int {
	i := pos
	for i > 0 && !textarea_is_word_byte(data[i - 1]) {i -= 1}
	for i > 0 && textarea_is_word_byte(data[i - 1]) {i -= 1}
	return i
}

// Returns the byte range [ws, we) of the word around pos, bounded by the
// enclosing line. Used by double-click to expand a caret click into a
// word selection. If pos lands on whitespace or punctuation and neither
// neighbor is a word byte, returns pos, pos — the caller should keep the
// caret where it is.
textarea_word_bounds :: proc(data: []u8, pos, line_start, line_end: int) -> (int, int) {
	ws := pos
	we := pos
	if pos > line_start && textarea_is_word_byte(data[pos - 1]) {
		for ws > line_start && textarea_is_word_byte(data[ws - 1]) {ws -= 1}
	}
	if pos < line_end && textarea_is_word_byte(data[pos]) {
		for we < line_end && textarea_is_word_byte(data[we]) {we += 1}
	}
	return ws, we
}

// Given a target x in pixels relative to the line's text origin, returns
// the byte index on that line whose rune boundary is closest to the
// target. Used by click positioning and by Up / Down to project the goal
// column onto a different line.
textarea_x_to_caret :: proc(
	c: ^Context,
	data: []u8,
	line_start, line_end: int,
	target_x: f32,
) -> int {
	if target_x <= 0 {return line_start}
	text := string(data[line_start:line_end])
	byte_pos := 0
	prev_w: f32 = 0
	for byte_pos < len(text) {
		_, rs := utf8.decode_rune_in_string(text[byte_pos:])
		end := byte_pos + rs
		if end > len(text) {end = len(text)}
		w := c.measure_text(text[:end], 17)
		if target_x < (prev_w + w) / 2 {return line_start + byte_pos}
		prev_w = w
		byte_pos = end
	}
	return line_end
}
