package ui

// A theme bundles the look-and-feel values a widget reads at draw time.
// For now Theme wraps only Palette; a follow-up adds Spacing, Type_Scale
// and Radii so numeric literals can migrate too. Keeping the wrapper
// around a single field lets the API stabilize before the scales land.
Theme :: struct {
	palette: Palette,
}

// Package-level defaults. Package vars (not consts) so Context can hold
// a pointer to one — Odin forbids taking the address of a constant.
// Users wanting a bespoke theme set `c.theme` to a Theme they own.
DARK_THEME: Theme = {palette = DARK_PALETTE}
LIGHT_THEME: Theme = {palette = LIGHT_PALETTE}

// Sets the theme pointer. nil restores the implicit DARK_THEME default.
set_theme :: proc(c: ^Context, t: ^Theme) {c.theme = t}

// Looks up the active palette. Widgets call this instead of referring
// to a hard-coded const so colors flow from whatever theme the host has
// set. Nil theme pointer resolves to DARK_THEME.
palette :: proc(c: ^Context) -> Palette {
	if c.theme == nil {return DARK_THEME.palette}
	return c.theme.palette
}
