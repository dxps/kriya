package main
import ui "kriya:ui"

framework_options:=[]string{"Odin","C","Rust"}
framework_dropdown:=ui.Dropdown{selected=0}

draw_dropdowns :: proc(c:^ui.Context) {
    ui.label(c,302,250,"LANGUAGE",11,{0.47,0.56,0.61,1})
    ui.dropdown(c,30,{302,266,360,46},framework_options,&framework_dropdown)
    ui.label(c,302,456,"Open the menu and choose an option.",17)
}
