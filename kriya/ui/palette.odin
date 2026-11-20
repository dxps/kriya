package ui

Palette :: struct {
	surface, surface_raised, overlay, overlay_border:        Color,
	primary, primary_hover, primary_pressed, primary_bright: Color,
	border, border_hover, divider:                           Color,
	text, text_muted, text_on_primary, text_subtle:          Color,
	item_selected, item_hover:                               Color,
	disabled:                                                Color,
	scroll_track, scroll_thumb:                              Color,
	focus_ring:                                              Color,
}

// Dark palette: the project's original look. Deep teal surface, bright
// mint primary, off-white text. This is the default a Context resolves
// to when no theme is set.
DARK_PALETTE :: Palette {
	surface         = {0.075, 0.105, 0.125, 1},
	surface_raised  = {0.10, 0.14, 0.17, 1},
	overlay         = {0.12, 0.16, 0.18, 1},
	overlay_border  = {0.22, 0.30, 0.33, 1},
	primary         = {0.20, 0.67, 0.57, 1},
	primary_hover   = {0.29, 0.78, 0.66, 1},
	primary_pressed = {0.14, 0.48, 0.42, 1},
	primary_bright  = {0.32, 0.83, 0.69, 1},
	border          = {0.25, 0.34, 0.38, 1},
	border_hover    = {0.36, 0.48, 0.52, 1},
	divider         = {0.20, 0.27, 0.30, 1},
	text            = {0.84, 0.89, 0.92, 1},
	text_muted      = {0.47, 0.56, 0.61, 1},
	text_on_primary = {0.06, 0.11, 0.12, 1},
	text_subtle     = {0.57, 0.66, 0.69, 1},
	item_selected   = {0.15, 0.25, 0.24, 1},
	item_hover      = {0.18, 0.31, 0.29, 1},
	disabled        = {0.20, 0.25, 0.28, 1},
	scroll_track    = {0.26, 0.34, 0.37, 1},
	scroll_thumb    = {0.42, 0.69, 0.64, 1},
	focus_ring      = {0.46, 0.92, 0.80, 1},
}

// Light palette: near-white surface, deep teal primary, dark text. Hues
// are preserved from DARK_PALETTE where possible so a theme switch looks
// like the same family, not two unrelated designs.
LIGHT_PALETTE :: Palette {
	surface         = {0.97, 0.98, 0.99, 1},
	surface_raised  = {1.00, 1.00, 1.00, 1},
	overlay         = {0.96, 0.97, 0.98, 1},
	overlay_border  = {0.78, 0.84, 0.87, 1},
	primary         = {0.13, 0.54, 0.45, 1},
	primary_hover   = {0.18, 0.62, 0.52, 1},
	primary_pressed = {0.09, 0.42, 0.34, 1},
	primary_bright  = {0.11, 0.48, 0.40, 1},
	border          = {0.72, 0.78, 0.82, 1},
	border_hover    = {0.52, 0.60, 0.65, 1},
	divider         = {0.85, 0.89, 0.92, 1},
	text            = {0.10, 0.14, 0.17, 1},
	text_muted      = {0.40, 0.47, 0.52, 1},
	text_on_primary = {1.00, 1.00, 1.00, 1},
	text_subtle     = {0.28, 0.35, 0.40, 1},
	item_selected   = {0.84, 0.95, 0.92, 1},
	item_hover      = {0.92, 0.97, 0.95, 1},
	disabled        = {0.80, 0.84, 0.87, 1},
	scroll_track    = {0.72, 0.78, 0.82, 1},
	scroll_thumb    = {0.28, 0.60, 0.52, 1},
	focus_ring      = {0.20, 0.72, 0.60, 1},
}
