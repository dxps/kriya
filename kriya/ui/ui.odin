package ui

Color :: [4]f32
Rect :: struct { x,y,w,h:f32 }
Command :: struct { rect:Rect, color:Color, text:string, size:f32 }
Context :: struct {
    commands:[dynamic]Command,
    mx,my:f32,
    pressed,released,down:bool,
    active:u64,
    measure_text:proc(text:string,size:f32)->f32,
    pointer_cursor:bool,
}
begin :: proc(c:^Context) { clear(&c.commands);c.pointer_cursor=false }
end :: proc(c:^Context) { c.pressed=false; c.released=false }
box :: proc(c:^Context,r:Rect,color:Color) { append(&c.commands,Command{rect=r,color=color}) }
label :: proc(c:^Context,x,y:f32,text:string,size:f32=18,color:Color={0.84,0.89,0.92,1}) { append(&c.commands,Command{rect={x=x,y=y},text=text,size=size,color=color}) }
contains :: proc(c:^Context,r:Rect)->bool { return c.mx>=r.x && c.mx<r.x+r.w && c.my>=r.y && c.my<r.y+r.h }
button :: proc(c:^Context,id:u64,r:Rect,text:string,disabled:=false)->bool {
    hover:=contains(c,r) && !disabled
    if hover {c.pointer_cursor=true}
    if hover && c.pressed { c.active=id }
    clicked:=hover && c.released && c.active==id
    color:Color={0.20,0.67,0.57,1}
    if hover { color={0.29,0.78,0.66,1} }
    if c.active==id && c.down { color={0.14,0.48,0.42,1} }
    if disabled { color={0.20,0.25,0.28,1} }
    box(c,r,color); label(c,r.x+18,r.y+28,text,18,{0.06,0.11,0.12,1})
    if c.released && c.active==id { c.active=0 }
    return clicked
}
checkbox :: proc(c:^Context,id:u64,x,y:f32,text:string,value:^bool) {
    r:=Rect{x,y,18,18}
    hit:=r
    if len(text)>0 {
        assert(c.measure_text!=nil,"Checkbox labels require a text measurement callback")
        hit.w=28+c.measure_text(text,18)
    }
    hover:=contains(c,hit)
    if hover {c.pointer_cursor=true}
    if hover && c.pressed {c.active=id}
    if hover && c.released && c.active==id {value^ = !value^}
    border:Color={0.20,0.67,0.57,1}
    if hover {border={0.29,0.78,0.66,1}}
    if c.active==id && c.down {border={0.14,0.48,0.42,1}}
    box(c,r,border)
    // One logical pixel of border, independent of the checked indicator.
    box(c,{x+1,y+1,16,16},{0.10,0.14,0.17,1})
    if value^ {box(c,{x+3,y+3,12,12},border)}
    if c.released && c.active==id {c.active=0}
    label(c,x+28,y+14,text)
}
