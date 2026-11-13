package ui

// Undo / redo plumbing for Text_Input. Mirrors the textarea's history
// layer but with a 128-byte snapshot payload so each slot costs ~160 bytes
// instead of ~1 KB — a single-line input has an order of magnitude less
// text to remember. Edit_Kind and HISTORY_CAP are reused from the
// textarea's history module so the coalescing rules stay identical.

Input_History_Entry :: struct {
	data:   [128]u8,
	len:    int,
	caret:  int,
	anchor: int,
}

input_snapshot :: proc(value: ^Text_Input) -> Input_History_Entry {
	entry: Input_History_Entry
	copy(entry.data[:value.len], value.data[:value.len])
	entry.len = value.len
	entry.caret = value.caret
	entry.anchor = value.anchor
	return entry
}

// Entry comes in by pointer so its embedded array stays addressable for
// the slice copy — Odin procedure parameters aren't.
input_restore :: proc(value: ^Text_Input, entry: ^Input_History_Entry) {
	value.len = entry.len
	copy(value.data[:entry.len], entry.data[:entry.len])
	value.caret = entry.caret
	value.anchor = entry.anchor
}

input_history_push :: proc(
	stack: ^[HISTORY_CAP]Input_History_Entry,
	len: ^int,
	entry: ^Input_History_Entry,
) {
	if len^ < HISTORY_CAP {
		stack[len^] = entry^
		len^ += 1
	} else {
		for i in 0 ..< HISTORY_CAP - 1 {stack[i] = stack[i + 1]}
		stack[HISTORY_CAP - 1] = entry^
	}
}

// Call right before every write. Pushes the current state onto undo when
// the edit kind changed (so same-kind runs coalesce) and always clears
// the redo stack — a new edit forks history.
input_begin_edit :: proc(value: ^Text_Input, kind: Edit_Kind) {
	if kind != value.last_edit_kind {
		snap := input_snapshot(value)
		input_history_push(&value.undo, &value.undo_len, &snap)
		value.last_edit_kind = kind
	}
	value.redo_len = 0
}

input_undo :: proc(value: ^Text_Input) -> bool {
	if value.undo_len == 0 {return false}
	snap := input_snapshot(value)
	input_history_push(&value.redo, &value.redo_len, &snap)
	value.undo_len -= 1
	input_restore(value, &value.undo[value.undo_len])
	value.last_edit_kind = .None
	return true
}

input_redo :: proc(value: ^Text_Input) -> bool {
	if value.redo_len == 0 {return false}
	snap := input_snapshot(value)
	input_history_push(&value.undo, &value.undo_len, &snap)
	value.redo_len -= 1
	input_restore(value, &value.redo[value.redo_len])
	value.last_edit_kind = .None
	return true
}
