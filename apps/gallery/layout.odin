package main

import ui "kriya:ui"

// Sidebar column (left rail).
SIDEBAR_W           :: f32(230)
SIDEBAR_TEXT_X      :: f32(28)
SIDEBAR_BRAND_Y     :: f32(52)
SIDEBAR_KICKER_Y    :: f32(82) // "COMPONENT WORKSHOP"
SIDEBAR_GROUP_Y     :: f32(140) // "FOUNDATIONS / 01"
SIDEBAR_LINKS_Y     :: f32(164)
SIDEBAR_LINK_X      :: f32(24)
SIDEBAR_LINK_W      :: f32(182)
SIDEBAR_LINK_H      :: f32(36)
SIDEBAR_LINK_STRIDE :: f32(44)

// Right pane (page column), anchored at CONTENT_X with the preview card inside.
CONTENT_X     :: f32(274)
PAGE_EYEBROW_Y :: f32(52) // "LIBRARY / EXPLORER"
PAGE_TITLE_Y   :: f32(110)
PAGE_SUB_Y     :: f32(146)

// Preview card: an inner panel whose own content starts at WIDGET_X.
PREVIEW_X             :: CONTENT_X
PREVIEW_Y             :: f32(184)
PREVIEW_H             :: f32(350)
PREVIEW_MIN_W         :: f32(420)
PREVIEW_MARGIN_RIGHT  :: f32(44)
PREVIEW_PAD_X         :: f32(28)
PREVIEW_HEADER_Y      :: f32(220) // "INTERACTIVE PREVIEW"
WIDGET_X              :: PREVIEW_X + PREVIEW_PAD_X // 302

// Source hint sits a fixed gap below the preview card, whose height is
// per-view, so the exact y is computed by the caller.
SOURCE_HINT_GAP :: f32(26)

// Shared control metrics used by every view.
CONTROL_H :: f32(46)
BUTTON_W  :: f32(162)
INPUT_W   :: f32(360)

// Field height for text widgets (input, dropdown, textarea trigger) grows
// with the live padding so the box stays proportional. 2 * pad for top /
// bottom insets plus ~18 px for a 17pt glyph; equals CONTROL_H at the
// default padding of 14.
field_h :: proc() -> f32 {return 2 * configured_padding() + 18}

// Opens a captioned-field group inside a column stack: emits an 11 pt
// muted caption slot, skips 8 px, then returns the field_h()-tall slot
// for the widget. The caller plugs the returned rect into whichever
// field they're drawing — dropdown, input, something else — which keeps
// the widget's own options (searchable, password, read_only) out of the
// helper. The post-field skip stays at the call site since each group
// tunes it differently.
field_group :: proc(c: ^ui.Context, s: ^ui.Stack, caption: string) -> ui.Rect {
	ts := ui.type_scale(c)
	sp := ui.spacing(c)
	ui.label_in(c, ui.next(s, ts.caption), caption, ts.caption, color = ui.palette(c).text_muted)
	ui.skip(s, sp.sm)
	return ui.next(s, field_h())
}
