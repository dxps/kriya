package main
import ui "kriya:ui"
import "../../gallery/routes"

View :: struct {
    draw:proc(c:^ui.Context),
    source:string,
    content_height:f32,
}

views:=[?]View{
    {draw_buttons,"apps/gallery/buttons.odin",594},
    {draw_inputs,"apps/gallery/inputs.odin",594},
    {draw_dropdowns,"apps/gallery/dropdowns.odin",650},
    {draw_checkboxes,"apps/gallery/checkboxes.odin",594},
    {draw_typography,"apps/gallery/typography.odin",594},
    {draw_composition,"apps/gallery/composition.odin",594},
}
view_scroll:[len(views)]ui.Scroll_State
#assert(len(views)==len(routes.SECTIONS))
