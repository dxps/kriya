package web

foreign import browser "env.o"
@(default_calling_convention = "c")
foreign browser {
	kriya_path_matches :: proc(path: cstring) -> b32 ---
	kriya_navigate :: proc(path: cstring) ---
	// Small bits of UI state (which sidebar groups are expanded) that
	// should survive a reload. kriya_storage_get returns the number of
	// bytes written into out — 0 if the key is missing or its value
	// isn't exactly cap bytes long, so the caller can tell "absent" from
	// "present" without a separate found flag.
	kriya_storage_get :: proc(key: cstring, out: ^u8, cap: i32) -> i32 ---
	kriya_storage_set :: proc(key: cstring, value: cstring) ---
}
