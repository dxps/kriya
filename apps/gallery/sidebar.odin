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

// Walks routes.GROUPS, emitting a kicker label per group followed by
// its sections' links. 'y' tracks the next kicker baseline between
// groups and the current link top inside them; the arithmetic at the
// group boundary converts the last link's top into its bottom so the
// group-to-group gap is measured from where the strip actually ends,
// not where the loop happened to park the cursor.
draw_sidebar :: proc(h: f32) {
	pal := ui.palette(&ctx)
	ui.box(&ctx, {0, 0, SIDEBAR_W, h}, pal.surface_raised)
	ui.label(&ctx, SIDEBAR_TEXT_X, SIDEBAR_BRAND_Y, "kriya", 36, pal.primary_bright)
	ui.label(&ctx, SIDEBAR_TEXT_X, SIDEBAR_KICKER_Y, "COMPONENT WORKSHOP", 12)

	sections := routes.SECTIONS
	y: f32 = SIDEBAR_GROUPS_Y
	for group, g in routes.GROUPS {
		if g > 0 {y += SIDEBAR_GROUP_GAP}
		ui.label(&ctx, SIDEBAR_TEXT_X, y, group.title, 12, pal.text_muted)
		links_top := y + SIDEBAR_KICKER_TO_LINK
		for j in 0 ..< group.count {
			i := group.start + j
			link_y := links_top + f32(j) * SIDEBAR_LINK_STRIDE
			section := sections[i]
			if sidebar_link(
				&ctx,
				u64(100 + i),
				{SIDEBAR_LINK_X, link_y, SIDEBAR_LINK_W, SIDEBAR_LINK_H},
				section.title,
				selected == i,
			) {
				selected = i
				web.kriya_navigate(section.path)
			}
		}
		// Advance y to the bottom of the last link so the next group's
		// SIDEBAR_GROUP_GAP is measured from a visually meaningful edge.
		y = links_top + f32(group.count - 1) * SIDEBAR_LINK_STRIDE + SIDEBAR_LINK_H
	}
}
