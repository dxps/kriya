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

@(test)
input_focus_types_backspaces_and_masks_password :: proc(t:^testing.T) {
    c:=Context{mx=10,my=10,measure_text=test_text_width,pressed=true,down=true}
    defer delete(c.commands)
    value:Text_Input
    input(&c,7,{0,0,240,44},"Password",&value,true)
    testing.expect(t,c.focused==7)
    end(&c);begin(&c)
    c.typed[0]='a';c.typed[1]='b';c.typed_len=2
    input(&c,7,{0,0,240,44},"Password",&value,true)
    testing.expect(t,value.len==2)
    testing.expect(t,string(value.data[:value.len])=="ab")
    // Two circular bullet commands are emitted instead of font-dependent '*'.
    bullet_count:=0
    for command in c.commands {
        if command.radius==4 && command.rect.w==8 && command.rect.h==8 {bullet_count+=1}
    }
    testing.expect(t,bullet_count==2)
    end(&c);begin(&c)
    c.backspace=true
    input(&c,7,{0,0,240,44},"Password",&value,true)
    testing.expect(t,string(value.data[:value.len])=="a")
}

@(test)
password_eye_toggles_reveal_without_losing_focus :: proc(t:^testing.T) {
    c:=Context{mx=220,my=20,measure_text=test_text_width,pressed=true,down=true,focused=7}
    defer delete(c.commands)
    value:Text_Input
    input(&c,7,{0,0,240,44},"Password",&value,true)
    hidden_lines:=0
    for command in c.commands {if command.line {hidden_lines+=1}}
    testing.expect(t,hidden_lines==10)
    end(&c);begin(&c)
    c.mx=220;c.my=20;c.released=true;c.down=false
    input(&c,7,{0,0,240,44},"Password",&value,true)
    testing.expect(t,value.revealed)
    testing.expect(t,c.focused==7)
    revealed_lines:=0
    for command in c.commands {if command.line {revealed_lines+=1}}
    testing.expect(t,revealed_lines==8)
}

@(test)
dropdown_opens_and_selects_an_option :: proc(t:^testing.T) {
    c:=Context{mx=10,my=10,pressed=true,down=true}
    defer delete(c.commands)
    value:Dropdown
    options:=[]string{"Odin","C","Rust"}
    dropdown(&c,10,{0,0,200,44},options,&value)
    end(&c);begin(&c)
    c.mx=10;c.my=10;c.released=true;c.down=false
    dropdown(&c,10,{0,0,200,44},options,&value)
    testing.expect(t,value.open)
    end(&c);begin(&c)
    c.mx=10;c.my=104;c.pressed=true;c.down=true
    dropdown(&c,10,{0,0,200,44},options,&value)
    end(&c);begin(&c)
    c.mx=10;c.my=104;c.released=true;c.down=false
    dropdown(&c,10,{0,0,200,44},options,&value)
    testing.expect(t,value.selected==1)
    testing.expect(t,!value.open)
}
