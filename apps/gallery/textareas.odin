package main
import ui "kriya:ui"

notes: ui.Text_Area
wrapped_notes: ui.Text_Area

init_textarea_examples :: proc() {
	ui.set_area_text(
		&notes,
		"Multi-line input.\nEnter inserts a newline.\nBackspace removes a rune.\nScroll with the wheel, or shift-wheel for horizontal; drag the scrollbar thumbs.\nContent that doesn't fit is clipped.\nThe caret is pulled back into view when you type.\nTry adding a few more lines.\nLine eight.\nLine nine.",
	)
	ui.set_area_text(
		&wrapped_notes,
		"Soft wrap breaks long lines at word boundaries so paragraphs fit the width of the box without horizontal scrolling. Nav keys walk visual lines: Down moves to the next wrapped row, Home goes to the row's start.",
	)
}

draw_textareas :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "NO WRAP", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.textarea(c, 30, {WIDGET_X, 266, INPUT_W, 160}, "Jot something down", &notes)
	ui.label(c, WIDGET_X, 452, "WRAPPED", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.textarea(c, 31, {WIDGET_X, 468, INPUT_W, 150}, "Paragraph", &wrapped_notes, wrap = true)
}
