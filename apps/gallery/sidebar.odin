package main

import web "../../backends/web"
import "../../routes"
import ui "kriya:ui"

// One flag per routes.GROUPS entry, true = expanded. Defaults to all
// expanded; init_sidebar_state overrides from localStorage if a prior
// session saved something.
GROUP_COUNT :: len(routes.GROUPS)
group_expanded: [GROUP_COUNT]bool

SIDEBAR_STORAGE_KEY :: "kriya.sidebar.groups"

init_sidebar_state :: proc() {
	for i in 0 ..< GROUP_COUNT {group_expanded[i] = true}
	buf: [GROUP_COUNT]u8
	if web.kriya_storage_get(SIDEBAR_STORAGE_KEY, raw_data(buf[:]), GROUP_COUNT) == GROUP_COUNT {
		for i in 0 ..< GROUP_COUNT {group_expanded[i] = buf[i] == '1'}
	}
}

persist_sidebar_state :: proc() {
	buf: [GROUP_COUNT + 1]u8 // +1: kriya_storage_set wants a null-terminated cstring
	for i in 0 ..< GROUP_COUNT {buf[i] = group_expanded[i] ? '1' : '0'}
	buf[GROUP_COUNT] = 0
	web.kriya_storage_set(SIDEBAR_STORAGE_KEY, cstring(raw_data(buf[:])))
}

// Clickable group kicker: a disclosure triangle (▸ collapsed, ▾
// expanded) plus the group's label, same filled-triangle technique as
// the dropdown's open/closed arrow. The whole sidebar-width row is the
// hit target, not just the glyphs. Groups aren't a navigable
// destination, so unlike sidebar_link there's no 'active' state.
sidebar_group_header :: proc(c: ^ui.Context, id: u64, y: f32, title: string, expanded: bool) -> bool {
	hit := ui.Rect{0, y - 14, SIDEBAR_W, 20}
	hover, clicked := ui.pressable(c, id, hit)
	pal := ui.palette(c)
	color := hover ? pal.text_subtle : pal.text_muted

	// The collapsed (right-pointing) shape is the expanded (down-pointing)
	// one rotated 90°: both are the same two base points 4px either side
	// of center plus an apex 4px out the other axis, so they're congruent
	// and neither reads as smaller than the other.
	cx := SIDEBAR_TEXT_X - 10
	cy := y - 3
	if expanded {
		ui.triangle(c, cx - 4, cy - 4, cx + 4, cy - 4, cx, cy + 4, color)
	} else {
		ui.triangle(c, cx - 4, cy - 4, cx - 4, cy + 4, cx + 4, cy, color)
	}
	ui.label(c, SIDEBAR_TEXT_X, y, title, 12, color)
	return clicked
}

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

// The groups region scrolls independently of the brand header, so the
// sidebar scales with the number of sections. One ui.Scroll_State lives
// here to remember the sidebar's own offset across frames, separate
// from the main view's scroll.
sidebar_scroll: ui.Scroll_State

// Walks routes.GROUPS inside a dedicated scroll viewport, emitting a
// clickable kicker header per group, followed by its sections' links
// when the group is expanded. 'y' tracks the next kicker baseline
// between groups and the current link top inside them; the arithmetic
// at the group boundary converts the last link's top into its bottom so
// the group-to-group gap is measured from where the strip actually
// ends, not where the loop happened to park the cursor. A collapsed
// group simply leaves y at its own header line, so the next group's
// SIDEBAR_GROUP_GAP follows right after it.
draw_sidebar :: proc(h: f32) {
	pal := ui.palette(&ctx)
	ui.box(&ctx, {0, 0, SIDEBAR_W, h}, pal.surface_raised)
	ui.label(&ctx, SIDEBAR_TEXT_X, SIDEBAR_BRAND_Y, "kriya", 36, pal.primary_bright)
	ui.label(&ctx, SIDEBAR_TEXT_X, SIDEBAR_KICKER_Y, "COMPONENT WORKSHOP", 12)

	viewport := ui.Rect{0, SIDEBAR_SCROLL_Y, SIDEBAR_W, max(0, h - SIDEBAR_SCROLL_Y)}
	ui.begin_scroll(&ctx, &sidebar_scroll, viewport, ctx.dt)

	sections := routes.SECTIONS
	y: f32 = SIDEBAR_GROUPS_Y
	for group, g in routes.GROUPS {
		if g > 0 {y += SIDEBAR_GROUP_GAP}
		if sidebar_group_header(&ctx, u64(200 + g), y, group.title, group_expanded[g]) {
			group_expanded[g] = !group_expanded[g]
			persist_sidebar_state()
		}
		if group_expanded[g] {
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

	ui.end_scroll(&ctx, &sidebar_scroll)
}
