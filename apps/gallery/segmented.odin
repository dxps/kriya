package main
import "core:fmt"
import ui "kriya:ui"

alignment_choice: int = 1
view_choice: int = 0
segmented_read_only: bool

// Two segmented controls (3-way and 4-way), a status readout and the
// read-only toggle. Container y=270 preserves the first-control top
// used by sibling controls; field_h() keeps the strip proportional to
// the live padding.
draw_segmented :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W, 260}, gap = 0)

	alignment_opts := []string{"Left", "Center", "Right"}
	ui.segmented(
		c,
		20,
		ui.next(&s, field_h()),
		alignment_opts,
		&alignment_choice,
		read_only = segmented_read_only,
	)
	ui.skip(&s, 20)

	view_opts := []string{"List", "Grid", "Cards", "Compact"}
	ui.segmented(
		c,
		21,
		ui.next(&s, field_h()),
		view_opts,
		&view_choice,
		read_only = segmented_read_only,
	)
	ui.skip(&s, 34)

	body := ui.type_scale(c).body
	ui.label_in(
		c,
		ui.next(&s, body),
		fmt.tprintf("Alignment: %s · View: %s", alignment_opts[alignment_choice], view_opts[view_choice]),
		body,
	)
	ui.skip(&s, 32)

	ui.toggle(c, 22, ui.next(&s, 18), "Read-only", &segmented_read_only)
}
