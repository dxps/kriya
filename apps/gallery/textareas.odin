package main
import ui "kriya:ui"

notes: ui.Text_Area
wrapped_notes: ui.Text_Area
textareas_read_only: bool

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

// Two textareas (160 and 150 tall) with captions, then a read-only
// toggle. Container y=242 puts the first caption baseline on the
// original 250; textarea heights stay literal because they're a design
// choice, not a derived size.
draw_textareas :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 242, INPUT_W, 450}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "NO WRAP", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 8)
	ui.textarea(
		c,
		30,
		ui.next(&s, 160),
		"Jot something down",
		&notes,
		read_only = textareas_read_only,
	)
	ui.skip(&s, 23)

	ui.label_in(c, ui.next(&s, 11), "WRAPPED", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 8)
	ui.textarea(
		c,
		31,
		ui.next(&s, 150),
		"Paragraph",
		&wrapped_notes,
		wrap = true,
		read_only = textareas_read_only,
	)
	ui.skip(&s, 25)

	ui.toggle(c, 32, ui.next(&s, 18), "Read-only", &textareas_read_only)
}
