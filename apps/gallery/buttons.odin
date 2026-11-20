package main
import "core:fmt"
import ui "kriya:ui"

button_count: int

// Outer column holds the button row and the two status lines; a nested row
// distributes the pair of buttons 18 px apart inside the row's slot.
// Container y=258 preserves the original button top; the skips below
// reproduce the original 34 px / 25 px visual gaps.
draw_buttons :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 258, INPUT_W, 160}, gap = 0)

	btn_row := ui.row(ui.next(&s, CONTROL_H), gap = 18)
	if ui.button(c, 1, ui.next(&btn_row, BUTTON_W), "Click me") {button_count += 1}
	ui.button(c, 2, ui.next(&btn_row, BUTTON_W), "Disabled", true)
	ui.skip(&s, 34)

	ui.label_in(
		c,
		ui.next(&s, 24),
		fmt.tprintf("Button pressed %d times", button_count),
		24,
	)
	ui.skip(&s, 25)
	ui.label_in(c, ui.next(&s, 17), "Hover, press and release to explore each state.", 17)
}
