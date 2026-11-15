package main
import "core:fmt"
import ui "kriya:ui"

framework_options := []string{"Odin", "C", "Rust"}
framework_dropdown := ui.Dropdown {
	selected = 0,
}
country_options := []string {
	"Argentina",
	"Australia",
	"Brazil",
	"Canada",
	"France",
	"Germany",
	"India",
	"Italy",
	"Japan",
	"Mexico",
	"Netherlands",
	"Norway",
	"Portugal",
	"Romania",
	"Spain",
	"Sweden",
	"United Kingdom",
	"United States",
}
country_dropdown := ui.Dropdown {
	selected = -1,
}
dropdowns_read_only: bool

draw_dropdowns :: proc(c: ^ui.Context) {
	ui.label(c, WIDGET_X, 250, "LANGUAGE", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.dropdown(
		c,
		30,
		{WIDGET_X, 266, INPUT_W, CONTROL_H},
		framework_options,
		&framework_dropdown,
		read_only = dropdowns_read_only,
	)
	ui.label(
		c,
		WIDGET_X,
		346,
		fmt.tprintf("Selected value: %s", framework_options[framework_dropdown.selected]),
		17,
	)
	ui.label(c, WIDGET_X, 400, "COUNTRY (SEARCHABLE)", 11, ui.DEFAULT_PALETTE.text_muted)
	ui.dropdown(
		c,
		32,
		{WIDGET_X, 416, INPUT_W, CONTROL_H},
		country_options,
		&country_dropdown,
		placeholder = "Pick a country",
		read_only = dropdowns_read_only,
		searchable = true,
		max_visible = 6,
	)
	ui.toggle(c, 31, WIDGET_X, 496, "Read-only", &dropdowns_read_only)
}
