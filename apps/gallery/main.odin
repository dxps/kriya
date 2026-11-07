package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:math"
import ui "kriya:ui"
import sg "sokol:gfx"
import sapp "sokol:app"
import sgl "sokol:gl"
import glue "sokol:glue"
import slog "sokol:log"
import tt "../../backends/font"
import web "../../backends/web"
import "../../gallery/routes"

font := #load("../../web/fonts/WorkSans.ttf")
ctx:ui.Context
Font_Atlas :: struct {
    physical_size:i32,
    dimension:i32,
    glyphs:[95]tt.bakedchar,
    image:sg.Image,
    view:sg.View,
}
atlases:[32]Font_Atlas
atlas_count:int
atlas_dpi:f32
// Scratch is reused for every atlas; GPU resources retain their own copy.
atlas_bitmap:[2048*2048]u8
atlas_pixels:[2048*2048]u32
sampler:sg.Sampler
pipeline:sgl.Pipeline
selected:int
sections:=routes.SECTIONS
count:int
enabled:=true
dark:=true
storage:[16*1024*1024]u8
arena:mem.Arena
temp_storage:[1024*1024]u8
temp_arena:mem.Arena
app_context:runtime.Context

init :: proc "c" () {
    context=app_context
    sg.setup({environment=glue.environment(),logger={func=slog.func}})
    sgl.setup({logger={func=slog.func},max_vertices=65536})
    pipeline=sgl.make_pipeline({colors={0={blend={enabled=true,src_factor_rgb=.SRC_ALPHA,dst_factor_rgb=.ONE_MINUS_SRC_ALPHA,src_factor_alpha=.ONE,dst_factor_alpha=.ONE_MINUS_SRC_ALPHA}}}})
    sampler=sg.make_sampler({min_filter=.LINEAR,mag_filter=.LINEAR,wrap_u=.CLAMP_TO_EDGE,wrap_v=.CLAMP_TO_EDGE})
}
clear_atlases :: proc() {
    for i in 0..<atlas_count {
        sg.destroy_view(atlases[i].view)
        sg.destroy_image(atlases[i].image)
    }
    atlas_count=0
}
font_atlas :: proc(size,dpi:f32)->^Font_Atlas {
    if dpi!=atlas_dpi {clear_atlases();atlas_dpi=dpi}
    physical_size:=i32(math.round(size*dpi))
    for i in 0..<atlas_count {
        if atlases[i].physical_size==physical_size {return &atlases[i]}
    }
    assert(atlas_count<len(atlases),"Font atlas cache exhausted")
    a:=&atlases[atlas_count]
    a.physical_size=physical_size
    a.dimension=128
    for a.dimension<physical_size*12 && a.dimension<2048 {a.dimension*=2}
    pixel_count:=int(a.dimension*a.dimension)
    used:=tt.BakeFontBitmap(raw_data(font),0,f32(physical_size),raw_data(atlas_bitmap[:]),a.dimension,a.dimension,32,95,raw_data(a.glyphs[:]))
    assert(used>0,"Glyphs do not fit in the font atlas")
    for alpha,i in atlas_bitmap[:pixel_count] {atlas_pixels[i]=0x00ffffff | (u32(alpha)<<24)}
    a.image=sg.make_image({width=a.dimension,height=a.dimension,data={ptr=&atlas_pixels[0],size=uint(pixel_count*4)}})
    a.view=sg.make_view({texture={image=a.image}})
    atlas_count+=1
    return a
}
quad :: proc(r:ui.Rect) {
    sgl.v2f(r.x,r.y);sgl.v2f(r.x+r.w,r.y);sgl.v2f(r.x+r.w,r.y+r.h);sgl.v2f(r.x,r.y+r.h)
}
measure_text :: proc(text:string,size:f32)->f32 {
    dpi:=sapp.dpi_scale()
    a:=font_atlas(size,dpi)
    advance:f32
    right:f32
    for ch in text {
        if ch<32 || ch>126 {continue}
        glyph:=a.glyphs[ch-32]
        right=max(right,advance+glyph.xoff+f32(glyph.x1-glyph.x0))
        advance+=glyph.xadvance
    }
    return max(right,advance)/dpi
}
render :: proc() {
    dpi:=sapp.dpi_scale()
    // Upload fonts before recording draw commands. Each font is rasterized at
    // its actual framebuffer size, avoiding reduction of a shared 40px bitmap.
    for c in ctx.commands {if len(c.text)>0 {_=font_atlas(c.size,dpi)}}
    sgl.defaults();sgl.load_pipeline(pipeline)
    sgl.matrix_mode_projection();sgl.ortho(0,sapp.widthf()/dpi,sapp.heightf()/dpi,0,-1,1)
    for c in ctx.commands {
        sgl.c4f(c.color[0],c.color[1],c.color[2],c.color[3])
        if len(c.text)==0 { sgl.disable_texture();sgl.begin_quads();quad(c.rect);sgl.end();continue }
        a:=font_atlas(c.size,dpi)
        sgl.enable_texture();sgl.texture(a.view,sampler);sgl.begin_quads()
        // Snap the baseline and glyph quads in physical pixels. Advances retain
        // their fractional precision; only the final glyph origin is rounded.
        x:=math.round(c.rect.x*dpi)
        y:=math.round(c.rect.y*dpi)
        for ch in c.text {
            if ch<32 || ch>126 {continue}
            q:tt.aligned_quad
            tt.GetBakedQuad(&a.glyphs[0],a.dimension,a.dimension,i32(ch-32),&x,&y,&q,true)
            sgl.v2f_t2f(q.x0/dpi,q.y0/dpi,q.s0,q.t0)
            sgl.v2f_t2f(q.x1/dpi,q.y0/dpi,q.s1,q.t0)
            sgl.v2f_t2f(q.x1/dpi,q.y1/dpi,q.s1,q.t1)
            sgl.v2f_t2f(q.x0/dpi,q.y1/dpi,q.s0,q.t1)
        }
        sgl.end()
    }
    sg.begin_pass({action={colors={0={load_action=.CLEAR,clear_value={0.067,0.09,0.11,1}}}},swapchain=glue.swapchain()})
    sgl.draw();sg.end_pass();sg.commit()
}
frame :: proc "c" () {
    context=app_context
    ui.begin(&ctx)
    ctx.measure_text=measure_text
    w:=sapp.widthf()/sapp.dpi_scale()
    h:=sapp.heightf()/sapp.dpi_scale()
    ui.box(&ctx,{0,0,230,h},{0.085,0.115,0.135,1})
    ui.label(&ctx,28,52,"kriya",36,{0.32,0.83,0.69,1})
    ui.label(&ctx,28,82,"COMPONENT WORKSHOP",12)
    ui.label(&ctx,28,140,"FOUNDATIONS / 01",12,{0.47,0.56,0.61,1})
    for section,i in routes.SECTIONS {
        y:=f32(164+i*52)
        if selected==i {ui.box(&ctx,{16,y,198,42},{0.14,0.22,0.24,1})}
        if ui.button(&ctx,u64(100+i),{24,y+3,182,36},section.title) {
            selected=i
            web.kriya_navigate(section.path)
        }
    }
    ui.label(&ctx,28,h-40,"ODIN + SOKOL",13)
    ui.label(&ctx,274,52,"LIBRARY / EXPLORER",13,{0.47,0.56,0.61,1})
    ui.label(&ctx,274,110,sections[selected].title,40)
    ui.label(&ctx,274,146,"Small primitives. Shared behavior. Built in Odin.",18)
    ui.box(&ctx,{274,184,max(420,w-318),350},{0.10,0.14,0.17,1})
    ui.label(&ctx,302,220,"INTERACTIVE PREVIEW",12,{0.47,0.56,0.61,1})
    switch selected {
    case 0:
        if ui.button(&ctx,1,{302,258,162,46},"Click me") {count+=1}
        ui.button(&ctx,2,{482,258,162,46},"Disabled",true)
        ui.label(&ctx,302,356,fmt.tprintf("Button pressed %d times",count),24)
        ui.label(&ctx,302,400,"Hover, press and release to explore each state.",17)
    case 1:
        ui.checkbox(&ctx,3,302,270,"Enable notifications",&enabled)
        ui.checkbox(&ctx,4,302,326,"Use dark appearance",&dark)
        ui.label(&ctx,302,410,"Each checkbox owns an independent value.",17)
    case 2:
        ui.label(&ctx,302,280,"Work Sans",48)
        ui.label(&ctx,302,328,"A clear voice for everyday interfaces.",24)
        ui.label(&ctx,302,374,"ABCDEFGHIJKLMNOPQRSTUVWXYZ",18)
        ui.label(&ctx,302,410,"abcdefghijklmnopqrstuvwxyz 0123456789",18)
    case 3:
        ui.label(&ctx,302,274,"Project settings",28)
        ui.checkbox(&ctx,5,302,310,"Publish preview",&enabled)
        if ui.button(&ctx,6,{302,378,162,46},"Save settings") {count+=1}
        ui.label(&ctx,302,474,fmt.tprintf("Saved %d times",count),17)
    }
    ui.label(&ctx,274,578,"WORK SANS / GPU GLYPH ATLAS",12,{0.47,0.56,0.61,1})
    ui.label(&ctx,274,612,"Edit apps/gallery/main.odin and save to reload.",17)
    sapp.set_mouse_cursor(ctx.pointer_cursor ? .POINTING_HAND : .DEFAULT)
    render();ui.end(&ctx)
    free_all(context.temp_allocator)
}
event :: proc "c" (e:^sapp.Event) {
    context=app_context
    ctx.mx=e.mouse_x/sapp.dpi_scale();ctx.my=e.mouse_y/sapp.dpi_scale()
    #partial switch e.type {
    case .MOUSE_DOWN: if e.mouse_button==.LEFT {ctx.pressed=true;ctx.down=true}
    case .MOUSE_UP: if e.mouse_button==.LEFT {ctx.released=true;ctx.down=false}
    case .UNFOCUSED: ctx.down=false;ctx.active=0
    case .MOUSE_LEAVE: ctx.mx=-1;ctx.my=-1
    case:
    }
}
cleanup :: proc "c" () {context=app_context;clear_atlases();sg.destroy_sampler(sampler);sgl.shutdown();sg.shutdown()}
@(export)
kriya_route_changed :: proc "c" () {
    context=app_context
    for section,i in routes.SECTIONS {
        if web.kriya_path_matches(section.path) {selected=i;return}
    }
}
@(export)
kriya_start :: proc "c" () {
    context=runtime.default_context()
    runtime._startup_runtime()
    mem.arena_init(&arena,storage[:])
    mem.arena_init(&temp_arena,temp_storage[:])
    context.allocator=mem.arena_allocator(&arena)
    context.temp_allocator=mem.arena_allocator(&temp_arena)
    app_context=context
    kriya_route_changed()
    enabled=true;dark=true
    sapp.run({init_cb=init,frame_cb=frame,event_cb=event,cleanup_cb=cleanup,width=1200,height=760,high_dpi=true,window_title="Kriya",html5={canvas_selector="#canvas"},logger={func=slog.func}})
}
main :: proc() {kriya_start()}
