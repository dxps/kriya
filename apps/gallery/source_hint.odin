package main
import ui "kriya:ui"

draw_source_hint :: proc(c:^ui.Context,source:string) {
    color:=ui.Color{0.47,0.55,0.59,1}
    path_color:=ui.Color{0.64,0.78,0.74,1}
    size:f32=16
    // Hasklig has taller vertical metrics; 17px matches Work Sans's 16px cap height.
    mono_size:f32=17
    x:f32=274
    // The preview ends at y=534; keep this baseline just 26px below it.
    ui.label(c,x,560,"Edit ",size,color)
    x+=measure_font_text("Edit ",size,.Body)
    ui.label(c,x,560,source,mono_size,path_color,.Mono)
    x+=measure_font_text(source,mono_size,.Mono)
    ui.label(c,x,560," and save to reload.",size,color)
}
