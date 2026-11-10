package main
import "core:fmt"
import ui "kriya:ui"

framework_options := []string{"Odin", "C", "Rust"}
framework_dropdown := ui.Dropdown {
	selected = 0,
}

draw_dropdowns :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "LANGUAGE", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.dropdown(c, 30, {WIDGET_X, 266, INPUT_W, CONTROL_H}, framework_options, &framework_dropdown)
	ui.label(
		c,
		WIDGET_X,
		346,
		fmt.tprintf("Selected value: %s", framework_options[framework_dropdown.selected]),
		17,
	)
}
