package main
import "core:fmt"
import ui "kriya:ui"

breadcrumb_path := [?]string{"Home", "Settings", "Profile", "Security"}
breadcrumb_clicked: int = -1

// A single breadcrumb row. Clicking any crumb but the last stores
// its index so the view can echo "Clicked: X" underneath — the same
// pattern modals uses to show which action a dialog returned.
draw_breadcrumbs :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W + 80, 160}, gap = 0)

	trail := ui.next(&s, 24)
	if idx := ui.breadcrumbs(c, 1200, trail, breadcrumb_path[:]); idx >= 0 {
		breadcrumb_clicked = idx
	}
	ui.skip(&s, 28)

	body := ui.type_scale(c).body
	label: string
	if breadcrumb_clicked < 0 {
		label = "Clicked: — (last crumb is inert)"
	} else {
		label = fmt.tprintf("Clicked: %s (index %d)", breadcrumb_path[breadcrumb_clicked], breadcrumb_clicked)
	}
	ui.label_in(c, ui.next(&s, body), label, body, color = ui.palette(c).text_muted)
}
