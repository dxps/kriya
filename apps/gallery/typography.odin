package main
import ui "kriya:ui"

// A type specimen's spacing is driven by chosen baselines, not by slots;
// the conversion still expresses the top-down sequence, and the skips
// reproduce the original baseline gaps (48, 46, 36).
draw_typography :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 244, INPUT_W, 220}, gap = 0)

	ui.label_in(c, ui.next(&s, 48), "Work Sans", 48)
	ui.skip(&s, 18)
	ui.label_in(c, ui.next(&s, 24), "A clear voice for everyday interfaces.", 24)
	ui.skip(&s, 27)
	ui.label_in(c, ui.next(&s, 18), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 18)
	ui.skip(&s, 18)
	ui.label_in(c, ui.next(&s, 18), "abcdefghijklmnopqrstuvwxyz 0123456789", 18)
}
