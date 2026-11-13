package ui

// Pill-shaped on/off switch. Track is 32x18, matching the checkbox's 18px
// box; the 12x12 thumb slides between a 3px inset on either side. Clicking
// anywhere on the track or its label flips the value.
toggle :: proc(c: ^Context, id: u64, x, y: f32, text: string, value: ^bool) {
	track := Rect{x, y, 32, 18}
	hit := track
	if len(text) > 0 {
		assert(c.measure_text != nil, "Toggle labels require a text measurement callback")
		hit.w = 42 + c.measure_text(text, 18)
	}
	hover, clicked := pressable(c, id, hit)
	if clicked {value^ = !value^}
	track_color := DEFAULT_PALETTE.border
	if value^ {
		track_color = DEFAULT_PALETTE.primary
		if hover {track_color = DEFAULT_PALETTE.primary_hover}
		if c.active == id && c.down {track_color = DEFAULT_PALETTE.primary_pressed}
	} else if hover {
		track_color = DEFAULT_PALETTE.border_hover
	}
	box(c, track, track_color, 9)
	thumb_x := value^ ? x + 17 : x + 3
	box(c, {thumb_x, y + 3, 12, 12}, DEFAULT_PALETTE.text, 6)
	label(c, x + 42, y + 14, text)
}
