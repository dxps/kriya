package main
import "core:fmt"
import ui "kriya:ui"

confirm_modal: ui.Modal
delete_count: int
cancel_count: int

// A single button opens a confirmation dialog; the counter underneath
// shows how many times each outcome has been picked. modal() returns
// the clicked action's index — this view matches on 1 ("Delete") so
// the "Cancel" button (index 0) just closes without side effects.
draw_modals :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 260, INPUT_W, 320}, gap = 0)

	open_slot := ui.next(&s, CONTROL_H)
	if ui.button(c, 80, {open_slot.x, open_slot.y, 180, open_slot.h}, "Delete item…") {
		confirm_modal.open = true
	}
	ui.skip(&s, 24)

	body := ui.type_scale(c).body
	ui.label_in(
		c,
		ui.next(&s, body),
		fmt.tprintf("Confirmed: %d · Cancelled: %d", delete_count, cancel_count),
		body,
	)

	switch ui.modal(
		c,
		81,
		"Delete this item?",
		"This action cannot be undone. The item and its associated data will be removed permanently.",
		[]string{"Cancel", "Delete"},
		&confirm_modal,
	) {
	case 0:
		cancel_count += 1
	case 1:
		delete_count += 1
	}
}
