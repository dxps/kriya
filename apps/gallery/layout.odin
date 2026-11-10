package main

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

// Source hint sits a fixed gap below the preview card.
SOURCE_HINT_GAP :: f32(26)
SOURCE_HINT_Y   :: PREVIEW_Y + PREVIEW_H + SOURCE_HINT_GAP // 560

// Shared control metrics used by every view.
CONTROL_H :: f32(46)
BUTTON_W  :: f32(162)
INPUT_W   :: f32(360)
