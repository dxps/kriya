package ui

import "core:unicode/utf8"

// Round identity tile for a person or entity — a photo stand-in drawn
// from the first letters of a name. Purely informational like badge:
// takes no id and reads no input, so a caller never worries about
// focus or hit-testing around it.
//
// Always a circle: corner radius is min(w, h)/2 regardless of the
// configured default, same way badge stays a pill. A non-square rect
// still rounds, giving a capsule — pass a square rect for the usual
// round look.
//
// emphasis switches between the two looks shared with the rest of the
// library (badge, button, segmented, toggle all pair this way) rather
// than introducing a separate avatar palette: subtle is a surface-
// raised fill behind a 1px border with muted initials, emphasis is a
// solid primary fill with text_on_primary.
avatar :: proc(c: ^Context, r: Rect, name: string, emphasis := false) {
	corner_radius := min(r.w, r.h) / 2
	text := initials(name)
	// Scale initials with the tile so 24-56 px avatars all read about
	// the same weight. 40% of the height puts a 40px avatar at ~16pt,
	// which matches a badge sitting next to it.
	size := max(10, r.h * 0.4)
	if emphasis {
		box(c, r, palette(c).primary, corner_radius)
		label_in(c, r, text, size, .Center, .Center, color = palette(c).text_on_primary)
		return
	}
	box(c, r, palette(c).border, corner_radius)
	inner := Rect{r.x + 1, r.y + 1, max(0, r.w - 2), max(0, r.h - 2)}
	box(c, inner, palette(c).surface_raised, max(0, corner_radius - 1))
	label_in(c, r, text, size, .Center, .Center, color = palette(c).text_muted)
}

// Derives 1-2 initials from a human name:
//   "Marius Ileana"    -> "MI"
//   "Ana"              -> "A"
//   "  ana  popescu "  -> "AP"
//   ""                 -> "?"
// A single word gives one initial; two or more words give the first
// word's first rune plus the last word's. Whitespace-only input falls
// back to "?" so the tile never renders blank.
//
// Uppercasing covers ASCII a-z only. Romanian names written with
// proper capitalization already pass through — the first rune of
// "Ileana" or "Ștefan" stays the glyph it was.
//
// Returned string lives in the temp allocator, matching wrap_text and
// truncate_fit; the host clears that allocator each frame.
initials :: proc(name: string) -> string {
	// First word.
	i := 0
	for i < len(name) && (name[i] == ' ' || name[i] == '\t') {i += 1}
	if i == len(name) {return "?"}
	first_start := i
	for i < len(name) && name[i] != ' ' && name[i] != '\t' {i += 1}

	// Last word start (if any). Scan past the first word's trailing
	// whitespace and keep updating last_start until the string ends,
	// so the final non-space run wins no matter how many words sit
	// between first and last.
	last_start := -1
	for i < len(name) {
		for i < len(name) && (name[i] == ' ' || name[i] == '\t') {i += 1}
		if i == len(name) {break}
		last_start = i
		for i < len(name) && name[i] != ' ' && name[i] != '\t' {i += 1}
	}

	first_r, _ := utf8.decode_rune_in_string(name[first_start:])
	first_up := ascii_upper(first_r)

	if last_start < 0 {
		buf := make([]u8, 4, context.temp_allocator)
		bytes, n := utf8.encode_rune(first_up)
		for k in 0 ..< n {buf[k] = bytes[k]}
		return string(buf[:n])
	}

	second_r, _ := utf8.decode_rune_in_string(name[last_start:])
	second_up := ascii_upper(second_r)

	buf := make([]u8, 8, context.temp_allocator)
	b1, n1 := utf8.encode_rune(first_up)
	for k in 0 ..< n1 {buf[k] = b1[k]}
	b2, n2 := utf8.encode_rune(second_up)
	for k in 0 ..< n2 {buf[n1 + k] = b2[k]}
	return string(buf[:n1 + n2])
}

@(private)
ascii_upper :: #force_inline proc(r: rune) -> rune {
	if r >= 'a' && r <= 'z' {return r - ('a' - 'A')}
	return r
}
