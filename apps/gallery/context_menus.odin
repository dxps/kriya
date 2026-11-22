package main
import "core:fmt"
import ui "kriya:ui"

context_menu_state: ui.Context_Menu
context_menu_last: int = -1

context_menu_items := [?]string {
	"Open",
	"Open in new tab",
	"", // divider
	"Copy",
	"Cut",
	"Paste",
	"", // divider
	"Delete",
}

// A dashed demo zone catches right-clicks and opens the popup at the
// cursor. The index of the last-clicked item is kept in a module var
// so the view can echo "Last pick: Copy" under the zone, same shape
// as modal's outcome counters.
draw_context_menus :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W + 60, 320}, gap = 0)

	ui.label_in(
		c,
		ui.next(&s, 11),
		"RIGHT-CLICK INSIDE THE ZONE",
		11,
		color = ui.palette(c).text_muted,
	)
	ui.skip(&s, 10)

	zone := ui.next(&s, 160)
	pal := ui.palette(c)
	ui.box(c, zone, pal.surface_raised, ui.DEFAULT_CORNER_RADIUS)
	ui.label_in(
		c,
		zone,
		"Right-click anywhere here",
		18,
		.Center,
		.Center,
		color = pal.text_muted,
	)

	// Fire the menu on a right-press that lands inside the zone.
	// c.right_pressed is a one-shot flag set by the host's event
	// handler on MOUSE_DOWN with the right button.
	if c.right_pressed && ui.point_in_rect(c.mx, c.my, zone) {
		ui.open_context_menu(&context_menu_state, c.mx, c.my)
	}

	ui.skip(&s, 24)
	body := ui.type_scale(c).body
	label: string
	if context_menu_last < 0 {
		label = "Last pick: — (right-click the zone above)"
	} else {
		label = fmt.tprintf("Last pick: %s", context_menu_items[context_menu_last])
	}
	ui.label_in(c, ui.next(&s, body), label, body, color = pal.text_muted)

	if idx := ui.context_menu(c, 1500, context_menu_items[:], &context_menu_state); idx >= 0 {
		context_menu_last = idx
	}
}
