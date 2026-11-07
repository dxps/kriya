package main
import ui "kriya:ui"
import "../../gallery/routes"

View :: struct {
    draw:proc(c:^ui.Context),
    source:string,
    content_height:f32,
}

views:=[?]View{
    {draw_buttons,"apps/gallery/buttons.odin",660},
    {draw_checkboxes,"apps/gallery/checkboxes.odin",660},
    {draw_typography,"apps/gallery/typography.odin",660},
    {draw_composition,"apps/gallery/composition.odin",660},
}
view_scroll:[len(views)]ui.Scroll_State
#assert(len(views)==len(routes.SECTIONS))
