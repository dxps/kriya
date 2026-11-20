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
