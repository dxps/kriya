package main

import ui "kriya:ui"
import web "../../backends/web"
import "../../gallery/routes"

sidebar_link :: proc(c:^ui.Context,id:u64,r:ui.Rect,text:string,active:bool)->bool {
    hover,clicked:=ui.pressable(c,id,r)
    color:=GALLERY_LINK_TEXT
    if active {color=ui.DEFAULT_PALETTE.primary_bright}
    if hover {
        background:=GALLERY_LINK_HOVER_BG
        if c.active==id && c.down {background=GALLERY_LINK_PRESSED_BG}
        ui.box(c,r,background,ui.DEFAULT_CORNER_RADIUS)
        color=GALLERY_LINK_TEXT_HOVER
    }
    if c.active==id && c.down {color=GALLERY_LINK_PRESSED_TEXT}
    if active {ui.box(c,{r.x+4,r.y+10,2,16},ui.DEFAULT_PALETTE.primary_bright,1)}
    ui.label(c,r.x+18,r.y+24,text,18,color)
    return clicked
}

draw_sidebar :: proc(h:f32) {
    ui.box(&ctx,{0,0,230,h},GALLERY_SIDEBAR_BG)
    ui.label(&ctx,28,52,"kriya",36,ui.DEFAULT_PALETTE.primary_bright)
    ui.label(&ctx,28,82,"COMPONENT WORKSHOP",12)
    ui.label(&ctx,28,140,"FOUNDATIONS / 01",12,ui.DEFAULT_PALETTE.text_muted)
    for section,i in routes.SECTIONS {
        y:=f32(164+i*44)
        if sidebar_link(&ctx,u64(100+i),{24,y,182,36},section.title,selected==i) {
            selected=i
            web.kriya_navigate(section.path)
        }
    }
}
