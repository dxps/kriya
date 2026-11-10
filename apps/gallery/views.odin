package main
import "../../routes"
import ui "kriya:ui"

View :: struct {
	draw:   proc(c: ^ui.Context),
	source: string,
}

views := [?]View {
	{draw_buttons, "apps/gallery/buttons.odin"},
	{draw_inputs, "apps/gallery/inputs.odin"},
	{draw_dropdowns, "apps/gallery/dropdowns.odin"},
	{draw_checkboxes, "apps/gallery/checkboxes.odin"},
	{draw_toggles, "apps/gallery/toggles.odin"},
	{draw_typography, "apps/gallery/typography.odin"},
	{draw_composition, "apps/gallery/composition.odin"},
}
view_scroll: [len(views)]ui.Scroll_State
#assert(len(views) == len(routes.SECTIONS))
