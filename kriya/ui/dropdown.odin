package ui

Dropdown :: struct {
	selected: int,
	open:     bool,
	// Backing buffer for the inline search field when the dropdown is
	// opened with searchable = true. Unused when searchable = false; the
	// zero value is a valid empty query, so callers pay no setup cost for
	// enabling search. Cleared on open and on select so each session starts
	// fresh.
	query:    Text_Input,
	// Scroll offset in pixels used when max_visible caps the menu shorter
	// than the option list. Clamped each frame against the current content
	// / view heights, so callers never have to worry about going stale
	// after filtering or option changes.
	scroll:   f32,
	dragging: bool,
	grab_y:   f32,
}

// Case-insensitive substring match for ASCII; non-ASCII bytes compare
// exactly. Empty query matches everything.
dropdown_match :: proc(option: string, query: []u8) -> bool {
	if len(query) == 0 {return true}
	if len(query) > len(option) {return false}
	for i in 0 ..= len(option) - len(query) {
		match := true
		for j in 0 ..< len(query) {
			a := option[i + j]
			b := query[j]
			if a >= 'A' && a <= 'Z' {a += 32}
			if b >= 'A' && b <= 'Z' {b += 32}
			if a != b {match = false; break}
		}
		if match {return true}
	}
	return false
}

dropdown :: proc(
	c: ^Context,
	id: u64,
	r: Rect,
	options: []string,
	value: ^Dropdown,
	placeholder: string = "",
	read_only := false,
	searchable := false,
	max_visible: int = 0,
	radius: Maybe(f32) = nil,
) {
	corner_radius := resolve_corner_radius(c, radius)
	assert(len(options) > 0, "Dropdowns require at least one option")
	// selected < 0 means "no value picked yet"; the trigger shows the
	// placeholder instead of an option, and no row is highlighted in the
	// menu. Clamp only the positive range so this sentinel survives a frame
	// when the caller didn't touch it.
	if value.selected >= 0 {
		value.selected = clamp(value.selected, 0, len(options) - 1)
	}
	// Read-only: the user can neither open the menu nor pick another
	// option. Collapse any previously-open menu first in case the flag
	// was flipped while it was showing.
	if read_only {value.open = false}
	// Precompute match indices for the current query so we can size the
	// menu and address rows by their visible position. An empty or non-
	// searchable query matches every option.
	search_id := sub_id(id, 0)
	query_bytes := searchable ? value.query.data[:value.query.len] : nil
	match_count := 0
	if value.open {
		for option in options {
			if dropdown_match(option, query_bytes) {match_count += 1}
		}
	}
	search_h: f32 = searchable ? 44 : 0
	row_h: f32 = 40
	menu_rows := searchable ? match_count : len(options)
	// max_visible caps how many rows the popup shows at once. 0 means
	// show every row; anything higher than the row count collapses back
	// to show-all. Overflow is reached by scrolling the popup, not the
	// page below.
	shown_rows := menu_rows
	if max_visible > 0 && max_visible < menu_rows {shown_rows = max_visible}
	menu_view_h := f32(shown_rows) * row_h
	menu_content_h := f32(menu_rows) * row_h
	max_scroll := max(0, menu_content_h - menu_view_h)
	menu := Rect{r.x, r.y + r.h, r.w, menu_view_h + 2 + search_h}
	if value.open && c.pressed && !contains(c, r) && !contains(c, menu) {
		value.open = false
		value.scroll = 0
		if searchable {set_text(&value.query, "")}
	}
	// Escape closes an open menu without picking anything. Consumed so a
	// stacked widget doesn't also react to it this frame.
	if value.open && c.cancel {
		value.open = false
		value.scroll = 0
		if searchable {set_text(&value.query, "")}
		c.cancel = false
	}
	hover: bool
	if !read_only {
		clicked: bool
		hover, clicked = pressable(c, id, r)
		if clicked {
			value.open = !value.open
			value.scroll = 0
			if searchable {
				set_text(&value.query, "")
				// Jump focus straight into the search field on open so the
				// user can start typing immediately; on close release it
				// so the next click doesn't look selected.
				c.focused = value.open ? search_id : 0
			}
		}
	}
	value.scroll = clamp(value.scroll, 0, max_scroll)
	// Read-only skips the hover / open border accents and uses a raised
	// inner surface so the field reads as non-interactive at a glance.
	border := DEFAULT_PALETTE.border
	if !read_only && (hover || value.open) {border = DEFAULT_PALETTE.primary_bright}
	surface := read_only ? DEFAULT_PALETTE.surface_raised : DEFAULT_PALETTE.surface
	box(c, r, border, corner_radius)
	box(
		c,
		{r.x + 1, r.y + 1, r.w - 2, r.h - 2},
		surface,
		max(0, corner_radius - 1),
	)
	if value.selected >= 0 {
		label(c, r.x + 14, r.y + 29, options[value.selected], 17)
	} else {
		label(c, r.x + 14, r.y + 29, placeholder, 17, DEFAULT_PALETTE.text_muted)
	}
	arrow_x := r.x + r.w - 22
	arrow_y := r.y + r.h / 2
	arrow_color := DEFAULT_PALETTE.text_subtle
	if value.open {
		triangle(
			c,
			arrow_x - 5,
			arrow_y + 3,
			arrow_x + 5,
			arrow_y + 3,
			arrow_x,
			arrow_y - 4,
			arrow_color,
		)
	} else {
		triangle(
			c,
			arrow_x - 5,
			arrow_y - 3,
			arrow_x + 5,
			arrow_y - 3,
			arrow_x,
			arrow_y + 4,
			arrow_color,
		)
	}
	// Claim the mouse wheel for this dropdown's popup region (or release
	// the claim if the dropdown has closed). begin_scroll on the NEXT frame
	// uses c.scroll_claim to skip its own wheel handling when the cursor
	// sits inside the menu — that's why we tag by id and clear only our
	// own claim, so stacked dropdowns don't stomp on each other. menu.y is
	// in logical (pre-scroll) coords; add c.offset_y so the stored rect is
	// in screen coords, matching the mouse position begin_scroll compares
	// against.
	if value.open {
		c.scroll_claim_id = id
		c.scroll_claim = {menu.x, menu.y + c.offset_y, menu.w, menu.h}
	} else if c.scroll_claim_id == id {
		c.scroll_claim_id = 0
	}
	if value.open {
		prev_layer := c.layer
		c.layer = .Overlay
		defer c.layer = prev_layer
		box(c, menu, DEFAULT_PALETTE.overlay_border, corner_radius)
		box(
			c,
			{menu.x + 1, menu.y + 1, menu.w - 2, menu.h - 2},
			DEFAULT_PALETTE.overlay,
			max(0, corner_radius - 1),
		)
		if searchable {
			search_rect := Rect{menu.x + 1, menu.y + 1, menu.w - 2, search_h - 1}
			input(c, search_id, search_rect, "Search", &value.query)
			// Thin divider between search and options.
			box(c, {menu.x + 1, menu.y + search_h, menu.w - 2, 1}, DEFAULT_PALETTE.divider)
		}
		// Scrollbar geometry. When the content fits, nothing scrolls and
		// rows use the full inner width; when it overflows, a 10 px gutter
		// is reserved on the right for the track so rows never slide under
		// the thumb. Press / drag on the thumb has to be handled before the
		// row pressable calls below so the item under the thumb doesn't
		// steal the click; the row clip (set up next) excludes the gutter
		// so item contains() checks ignore mouse-over-scrollbar anyway.
		// Wheel over the menu scrolls the popup (not the page below — the
		// scroll_claim set above makes begin_scroll skip this). Zero the
		// value afterwards so nothing further in the frame also consumes
		// it. Only valid when the popup actually scrolls.
		if max_scroll > 0 && contains(c, menu) && c.wheel_y != 0 {
			value.scroll = clamp(value.scroll + c.wheel_y, 0, max_scroll)
			c.wheel_y = 0
		}
		sb_gutter: f32 = 0
		track_x, track_y, track_h, thumb_h, thumb_y: f32
		thumb_hovered: bool
		if max_scroll > 0 {
			sb_gutter = 10
			track_x = menu.x + menu.w - 8
			track_y = menu.y + search_h + 4
			track_h = menu_view_h - 8
			thumb_h = max(24, track_h * menu_view_h / menu_content_h)
			travel := track_h - thumb_h
			thumb_y = track_y + (travel > 0 ? travel * value.scroll / max_scroll : 0)
			thumb_hit := Rect{track_x - 5, track_y - 2, 15, track_h + 4}
			thumb_hovered = contains(c, thumb_hit)
			if c.pressed && thumb_hovered {
				value.dragging = true
				value.grab_y =
					c.my >= thumb_y && c.my < thumb_y + thumb_h ? c.my - thumb_y : thumb_h / 2
			}
			if value.dragging {
				if travel > 0 {
					value.scroll = clamp(
						(c.my - track_y - value.grab_y) / travel * max_scroll,
						0,
						max_scroll,
					)
				}
				if !c.down {value.dragging = false}
			}
			if thumb_hovered || value.dragging {c.pointer_cursor = true}
		}
		// Clip the rows to the menu interior so scrolled content doesn't
		// bleed past the panel, and inset the right edge by the scrollbar
		// gutter so item contains() skips mouse-over-scrollbar hits. c.clip
		// is used as a screen-space scissor by the renderer, so translate
		// the logical menu.y by c.offset_y before storing.
		rows_clip_prev := c.clip
		rows_clipped_prev := c.clipped
		c.clip = {
			menu.x + 1,
			menu.y + search_h + 1 + c.offset_y,
			menu.w - 2 - sb_gutter,
			menu_view_h,
		}
		c.clipped = true
		// Row rendering. In searchable mode we walk options but only draw
		// matches, numbering them by visible slot so item rects stay packed.
		// Rows offset by value.scroll; clipped rows still consume a slot so
		// their indices stay stable across frames.
		visible_i := 0
		for option, i in options {
			if searchable && !dropdown_match(option, query_bytes) {continue}
			item := Rect{
				menu.x + 1,
				menu.y + search_h + 1 + f32(visible_i) * row_h - value.scroll,
				menu.w - 2 - sb_gutter,
				row_h,
			}
			item_hover, item_clicked := pressable(c, sub_id(id, u64(i + 1)), item)
			if item_clicked {
				value.selected = i
				value.open = false
				value.scroll = 0
				if searchable {set_text(&value.query, "")}
			}
			item_color := DEFAULT_PALETTE.overlay
			if i == value.selected {item_color = DEFAULT_PALETTE.item_selected}
			if item_hover {item_color = DEFAULT_PALETTE.item_hover}
			// Round panel-edge corners only when nothing scrolls, so the
			// rounded corners stay anchored to the panel; a scrolling menu
			// draws square rows and lets the panel's own rounding show.
			item_radius: f32 = 0
			if max_scroll == 0 {
				first_slot := visible_i == 0 && !searchable
				last_slot := visible_i == menu_rows - 1
				if first_slot || last_slot {item_radius = max(0, corner_radius - 1)}
				box(c, item, item_color, item_radius)
				if item_radius > 0 && first_slot && menu_rows > 1 {
					box(
						c,
						{item.x, item.y + item.h - item_radius, item.w, item_radius},
						item_color,
					)
				}
				if item_radius > 0 && last_slot && menu_rows > 1 {
					box(c, {item.x, item.y, item.w, item_radius}, item_color)
				}
			} else {
				box(c, item, item_color, 0)
			}
			label(c, item.x + 14, item.y + 26, option, 16)
			visible_i += 1
		}
		c.clip = rows_clip_prev
		c.clipped = rows_clipped_prev
		// Scrollbar paint goes on top of the restored clip so it isn't
		// itself clipped by the row interior.
		if max_scroll > 0 {
			hot := thumb_hovered || value.dragging
			w: f32 = hot ? 7 : 5
			alpha: f32 = hot ? 0.95 : 0.75
			center_x := track_x + 2
			tr := DEFAULT_PALETTE.scroll_track
			th := DEFAULT_PALETTE.scroll_thumb
			box(
				c,
				{center_x - w / 2, track_y, w, track_h},
				{tr[0], tr[1], tr[2], 0.18},
				w / 2,
			)
			box(
				c,
				{center_x - w / 2, thumb_y, w, thumb_h},
				{th[0], th[1], th[2], alpha},
				w / 2,
			)
		}
		// Enter while the search field is focused picks the first match.
		if searchable && c.enter && c.focused == search_id && match_count > 0 {
			for option, i in options {
				if dropdown_match(option, query_bytes) {
					value.selected = i
					value.open = false
					value.scroll = 0
					set_text(&value.query, "")
					c.enter = false
					break
				}
			}
		}
	}
}
