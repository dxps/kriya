#+build !wasm32
package ui
import "core:testing"

@(test)
scroll_clamps_and_resets_when_content_fits :: proc(t:^testing.T) {
    c:=Context{mx=20,my=20,wheel_y=500}
    s:Scroll_State
    begin_scroll(&c,&s,{0,0,100,100},300,0.016)
    testing.expect(t,s.offset==200)
    testing.expect(t,c.offset_y== -200)
    end_scroll(&c,&s,300)
    defer delete(c.commands)
    begin_scroll(&c,&s,{0,0,100,400},300,0.016)
    testing.expect(t,s.offset==0)
    end_scroll(&c,&s,300)
}

@(test)
scroll_clips_rendering_and_widget_hit_testing :: proc(t:^testing.T) {
    c:=Context{mx=20,my=20}
    s:=Scroll_State{offset=100}
    defer delete(c.commands)
    begin_scroll(&c,&s,{0,0,100,100},300,0.016)
    testing.expect(t,contains(&c,{10,110,40,30}))
    testing.expect(t,!contains(&c,{10,10,40,30}))
    box(&c,{10,110,40,30},{1,1,1,1})
    testing.expect(t,c.commands[0].variant.(Box_Command).rect.y==10)
    testing.expect(t,c.commands[0].clipped)
    c.my=110
    testing.expect(t,!contains(&c,{10,200,40,30}))
    end_scroll(&c,&s,300)
    testing.expect(t,!c.clipped && c.offset_y==0)
}

@(test)
scrollbar_fades_and_mouse_movement_reveals_it :: proc(t:^testing.T) {
    c:=Context{mx=20,my=20}
    s:Scroll_State
    defer delete(c.commands)
    begin_scroll(&c,&s,{0,0,100,100},300,1.3)
    end_scroll(&c,&s,300)
    testing.expect(t,len(c.commands)==0)
    c.moved=true
    begin_scroll(&c,&s,{0,0,100,100},300,0.016)
    end_scroll(&c,&s,300)
    testing.expect(t,len(c.commands)==2)
    thumb:=c.commands[1].variant.(Box_Command)
    testing.expect(t,thumb.radius>0)
    testing.expect(t,thumb.color[3]>0)
    clear(&c.commands)
    c.moved=false
    begin_scroll(&c,&s,{0,0,100,100},300,0.5)
    end_scroll(&c,&s,300)
    thumb_fading:=c.commands[1].variant.(Box_Command)
    testing.expect(t,thumb_fading.color[3]>0 && thumb_fading.color[3]<0.7)
}

@(test)
scrollbar_track_click_and_drag_capture_input :: proc(t:^testing.T) {
    c:=Context{mx=88,my=60,pressed=true,down=true}
    s:Scroll_State
    defer delete(c.commands)
    begin_scroll(&c,&s,{0,0,100,100},300,0.016)
    testing.expect(t,s.dragging && s.offset>0)
    testing.expect(t,c.input_blocked && c.pointer_cursor)
    end_scroll(&c,&s,300)
    end(&c);begin(&c)
    c.my=100;c.down=false;c.released=true
    begin_scroll(&c,&s,{0,0,100,100},300,0.016)
    testing.expect(t,!s.dragging && s.offset==200)
    end_scroll(&c,&s,300)
}
