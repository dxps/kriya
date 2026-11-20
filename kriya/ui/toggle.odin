package ui

// Pill-shaped on/off switch. Track is 32x18, matching the checkbox's 18px
// box; the 12x12 thumb slides between a 3px inset on either side. Clicking
// anywhere on the track or its label flips the value.
//
// Takes a Rect but only uses r.x and r.y: the toggle draws its own fixed
// 32×18 track and label, so the caller's width and height are ignored.
// Mirrors checkbox's signature so a layout slot flows straight in —
// ui.toggle(c, id, ui.next(&s, 18), ...).
toggle :: proc(c: ^Context, id: u64, r: Rect, text: string, value: ^bool, read_only := false) {
	track := Rect{r.x, r.y, 32, 18}
	hit := track
	if len(text) > 0 {
		assert(c.measure_text != nil, "Toggle labels require a text measurement callback")
		hit.w = 42 + c.measure_text(text, 18)
	}
	// Read-only skips the pressable call so clicks don't flip the value or
	// steal the pointer cursor, and the active-color accents give way to
	// muted palette tones. The thumb still slides to the current side so
	// the state stays readable as a non-interactive display.
	hover: bool
	if !read_only {
		clicked: bool
		hover, clicked = pressable(c, id, hit)
		if clicked {value^ = !value^}
	}
	track_color := DEFAULT_PALETTE.border
	if value^ {
		track_color = read_only ? DEFAULT_PALETTE.disabled : DEFAULT_PALETTE.primary
		if !read_only && hover {track_color = DEFAULT_PALETTE.primary_hover}
		if !read_only && c.active == id && c.down {track_color = DEFAULT_PALETTE.primary_pressed}
	} else if hover {
		track_color = DEFAULT_PALETTE.border_hover
	}
	box(c, track, track_color, 9)
	thumb_x := value^ ? r.x + 17 : r.x + 3
	thumb_color := read_only ? DEFAULT_PALETTE.text_subtle : DEFAULT_PALETTE.text
	box(c, {thumb_x, r.y + 3, 12, 12}, thumb_color, 6)
	label(c, r.x + 42, r.y + 14, text)
}
