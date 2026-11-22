package ui

// 1 px separator strip between blocks of content. Purely visual: no id,
// no hit test, no corner radius — sharp edges read as a rule, not a
// shape. The rect's aspect carries the orientation: a wide-thin rect
// is horizontal, a tall-thin one is vertical, so callers position it
// with the same ui.row / ui.col vocabulary every other widget uses
// instead of a dedicated axis parameter.
//
// Colored by palette(c).divider — the token already shared with the
// sidebar rule and scroll track, so a divider sits in the same key as
// its neighbors across both themes.
divider :: proc(c: ^Context, r: Rect) {
	box(c, r, palette(c).divider)
}
