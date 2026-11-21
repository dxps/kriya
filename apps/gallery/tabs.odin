package main
import ui "kriya:ui"

tab_choice: int = 0
tabs_read_only: bool

// Four-tab strip that switches the wrapping body copy underneath — the
// pattern you'd use for a settings pane or a profile page. Container
// y=260; strip height 40, then the body paragraph fills three wrapped
// lines before the read-only toggle.
draw_tabs :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 260, INPUT_W, 300}, gap = 0)

	tab_opts := []string{"Overview", "Activity", "Members", "Settings"}
	ui.tabs(c, 40, ui.next(&s, 40), tab_opts, &tab_choice, read_only = tabs_read_only)
	ui.skip(&s, 20)

	body := ui.type_scale(c).body
	bodies := []string {
		"Project overview: twelve open issues and three pull requests waiting on review this week.",
		"Recent activity: eight commits in the last seven days, two new contributors joined.",
		"Seven members on this project; three have been active in the last twenty-four hours.",
		"Project settings: notifications on, auto-archive after 90 days, protected default branch.",
	}
	ui.label_wrap(c, ui.next(&s, 3 * ui.line_height(body)), bodies[tab_choice], body)
	ui.skip(&s, 40)

	ui.toggle(c, 41, ui.next(&s, 18), "Read-only", &tabs_read_only)
}
