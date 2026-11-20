package main

import web "../../backends/web"
import "../../routes"
import ui "kriya:ui"

sidebar_link :: proc(c: ^ui.Context, id: u64, r: ui.Rect, text: string, active: bool) -> bool {
	hover, clicked := ui.pressable(c, id, r)
	pal := ui.palette(c)
	color := pal.text_muted
	if active {color = pal.primary_bright}
	if hover {
		background := pal.item_hover
		if c.active == id && c.down {background = pal.item_selected}
		ui.box(c, r, background, ui.DEFAULT_CORNER_RADIUS)
		color = pal.text
	}
	if c.active == id && c.down {color = pal.primary}
	if active {ui.box(c, {r.x + 4, r.y + 10, 2, 16}, pal.primary_bright, 1)}
	ui.label(c, r.x + 18, r.y + 24, text, 18, color)
	return clicked
}

draw_sidebar :: proc(h: f32) {
	pal := ui.palette(&ctx)
	ui.box(&ctx, {0, 0, SIDEBAR_W, h}, pal.surface_raised)
	ui.label(&ctx, SIDEBAR_TEXT_X, SIDEBAR_BRAND_Y, "kriya", 36, pal.primary_bright)
	ui.label(&ctx, SIDEBAR_TEXT_X, SIDEBAR_KICKER_Y, "COMPONENT WORKSHOP", 12)
	ui.label(&ctx, SIDEBAR_TEXT_X, SIDEBAR_GROUP_Y, "FOUNDATIONS / 01", 12, pal.text_muted)
	for section, i in routes.SECTIONS {
		y := SIDEBAR_LINKS_Y + f32(i) * SIDEBAR_LINK_STRIDE
		if sidebar_link(&ctx, u64(100 + i), {SIDEBAR_LINK_X, y, SIDEBAR_LINK_W, SIDEBAR_LINK_H}, section.title, selected == i) {
			selected = i
			web.kriya_navigate(section.path)
		}
	}
}
