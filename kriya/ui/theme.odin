package ui

// A theme bundles the look-and-feel values a widget reads at draw time:
// palette (colors), spacing (gaps and paddings), type_scale (named font
// sizes) and radii (named corner radii). Widgets look values up via
// palette(c) / spacing(c) / type_scale(c) / radii(c) so a theme swap is
// one `set_theme` call away.

Spacing :: struct {
	xs, sm, md, lg, xl: f32,
}

Type_Scale :: struct {
	caption, body, label, title, display: f32,
}

Radii :: struct {
	sharp, sm, md, lg, xl: f32,
}

Theme :: struct {
	palette:    Palette,
	spacing:    Spacing,
	type_scale: Type_Scale,
	radii:      Radii,
}

// Default scale constants — exported so callers wanting the raw values
// outside a Context (compile-time constants, static tables) can reach
// them without going through the resolver.
DEFAULT_SPACING :: Spacing{xs = 4, sm = 8, md = 12, lg = 20, xl = 32}
DEFAULT_TYPE_SCALE :: Type_Scale{caption = 11, body = 17, label = 18, title = 24, display = 48}
DEFAULT_RADII :: Radii{sharp = 0, sm = 4, md = 6, lg = 10, xl = 16}

// Package-level defaults. Package vars (not consts) so Context can hold
// a pointer to one — Odin forbids taking the address of a constant.
// Users wanting a bespoke theme set `c.theme` to a Theme they own.
DARK_THEME: Theme = {
	palette    = DARK_PALETTE,
	spacing    = DEFAULT_SPACING,
	type_scale = DEFAULT_TYPE_SCALE,
	radii      = DEFAULT_RADII,
}
LIGHT_THEME: Theme = {
	palette    = LIGHT_PALETTE,
	spacing    = DEFAULT_SPACING,
	type_scale = DEFAULT_TYPE_SCALE,
	radii      = DEFAULT_RADII,
}

// Sets the theme pointer. nil restores the implicit DARK_THEME default.
set_theme :: proc(c: ^Context, t: ^Theme) {c.theme = t}

// Scale resolvers: widgets call these instead of referring to hard-coded
// constants so sizes flow from whatever theme the host has set. Nil
// theme pointer resolves to DARK_THEME (all four resolvers share this
// default — themes always travel as a complete set).
palette :: proc(c: ^Context) -> Palette {
	if c.theme == nil {return DARK_THEME.palette}
	return c.theme.palette
}
spacing :: proc(c: ^Context) -> Spacing {
	if c.theme == nil {return DARK_THEME.spacing}
	return c.theme.spacing
}
type_scale :: proc(c: ^Context) -> Type_Scale {
	if c.theme == nil {return DARK_THEME.type_scale}
	return c.theme.type_scale
}
radii :: proc(c: ^Context) -> Radii {
	if c.theme == nil {return DARK_THEME.radii}
	return c.theme.radii
}
