package main

import "core:math"
import "core:strings"
import "core:unicode/utf8"
import sapp "sokol:app"

// Multi-click detection state. Sokol delivers each press as MOUSE_DOWN; we
// count consecutive presses that arrive within ~333ms (20 frames at 60Hz)
// and ~4 CSS pixels of the last one, promoting count 2 to double-click and
// count 3 to triple-click. Further presses stay capped at 3 so a 4th press
// still behaves like a triple.
last_click_frame: u64 = max(u64)
last_click_x:     f32
last_click_y:     f32
click_count:      int

// Send text to sokol's internal clipboard buffer. Converts to a
// null-terminated cstring using the temp allocator; sokol copies into its
// own buffer, so the temp lifetime is fine.
app_set_clipboard :: proc(text: string) {
	ctext := strings.clone_to_cstring(text, context.temp_allocator)
	sapp.set_clipboard_string(ctext)
}

event :: proc "c" (e: ^sapp.Event) {
	context = app_context
	ctx.mx = e.mouse_x / sapp.dpi_scale(); ctx.my = e.mouse_y / sapp.dpi_scale()
	#partial switch e.type {
	case .MOUSE_DOWN:
		if e.mouse_button == .LEFT {
			ctx.pressed = true
			ctx.down = true
			ctx.mouse_shift = (e.modifiers & sapp.MODIFIER_SHIFT) != 0
			frame := sapp.frame_count()
			close := last_click_frame != max(u64) &&
				frame - last_click_frame <= 20 &&
				math.abs(ctx.mx - last_click_x) < 4 &&
				math.abs(ctx.my - last_click_y) < 4
			if close {click_count = min(click_count + 1, 3)} else {click_count = 1}
			if click_count == 2 {ctx.double_click = true}
			if click_count == 3 {ctx.triple_click = true}
			last_click_frame = frame
			last_click_x = ctx.mx
			last_click_y = ctx.my
		}
	case .MOUSE_UP:
		if e.mouse_button == .LEFT {ctx.released = true; ctx.down = false}
	case .UNFOCUSED:
		ctx.down = false; ctx.active = 0
	case .MOUSE_LEAVE:
		ctx.mx = -1; ctx.my = -1
	case .MOUSE_MOVE:
		ctx.moved = true
	case .MOUSE_SCROLL:
		// Shift + vertical wheel rolls over to horizontal — desktop
		// convention for mice without a tilt / twist wheel.
		if (e.modifiers & sapp.MODIFIER_SHIFT) != 0 {
			ctx.wheel_x -= e.scroll_y * 32
		} else {
			ctx.wheel_y -= e.scroll_y * 32
		}
		ctx.wheel_x -= e.scroll_x * 32
	case .CHAR:
		if e.char_code < FIRST_GLYPH || e.char_code > LAST_GLYPH {break}
		bytes, n := utf8.encode_rune(rune(e.char_code))
		if ctx.typed_len + n > len(ctx.typed) {break}
		for i in 0 ..< n {
			ctx.typed[ctx.typed_len] = bytes[i]
			ctx.typed_len += 1
		}
	case .KEY_DOWN:
		if e.key_code == .BACKSPACE {ctx.backspace = true}
		if e.key_code == .DELETE {ctx.forward_delete = true}
		if e.key_code == .ENTER || e.key_code == .KP_ENTER {ctx.enter = true}
		if e.key_code == .LEFT {ctx.nav_left = true}
		if e.key_code == .RIGHT {ctx.nav_right = true}
		if e.key_code == .UP {ctx.nav_up = true}
		if e.key_code == .DOWN {ctx.nav_down = true}
		if e.key_code == .HOME {ctx.nav_home = true}
		if e.key_code == .END {ctx.nav_end = true}
		if e.key_code == .PAGE_UP {ctx.nav_page_up = true}
		if e.key_code == .PAGE_DOWN {ctx.nav_page_down = true}
		if (e.modifiers & sapp.MODIFIER_SHIFT) != 0 {ctx.nav_shift = true}
		// Word-jump modifier: Alt (Option on macOS). Walks the caret to
		// the next / previous word boundary.
		if (e.modifiers & sapp.MODIFIER_ALT) != 0 {ctx.nav_word = true}
		// Line-jump modifier: Ctrl on Linux / Windows / Web, Cmd on
		// macOS. Collapses Left / Right to Home / End so beginning- and
		// end-of-line are available from the same hand as the caret.
		if (e.modifiers & (sapp.MODIFIER_CTRL | sapp.MODIFIER_SUPER)) != 0 {ctx.nav_line = true}
		// Ctrl on Linux / Windows / Web, Cmd on macOS — accept either so
		// each host's conventional shortcut works. Paste is delivered
		// through the CLIPBOARD_PASTED event; Ctrl+V on web can't read the
		// clipboard from a KEY_DOWN handler.
		editor_mod := (e.modifiers & (sapp.MODIFIER_CTRL | sapp.MODIFIER_SUPER)) != 0
		if editor_mod && e.key_code == .A {ctx.select_all = true}
		if editor_mod && e.key_code == .C {ctx.copy_request = true}
		if editor_mod && e.key_code == .X {ctx.cut_request = true}
		// Ctrl/Cmd+Z undoes; Shift adds redo, and Ctrl+Y is the
		// traditional Windows alias for redo so both habits work.
		shift_held := (e.modifiers & sapp.MODIFIER_SHIFT) != 0
		if editor_mod && e.key_code == .Z {
			if shift_held {ctx.redo_request = true} else {ctx.undo_request = true}
		}
		if editor_mod && e.key_code == .Y {ctx.redo_request = true}
	case .CLIPBOARD_PASTED:
		raw := sapp.get_clipboard_string()
		if raw != nil {
			text := string(raw)
			n := min(len(text), len(ctx.paste))
			copy(ctx.paste[:n], transmute([]u8)text[:n])
			ctx.paste_len = n
		}
	case:
	}
}
