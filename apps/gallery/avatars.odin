package main
import ui "kriya:ui"

// Two rows: a size ladder in the subtle look (24 / 32 / 40 / 56 px —
// the span where initials stay legible), then an emphasis row of the
// same names at the middle size. The subtle row mixes single- and
// multi-word names so the gallery doubles as a visual spec for how
// initials() derives 1 vs 2 characters.
draw_avatars :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 270, INPUT_W, 220}, gap = 0)

	ui.label_in(c, ui.next(&s, 11), "SUBTLE", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)
	subtle_row := ui.row(ui.next(&s, 56), gap = 16)
	subtle_sizes := [4]f32{24, 32, 40, 56}
	subtle_names := [4]string{"Ana", "Marius Ileana", "Ana Popescu", "Ioana Radu"}
	for size, i in subtle_sizes {
		slot := ui.next(&subtle_row, size, size)
		// Align each tile to the baseline the largest one sits on so
		// the row reads as a scale rather than a staircase.
		slot.y = slot.y + (56 - size)
		ui.avatar(c, slot, subtle_names[i])
	}
	ui.skip(&s, 40)

	ui.label_in(c, ui.next(&s, 11), "EMPHASIS", 11, color = ui.palette(c).text_muted)
	ui.skip(&s, 10)
	emph_row := ui.row(ui.next(&s, 40), gap = 16)
	emph_names := [3]string{"Marius Ileana", "Ana Popescu", "Ștefan Ionescu"}
	for name in emph_names {
		ui.avatar(c, ui.next(&emph_row, 40, 40), name, emphasis = true)
	}
}
