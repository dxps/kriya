package main
import "../../routes"
import ui "kriya:ui"

// preview_h is the height of the preview card for this view; 0 falls back
// to PREVIEW_H so most views don't have to care. Set it larger when the
// view stacks multiple widgets and the default card feels cramped.
View :: struct {
	draw:      proc(c: ^ui.Context),
	source:    string,
	preview_h: f32,
}

views := [?]View {
	{draw_buttons, "apps/gallery/buttons.odin", 0},
	{draw_inputs, "apps/gallery/inputs.odin", 0},
	{draw_textareas, "apps/gallery/textareas.odin", 470},
	{draw_dropdowns, "apps/gallery/dropdowns.odin", 0},
	{draw_checkboxes, "apps/gallery/checkboxes.odin", 0},
	{draw_toggles, "apps/gallery/toggles.odin", 0},
	{draw_typography, "apps/gallery/typography.odin", 0},
	{draw_composition, "apps/gallery/composition.odin", 0},
}
view_scroll: [len(views)]ui.Scroll_State
#assert(len(views) == len(routes.SECTIONS))
