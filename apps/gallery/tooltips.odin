package main
import "core:fmt"
import ui "kriya:ui"

tooltips_counter: int

// Four interactive elements each with a hover tooltip. Buttons and
// toggles use their own layout rect as the hover hit; the long-form
// explanation hint uses a dedicated badge rect so the pointer has a
// focused target.
draw_tooltips :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 254, INPUT_W, 360}, gap = 0)

	button_rect := ui.next(&s, CONTROL_H)
	// Only treat the BUTTON_W-wide prefix as the button; it also serves
	// as the tooltip hit.
	primary_rect := ui.Rect{button_rect.x, button_rect.y, BUTTON_W, button_rect.h}
	if ui.button(c, 70, primary_rect, "Save changes") {tooltips_counter += 1}
	ui.tooltip(c, 70, primary_rect, "Writes the current draft to disk.")
	ui.skip(&s, 24)

	disabled_rect := ui.next(&s, CONTROL_H)
	disabled_primary := ui.Rect{disabled_rect.x, disabled_rect.y, BUTTON_W, disabled_rect.h}
	ui.button(c, 71, disabled_primary, "Publish", true)
	ui.tooltip(c, 71, disabled_primary, "Fill in the author field first.")
	ui.skip(&s, 24)

	badge_rect := ui.next(&s, 28)
	badge := ui.Rect{badge_rect.x, badge_rect.y, 160, 28}
	ui.box(c, badge, ui.palette(c).surface_raised, 14)
	ui.label_in(
		c,
		badge,
		"? what is auto-save",
		13,
		.Center,
		.Center,
		color = ui.palette(c).text_muted,
	)
	ui.tooltip(c, 72, badge, "Auto-save writes to a draft copy every 30 seconds.")
	ui.skip(&s, 44)

	body := ui.type_scale(c).body
	ui.label_in(c, ui.next(&s, body), fmt.tprintf("Saved %d times", tooltips_counter), body)
}
