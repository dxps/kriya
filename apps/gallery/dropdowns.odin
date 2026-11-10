package main
import "core:fmt"
import ui "kriya:ui"

framework_options := []string{"Odin", "C", "Rust"}
framework_dropdown := ui.Dropdown {
	selected = 0,
}

draw_dropdowns :: proc(c: ^ui.Context) {
	ui.label(c, 302, 250, "LANGUAGE", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.dropdown(c, 30, {302, 266, 360, 46}, framework_options, &framework_dropdown)
	ui.label(
		c,
		302,
		346,
		fmt.tprintf("Selected value: %s", framework_options[framework_dropdown.selected]),
		17,
	)
}
