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

// Order must match routes.SECTIONS so views[selected] addresses the
// right gallery view. Comments mirror the group boundaries in routes.
views := [?]View {
	// Widgets
	{draw_buttons, "apps/gallery/buttons.odin", 0},
	{draw_inputs, "apps/gallery/inputs.odin", 0},
	{draw_textareas, "apps/gallery/textareas.odin", 500},
	{draw_dropdowns, "apps/gallery/dropdowns.odin", 0},
	{draw_checkboxes, "apps/gallery/checkboxes.odin", 0},
	{draw_toggles, "apps/gallery/toggles.odin", 0},
	{draw_sliders, "apps/gallery/sliders.odin", 540},
	{draw_progress, "apps/gallery/progress.odin", 0},
	{draw_tooltips, "apps/gallery/tooltips.odin", 0},
	{draw_modals, "apps/gallery/modals.odin", 0},
	{draw_radios, "apps/gallery/radios.odin", 0},
	{draw_segmented, "apps/gallery/segmented.odin", 0},
	{draw_tabs, "apps/gallery/tabs.odin", 0},
	{draw_badges, "apps/gallery/badges.odin", 0},
	{draw_avatars, "apps/gallery/avatars.odin", 0},
	{draw_dividers, "apps/gallery/dividers.odin", 0},
	{draw_chips, "apps/gallery/chips.odin", 0},
	{draw_accordions, "apps/gallery/accordions.odin", 500},
	{draw_breadcrumbs, "apps/gallery/breadcrumbs.odin", 0},
	{draw_toasts, "apps/gallery/toasts.odin", 0},
	// System
	{draw_typography, "apps/gallery/typography.odin", 0},
	{draw_composition, "apps/gallery/composition.odin", 0},
	{draw_setup, "apps/gallery/setup.odin", 420},
}
view_scroll: [len(views)]ui.Scroll_State
#assert(len(views) == len(routes.SECTIONS))
