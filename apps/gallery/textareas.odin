package main
import ui "kriya:ui"

notes: ui.Text_Area

init_textarea_examples :: proc() {
	ui.set_area_text(
		&notes,
		"Multi-line input.\nEnter inserts a newline.\nBackspace removes a rune.\nScroll with the wheel.\nContent that doesn't fit is clipped.\nThe caret is pulled back into view when you type.\nTry adding a few more lines.\nLine eight.\nLine nine.\nLine ten.",
	)
}

draw_textareas :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "NOTES", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.textarea(c, 30, {WIDGET_X, 266, INPUT_W, 160}, "Jot something down", &notes)
	ui.label(c, WIDGET_X, 452, "Scroll past the bottom; typing pulls the caret back in.", 17)
}
