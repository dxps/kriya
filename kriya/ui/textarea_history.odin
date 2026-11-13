package ui

// Undo / redo plumbing and the three in-place edit primitives the
// textarea routes every mutation through. Keeping them here lets the
// widget proc read as "handle input, call these" rather than inlining
// buffer manipulation and snapshot copying.

// Edit_Kind classifies the previous write so consecutive edits of the
// same kind coalesce into one undo entry — typing a word creates one
// undo step, not one per character; a run of Backspaces is one step too.
// Anything less uniform (Enter, paste, cut, backspace with selection)
// flushes to .Other so each stands alone.
Edit_Kind :: enum u8 {
	None,
	Insert,
	Delete,
	Other,
}

// Fixed-size snapshot of the editable state. Stored on undo / redo stacks
// so a revert is one struct copy — simple and allocation-free at the
// cost of ~1 KB per entry.
History_Entry :: struct {
	data:   [1024]u8,
	len:    int,
	caret:  int,
	anchor: int,
}

HISTORY_CAP :: 8

// Captures the current buffer, length, caret and anchor as a History_Entry.
textarea_snapshot :: proc(value: ^Text_Area) -> History_Entry {
	entry: History_Entry
	copy(entry.data[:value.len], value.data[:value.len])
	entry.len = value.len
	entry.caret = value.caret
	entry.anchor = value.anchor
	return entry
}

// Replaces the current state with a History_Entry. Clears the goal column
// and the sticky-drag flags because they don't belong to the saved text.
// The entry comes in by pointer so its embedded array stays addressable
// for the slice copy — Odin procedure parameters aren't.
textarea_restore :: proc(value: ^Text_Area, entry: ^History_Entry) {
	value.len = entry.len
	copy(value.data[:entry.len], entry.data[:entry.len])
	value.caret = entry.caret
	value.anchor = entry.anchor
	value.goal_sticky = false
}

// Pushes onto a fixed-size stack. When full, shifts left so the oldest
// entry is dropped and the new entry lands at the top; cheap enough for
// an 8-slot stack and avoids ring-buffer bookkeeping.
textarea_history_push :: proc(
	stack: ^[HISTORY_CAP]History_Entry,
	len: ^int,
	entry: ^History_Entry,
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
textarea_begin_edit :: proc(value: ^Text_Area, kind: Edit_Kind) {
	if kind != value.last_edit_kind {
		snap := textarea_snapshot(value)
		textarea_history_push(&value.undo, &value.undo_len, &snap)
		value.last_edit_kind = kind
	}
	value.redo_len = 0
}

// Reverts to the most recent snapshot. Pushes the current state onto the
// redo stack first so redo can bring it back. Returns true on success.
textarea_undo :: proc(value: ^Text_Area) -> bool {
	if value.undo_len == 0 {return false}
	snap := textarea_snapshot(value)
	textarea_history_push(&value.redo, &value.redo_len, &snap)
	value.undo_len -= 1
	textarea_restore(value, &value.undo[value.undo_len])
	value.last_edit_kind = .None
	return true
}

// Replays the most recent undone state. Mirrors textarea_undo.
textarea_redo :: proc(value: ^Text_Area) -> bool {
	if value.redo_len == 0 {return false}
	snap := textarea_snapshot(value)
	textarea_history_push(&value.undo, &value.undo_len, &snap)
	value.redo_len -= 1
	textarea_restore(value, &value.redo[value.redo_len])
	value.last_edit_kind = .None
	return true
}

// Removes the selected byte range (when anchor != caret) by shifting the
// suffix left, then collapses the pair to the start of the range. Returns
// true when a selection was deleted.
textarea_delete_selection :: proc(value: ^Text_Area) -> bool {
	if value.anchor == value.caret {return false}
	s := min(value.anchor, value.caret)
	e := max(value.anchor, value.caret)
	shift := e - s
	for i := e; i < value.len; i += 1 {value.data[i - shift] = value.data[i]}
	value.len -= shift
	value.caret = s
	value.anchor = s
	return true
}

// Shifts the suffix right and copies bytes into the gap at value.caret,
// then collapses the selection. Returns the number of bytes actually
// inserted (0 when full or empty).
textarea_insert :: proc(value: ^Text_Area, bytes: []u8) -> int {
	n := min(len(bytes), len(value.data) - value.len)
	if n <= 0 {return 0}
	for i := value.len - 1; i >= value.caret; i -= 1 {value.data[i + n] = value.data[i]}
	copy(value.data[value.caret:value.caret + n], bytes[:n])
	value.len += n
	value.caret += n
	value.anchor = value.caret
	return n
}

// Removes the rune to the left of the caret by stepping back past UTF-8
// continuation bytes (top two bits == 10), then shifting the suffix left
// and collapsing the selection. Returns true when a rune was removed.
textarea_backspace :: proc(value: ^Text_Area) -> bool {
	if value.caret == 0 {return false}
	end := value.caret
	start := end - 1
	for start > 0 && (value.data[start] & 0xC0) == 0x80 {start -= 1}
	shift := end - start
	for i := end; i < value.len; i += 1 {value.data[i - shift] = value.data[i]}
	value.len -= shift
	value.caret = start
	value.anchor = start
	return true
}
