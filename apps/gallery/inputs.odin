package main
import ui "kriya:ui"

name_input:ui.Text_Input
password_input:ui.Text_Input

init_input_examples :: proc() {
    ui.set_text(&name_input,"Ada Lovelace")
    ui.set_text(&password_input,"analytical-engine")
}

draw_inputs :: proc(c:^ui.Context) {
    ui.label(c,302,250,"STANDARD",11,ui.DEFAULT_PALETTE.text_muted)
    ui.input(c,20,{302,266,360,46},"Enter a name",&name_input)
    ui.label(c,302,346,"PASSWORD",11,ui.DEFAULT_PALETTE.text_muted)
    ui.input(c,21,{302,362,360,46},"Enter a password",&password_input,true)
    ui.label(c,302,452,"Click the eye to reveal or hide the password.",17)
}
