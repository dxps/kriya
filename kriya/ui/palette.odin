package ui

Palette :: struct {
    surface, surface_raised, overlay, overlay_border: Color,
    primary, primary_hover, primary_pressed, primary_bright: Color,
    border, border_hover, divider: Color,
    text, text_muted, text_on_primary, text_subtle: Color,
    item_selected, item_hover: Color,
    disabled: Color,
    scroll_track, scroll_thumb: Color,
}

DEFAULT_PALETTE :: Palette{
    surface         = {0.075, 0.105, 0.125, 1},
    surface_raised  = {0.10,  0.14,  0.17,  1},
    overlay         = {0.12,  0.16,  0.18,  1},
    overlay_border  = {0.22,  0.30,  0.33,  1},
    primary         = {0.20,  0.67,  0.57,  1},
    primary_hover   = {0.29,  0.78,  0.66,  1},
    primary_pressed = {0.14,  0.48,  0.42,  1},
    primary_bright  = {0.32,  0.83,  0.69,  1},
    border          = {0.25,  0.34,  0.38,  1},
    border_hover    = {0.36,  0.48,  0.52,  1},
    divider         = {0.20,  0.27,  0.30,  1},
    text            = {0.84,  0.89,  0.92,  1},
    text_muted      = {0.47,  0.56,  0.61,  1},
    text_on_primary = {0.06,  0.11,  0.12,  1},
    text_subtle     = {0.57,  0.66,  0.69,  1},
    item_selected   = {0.15,  0.25,  0.24,  1},
    item_hover      = {0.18,  0.31,  0.29,  1},
    disabled        = {0.20,  0.25,  0.28,  1},
    scroll_track    = {0.26,  0.34,  0.37,  1},
    scroll_thumb    = {0.42,  0.69,  0.64,  1},
}
