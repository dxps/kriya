package main

import ui "kriya:ui"
import web "../../backends/web"
import "../../gallery/routes"

sidebar_link :: proc(c:^ui.Context,id:u64,r:ui.Rect,text:string,active:bool)->bool {
    hover:=ui.contains(c,r)
    if hover {c.pointer_cursor=true}
    if hover && c.pressed {c.active=id}
    clicked:=hover && c.released && c.active==id
    color:ui.Color={0.57,0.64,0.68,1}
    if active {color={0.32,0.83,0.69,1}}
    if hover {color={0.86,0.93,0.92,1}}
    if c.active==id && c.down {color={0.26,0.67,0.57,1}}
    if active {ui.box(c,{r.x+4,r.y+10,2,16},{0.32,0.83,0.69,1},1)}
    ui.label(c,r.x+18,r.y+24,text,18,color)
    if c.released && c.active==id {c.active=0}
    return clicked
}

draw_sidebar :: proc(h:f32) {
    ui.box(&ctx,{0,0,230,h},{0.085,0.115,0.135,1})
    ui.label(&ctx,28,52,"kriya",36,{0.32,0.83,0.69,1})
    ui.label(&ctx,28,82,"COMPONENT WORKSHOP",12)
    ui.label(&ctx,28,140,"FOUNDATIONS / 01",12,{0.47,0.56,0.61,1})
    for section,i in routes.SECTIONS {
        y:=f32(164+i*44)
        if sidebar_link(&ctx,u64(100+i),{24,y,182,36},section.title,selected==i) {
            selected=i
            web.kriya_navigate(section.path)
        }
    }
    ui.label(&ctx,28,h-40,"ODIN + SOKOL",13)
}
