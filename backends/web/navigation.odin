package web

foreign import browser "env.o"
@(default_calling_convention="c")
foreign browser {
    kriya_path_matches :: proc(path:cstring)->b32 ---
    kriya_navigate :: proc(path:cstring) ---
}
