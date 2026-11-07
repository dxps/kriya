#+build !wasm32
package ui
import "core:testing"

@(test)
button_release_requires_matching_press :: proc(t:^testing.T) {
    c:Context
    defer delete(c.commands)
    r:=Rect{0,0,100,40}
    c.mx=10;c.my=10;c.released=true
    testing.expect(t,!button(&c,1,r,"Save"))
    end(&c);begin(&c)
    c.pressed=true;c.down=true
    testing.expect(t,!button(&c,1,r,"Save"))
    end(&c);begin(&c)
    c.down=false;c.released=true
    testing.expect(t,button(&c,1,r,"Save"))
    testing.expect(t,c.active==0)
}
@(test)
disabled_button_does_not_capture :: proc(t:^testing.T) {
    c:=Context{mx=10,my=10,pressed=true,down=true}
    defer delete(c.commands)
    testing.expect(t,!button(&c,1,{0,0,100,40},"Save",true))
    testing.expect(t,c.active==0)
}

test_text_width :: proc(text:string,size:f32)->f32 {return 140}

@(test)
checkbox_label_toggles_and_requests_pointer :: proc(t:^testing.T) {
    c:=Context{mx=100,my=12,measure_text=test_text_width}
    defer delete(c.commands)
    value:=false
    begin(&c)
    c.pressed=true;c.down=true
    checkbox(&c,1,0,0,"Enable notifications",&value)
    testing.expect(t,c.pointer_cursor)
    testing.expect(t,!value)
    end(&c);begin(&c)
    c.released=true;c.down=false
    checkbox(&c,1,0,0,"Enable notifications",&value)
    testing.expect(t,value)
    testing.expect(t,c.active==0)
    end(&c);begin(&c)
    c.mx=180
    checkbox(&c,1,0,0,"Enable notifications",&value)
    testing.expect(t,!c.pointer_cursor)
}

@(test)
checkbox_release_outside_label_does_not_toggle :: proc(t:^testing.T) {
    c:=Context{mx=100,my=12,measure_text=test_text_width,pressed=true,down=true}
    defer delete(c.commands)
    value:=false
    checkbox(&c,1,0,0,"Enable notifications",&value)
    end(&c);begin(&c)
    c.mx=180;c.down=false;c.released=true
    checkbox(&c,1,0,0,"Enable notifications",&value)
    testing.expect(t,!value)
    testing.expect(t,c.active==0)
    testing.expect(t,!c.pointer_cursor)
}
