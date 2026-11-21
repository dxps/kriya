#+build !wasm32
package ui
import "core:testing"

@(test)
palette_defaults_to_dark_when_no_theme_set :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	p := palette(&c)
	testing.expect(t, p == DARK_PALETTE)
}

@(test)
set_theme_switches_resolved_palette :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)

	set_theme(&c, &LIGHT_THEME)
	testing.expect(t, palette(&c) == LIGHT_PALETTE)

	set_theme(&c, &DARK_THEME)
	testing.expect(t, palette(&c) == DARK_PALETTE)

	// Nil clears back to the implicit default.
	set_theme(&c, nil)
	testing.expect(t, palette(&c) == DARK_PALETTE)
}

@(test)
label_default_color_resolves_to_theme_text :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)

	label(&c, 0, 20, "hi")
	cmd := c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.color == DARK_PALETTE.text)

	clear(&c.commands)
	set_theme(&c, &LIGHT_THEME)
	label(&c, 0, 20, "hi")
	cmd = c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.color == LIGHT_PALETTE.text)
}

@(test)
label_explicit_color_overrides_theme_default :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	red := Color{1, 0, 0, 1}
	label(&c, 0, 20, "hi", color = red)
	cmd := c.commands[0].variant.(Text_Command)
	testing.expect(t, cmd.color == red)
}

@(test)
scale_helpers_default_to_dark_theme :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	testing.expect(t, spacing(&c) == DEFAULT_SPACING)
	testing.expect(t, type_scale(&c) == DEFAULT_TYPE_SCALE)
	testing.expect(t, radii(&c) == DEFAULT_RADII)
}

@(test)
scale_helpers_follow_set_theme :: proc(t: ^testing.T) {
	c: Context
	defer delete(c.commands)
	custom := Theme {
		palette    = DARK_PALETTE,
		spacing    = Spacing{xs = 2, sm = 4, md = 6, lg = 10, xl = 16},
		type_scale = Type_Scale{caption = 8, body = 12, label = 13, title = 18, display = 32},
		radii      = Radii{sharp = 0, sm = 2, md = 4, lg = 8, xl = 14},
	}
	set_theme(&c, &custom)
	testing.expect(t, spacing(&c).md == 6)
	testing.expect(t, type_scale(&c).caption == 8)
	testing.expect(t, radii(&c).lg == 8)
}

@(test)
dark_and_light_themes_share_scale_defaults :: proc(t: ^testing.T) {
	// Palette differs by theme; the scales are identical by default so a
	// dark→light switch doesn't reflow the layout.
	testing.expect(t, DARK_THEME.spacing == LIGHT_THEME.spacing)
	testing.expect(t, DARK_THEME.type_scale == LIGHT_THEME.type_scale)
	testing.expect(t, DARK_THEME.radii == LIGHT_THEME.radii)
}
