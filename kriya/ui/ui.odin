package ui

Color :: [4]f32
Font :: enum { Body, Mono }
DEFAULT_CORNER_RADIUS :: 6.0
USE_CONTEXT_CORNER_RADIUS :: -1.0
Rect :: struct { x,y,w,h:f32 }
Box_Command :: struct { rect:Rect, color:Color, radius:f32 }
Line_Command :: struct { x1,y1,x2,y2,width:f32, color:Color }
Triangle_Command :: struct { x1,y1,x2,y2,x3,y3:f32, color:Color }
Text_Command :: struct { x,y:f32, text:string, size:f32, font:Font, color:Color }
Command_Variant :: union { Box_Command, Line_Command, Triangle_Command, Text_Command }
Command :: struct { clip:Rect, clipped:bool, variant:Command_Variant }
Context :: struct {
    commands:[dynamic]Command,
    mx,my:f32,
    pressed,released,down:bool,
    active:u64,
    measure_text:proc(text:string,size:f32)->f32,
    pointer_cursor:bool,
    moved:bool,
    wheel_y:f32,
    offset_y:f32,
    clip:Rect,
    clipped:bool,
    input_blocked:bool,
    focused:u64,
    typed:[32]u8,
    typed_len:int,
    backspace:bool,
    corner_radius:f32,
    corner_radius_set:bool,
}
begin :: proc(c:^Context) { clear(&c.commands);c.pointer_cursor=false;c.offset_y=0;c.clipped=false;c.input_blocked=false }
end :: proc(c:^Context) { c.pressed=false; c.released=false;c.moved=false;c.wheel_y=0;c.typed_len=0;c.backspace=false }
set_corner_radius :: proc(c:^Context,radius:f32) {
    c.corner_radius=max(0,radius)
    c.corner_radius_set=true
}
resolve_corner_radius :: proc(c:^Context,radius:f32)->f32 {
    if radius>=0 {return radius}
    if c.corner_radius_set {return c.corner_radius}
    return DEFAULT_CORNER_RADIUS
}
box :: proc(c:^Context,r:Rect,color:Color,radius:f32=0) {
    translated:=r;translated.y+=c.offset_y
    append(&c.commands,Command{clip=c.clip,clipped=c.clipped,variant=Box_Command{rect=translated,color=color,radius=radius}})
}
line :: proc(c:^Context,x1,y1,x2,y2,width:f32,color:Color) {
    append(&c.commands,Command{clip=c.clip,clipped=c.clipped,variant=Line_Command{x1=x1,y1=y1+c.offset_y,x2=x2,y2=y2+c.offset_y,width=width,color=color}})
}
triangle :: proc(c:^Context,x1,y1,x2,y2,x3,y3:f32,color:Color) {
    append(&c.commands,Command{clip=c.clip,clipped=c.clipped,variant=Triangle_Command{x1=x1,y1=y1+c.offset_y,x2=x2,y2=y2+c.offset_y,x3=x3,y3=y3+c.offset_y,color=color}})
}
label :: proc(c:^Context,x,y:f32,text:string,size:f32=18,color:Color={0.84,0.89,0.92,1},font:Font=.Body) {
    append(&c.commands,Command{clip=c.clip,clipped=c.clipped,variant=Text_Command{x=x,y=y+c.offset_y,text=text,size=size,font=font,color=color}})
}
point_in_rect :: proc(x,y:f32,r:Rect)->bool {return x>=r.x && x<r.x+r.w && y>=r.y && y<r.y+r.h}
contains :: proc(c:^Context,r:Rect)->bool {
    translated:=r;translated.y+=c.offset_y
    return !c.input_blocked && (!c.clipped || point_in_rect(c.mx,c.my,c.clip)) && point_in_rect(c.mx,c.my,translated)
}
button :: proc(c:^Context,id:u64,r:Rect,text:string,disabled:=false,radius:f32=USE_CONTEXT_CORNER_RADIUS)->bool {
    corner_radius:=resolve_corner_radius(c,radius)
    hover:=contains(c,r) && !disabled
    if hover {c.pointer_cursor=true}
    if hover && c.pressed { c.active=id }
    clicked:=hover && c.released && c.active==id
    color:Color={0.20,0.67,0.57,1}
    if hover { color={0.29,0.78,0.66,1} }
    if c.active==id && c.down { color={0.14,0.48,0.42,1} }
    if disabled { color={0.20,0.25,0.28,1} }
    box(c,r,color,corner_radius); label(c,r.x+18,r.y+28,text,18,{0.06,0.11,0.12,1})
    if c.released && c.active==id { c.active=0 }
    return clicked
}
checkbox :: proc(c:^Context,id:u64,x,y:f32,text:string,value:^bool,radius:f32=USE_CONTEXT_CORNER_RADIUS) {
    corner_radius:=resolve_corner_radius(c,radius)
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
    box(c,r,border,corner_radius)
    // One logical pixel of border, independent of the checked indicator.
    box(c,{x+1,y+1,16,16},{0.10,0.14,0.17,1},max(0,corner_radius-1))
    if value^ {box(c,{x+3,y+3,12,12},border,max(0,corner_radius-3))}
    if c.released && c.active==id {c.active=0}
    label(c,x+28,y+14,text)
}

Text_Input :: struct {
    data:[128]u8,
    len:int,
    revealed:bool,
}

set_text :: proc(value:^Text_Input,text:string) {
    value.len=min(len(text),len(value.data))
    copy(value.data[:value.len],transmute([]u8)text[:value.len])
}

input :: proc(c:^Context,id:u64,r:Rect,placeholder:string,value:^Text_Input,password:=false,radius:f32=USE_CONTEXT_CORNER_RADIUS) {
    corner_radius:=resolve_corner_radius(c,radius)
    hover:=contains(c,r)
    eye_w:f32=password ? 44 : 0
    text_hit:=Rect{r.x,r.y,r.w-eye_w,r.h}
    if hover {c.pointer_cursor=true}
    if c.pressed {
        if contains(c,text_hit) {c.focused=id}
        else if c.focused==id && !hover {c.focused=0}
    }
    focused:=c.focused==id
    if focused {
        if c.backspace && value.len>0 {value.len-=1}
        for ch in c.typed[:c.typed_len] {
            if value.len<len(value.data) {value.data[value.len]=ch;value.len+=1}
        }
        c.typed_len=0
        c.backspace=false
    }
    border:Color={0.25,0.34,0.38,1}
    if hover {border={0.36,0.48,0.52,1}}
    if focused {border={0.32,0.83,0.69,1}}
    box(c,r,border,corner_radius)
    box(c,{r.x+1,r.y+1,r.w-2,r.h-2},{0.075,0.105,0.125,1},max(0,corner_radius-1))
    shown:=placeholder
    masked:=password && !value.revealed && value.len>0
    color:=Color{0.47,0.56,0.61,1}
    if value.len>0 {
        color={0.84,0.89,0.92,1}
        if !masked {
            shown=string(value.data[:value.len])
        }
    }
    if masked {
        // Draw round password bullets independently of the text font so their
        // shape remains circular at every display scale.
        bullet_x:=r.x+14
        for _ in 0..<value.len {
            box(c,{bullet_x,r.y+r.h/2-4,8,8},color,4)
            bullet_x+=14
        }
    } else {
        label(c,r.x+14,r.y+29,shown,17,color)
    }
    if focused {
        caret_x:=r.x+14+f32(value.len)*14
        if !masked {
            assert(c.measure_text!=nil,"Focused inputs require a text measurement callback")
            caret_x=r.x+14+c.measure_text(shown,17)
        }
        box(c,{min(caret_x,r.x+r.w-eye_w-12),r.y+11,1,r.h-22},{0.32,0.83,0.69,1})
    }
    if password {
        divider_x:=r.x+r.w-eye_w
        box(c,{divider_x,r.y+8,1,r.h-16},{0.20,0.27,0.30,1})
        eye:=Rect{divider_x+12,r.y+16,20,12}
        eye_hover:=contains(c,{divider_x,r.y,eye_w,r.h})
        if eye_hover && c.pressed {c.active=id|0x8000000000000000}
        if eye_hover && c.released && c.active==(id|0x8000000000000000) {value.revealed=!value.revealed}
        eye_color:=eye_hover ? Color{0.32,0.83,0.69,1} : Color{0.57,0.66,0.69,1}
        // Four short segments per lid retain a gentle curve while keeping the
        // left and right corners pointed like a conventional eye glyph.
        line(c,eye.x,eye.y+6,eye.x+5,eye.y+2,1.4,eye_color)
        line(c,eye.x+5,eye.y+2,eye.x+10,eye.y+1,1.4,eye_color)
        line(c,eye.x+10,eye.y+1,eye.x+15,eye.y+2,1.4,eye_color)
        line(c,eye.x+15,eye.y+2,eye.x+20,eye.y+6,1.4,eye_color)
        line(c,eye.x,eye.y+6,eye.x+5,eye.y+10,1.4,eye_color)
        line(c,eye.x+5,eye.y+10,eye.x+10,eye.y+11,1.4,eye_color)
        line(c,eye.x+10,eye.y+11,eye.x+15,eye.y+10,1.4,eye_color)
        line(c,eye.x+15,eye.y+10,eye.x+20,eye.y+6,1.4,eye_color)
        box(c,{eye.x+7,eye.y+3,6,6},eye_color,3)
        if !value.revealed {
            // Hidden is visually distinct by default: the eye is struck through.
            line(c,eye.x-2,eye.y+eye.h+3,eye.x+eye.w+2,eye.y-3,2.5,{0.075,0.105,0.125,1})
            line(c,eye.x-2,eye.y+eye.h+3,eye.x+eye.w+2,eye.y-3,1.25,eye_color)
        }
        if c.released && c.active==(id|0x8000000000000000) {c.active=0}
    }
}

Dropdown :: struct {
    selected:int,
    open:bool,
}

dropdown :: proc(c:^Context,id:u64,r:Rect,options:[]string,value:^Dropdown,radius:f32=USE_CONTEXT_CORNER_RADIUS) {
    corner_radius:=resolve_corner_radius(c,radius)
    assert(len(options)>0,"Dropdowns require at least one option")
    value.selected=clamp(value.selected,0,len(options)-1)
    menu:=Rect{r.x,r.y+r.h,r.w,f32(len(options))*40+2}
    if value.open && c.pressed && !contains(c,r) && !contains(c,menu) {
        value.open=false
    }
    hover:=contains(c,r)
    if hover {c.pointer_cursor=true}
    if hover && c.pressed {c.active=id}
    if hover && c.released && c.active==id {value.open=!value.open}
    border:Color={0.25,0.34,0.38,1}
    if hover || value.open {border={0.32,0.83,0.69,1}}
    box(c,r,border,corner_radius)
    box(c,{r.x+1,r.y+1,r.w-2,r.h-2},{0.075,0.105,0.125,1},max(0,corner_radius-1))
    label(c,r.x+14,r.y+29,options[value.selected],17)
    arrow_x:=r.x+r.w-22
    arrow_y:=r.y+r.h/2
    arrow_color:=Color{0.57,0.66,0.69,1}
    if value.open {
        triangle(c,arrow_x-5,arrow_y+3,arrow_x+5,arrow_y+3,arrow_x,arrow_y-4,arrow_color)
    } else {
        triangle(c,arrow_x-5,arrow_y-3,arrow_x+5,arrow_y-3,arrow_x,arrow_y+4,arrow_color)
    }
    if c.released && c.active==id {c.active=0}
    if value.open {
        box(c,menu,{0.22,0.30,0.33,1},corner_radius)
        box(c,{menu.x+1,menu.y+1,menu.w-2,menu.h-2},{0.12,0.16,0.18,1},max(0,corner_radius-1))
        for option,i in options {
            item:=Rect{menu.x+1,menu.y+1+f32(i)*40,menu.w-2,40}
            item_id:=id+u64(i)+1
            item_hover:=contains(c,item)
            if item_hover {c.pointer_cursor=true}
            if item_hover && c.pressed {c.active=item_id}
            if item_hover && c.released && c.active==item_id {value.selected=i;value.open=false}
            item_color:=Color{0.12,0.16,0.18,1}
            if i==value.selected {item_color={0.15,0.25,0.24,1}}
            if item_hover {item_color={0.18,0.31,0.29,1}}
            item_radius:f32=0
            if i==0 || i==len(options)-1 {item_radius=max(0,corner_radius-1)}
            box(c,item,item_color,item_radius)
            // Preserve the panel curves while keeping adjoining row edges square.
            if item_radius>0 && i==0 && len(options)>1 {
                box(c,{item.x,item.y+item.h-item_radius,item.w,item_radius},item_color)
            }
            if item_radius>0 && i==len(options)-1 && len(options)>1 {
                box(c,{item.x,item.y,item.w,item_radius},item_color)
            }
            label(c,item.x+14,item.y+26,option,16)
            if c.released && c.active==item_id {c.active=0}
        }
    }
}
