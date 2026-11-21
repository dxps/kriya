package main
import "core:fmt"
import ui "kriya:ui"

accent_choice: int = 1
radios_read_only: bool

// Three radios share a single int. Container y=270 matches the
// first-control top used by the sibling checkboxes / toggles views;
// skips carry the same visual rhythm — control (18) / skip 22 /
// control (18) / skip 22 / control (18) / skip 69 / status (17) /
// skip 32 / read-only (18).
draw_radios :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W, 240}, gap = 0)

	ui.radio(c, 10, ui.next(&s, 18), "Red", &accent_choice, 0, read_only = radios_read_only)
	ui.skip(&s, 22)
	ui.radio(c, 11, ui.next(&s, 18), "Green", &accent_choice, 1, read_only = radios_read_only)
	ui.skip(&s, 22)
	ui.radio(c, 12, ui.next(&s, 18), "Blue", &accent_choice, 2, read_only = radios_read_only)
	ui.skip(&s, 69)

	accents := []string{"Red", "Green", "Blue"}
	ui.label_in(
		c,
		ui.next(&s, 17),
		fmt.tprintf("Selected accent: %s", accents[accent_choice]),
		17,
	)
	ui.skip(&s, 32)

	ui.toggle(c, 13, ui.next(&s, 18), "Read-only", &radios_read_only)
}
