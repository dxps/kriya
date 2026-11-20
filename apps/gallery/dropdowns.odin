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

// Two dropdown groups via field_group, separated by a selected-value
// readout (not a field — it's a size-17 body label, left inline), then
// a read-only toggle. Container y=242 puts the first caption baseline
// on the original 250.
draw_dropdowns :: proc(c: ^ui.Context) {
	s := ui.col({WIDGET_X, 242, INPUT_W, 300}, gap = 0)

	ui.dropdown(
		c,
		30,
		field_group(c, &s, "LANGUAGE"),
		framework_options,
		&framework_dropdown,
		read_only = dropdowns_read_only,
	)
	ui.skip(&s, 26)

	ui.label_in(
		c,
		ui.next(&s, 17),
		fmt.tprintf("Selected value: %s", framework_options[framework_dropdown.selected]),
		17,
	)
	ui.skip(&s, 42)

	ui.dropdown(
		c,
		32,
		field_group(c, &s, "COUNTRY (SEARCHABLE)"),
		country_options,
		&country_dropdown,
		placeholder = "Pick a country",
		read_only = dropdowns_read_only,
		searchable = true,
		max_visible = 6,
	)
	ui.skip(&s, 39)

	ui.toggle(c, 31, ui.next(&s, 18), "Read-only", &dropdowns_read_only)
}
