package main

import "core:fmt"
import "core:os"
import "core:net"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import "../../gallery/routes"

Build_State :: struct {
    sequence:int,
    revision:int,
    failed:bool,
    building:bool,
}
state:Build_State
state_mutex:sync.Mutex
// Block asset reads while publishing a new JS/WASM bundle.
assets_mutex:sync.Mutex
server_id:i64

snapshot :: proc()->Build_State {
    sync.mutex_lock(&state_mutex)
    defer sync.mutex_unlock(&state_mutex)
    return state
}
fingerprint :: proc()->u64 {
    h:u64=14695981039346656037
    for root in ([]string{"apps","kriya","backends","gallery","web/fonts","scripts"}) {
        walker:=os.walker_create(root)
        for info in os.walker_walk(&walker) {
            if info.type==.Directory {continue}
            for b in info.fullpath {h=(h~u64(b))*1099511628211}
            data,err:=os.read_entire_file(info.fullpath,context.temp_allocator)
            if err==nil {for b in data {h=(h~u64(b))*1099511628211}}
        }
        os.walker_destroy(&walker)
    }
    for path in ([]string{"web/index.html","web/odin-library.js","web/favicon.svg","web/favicon.ico"}) {
        data,_:=os.read_entire_file(path,context.temp_allocator)
        for b in data {h=(h~u64(b))*1099511628211}
    }
    return h
}
build :: proc() {
    sync.mutex_lock(&state_mutex)
    state.building=true;state.sequence+=1
    sync.mutex_unlock(&state_mutex)
    fmt.println("Building gallery…")
    sync.mutex_lock(&assets_mutex)
    p,err:=os.process_start({command=[]string{"sh","scripts/build-web.sh"},stdout=os.stdout,stderr=os.stderr})
    failed:=err!=nil
    if err==nil {
        result,wait_err:=os.process_wait(p)
        failed=wait_err!=nil || result.exit_code!=0
    } else {fmt.eprintln(err)}
    sync.mutex_unlock(&assets_mutex)
    sync.mutex_lock(&state_mutex)
    state.failed=failed;state.building=false;state.sequence+=1
    if !failed {state.revision+=1;fmt.println("Build ready.")}
    sync.mutex_unlock(&state_mutex)
}
watch :: proc(initial:u64) {
    last:=initial
    candidate:=initial
    for {
        time.sleep(250*time.Millisecond)
        current:=fingerprint()
        // Require two equal samples to debounce editor save bursts.
        if current!=last && current==candidate {last=current;build()}
        candidate=current
        free_all(context.temp_allocator)
    }
}
send_text :: proc(client:net.TCP_Socket,text:string)->bool {
    n,err:=net.send_tcp(client,transmute([]u8)text)
    return err==nil && n==len(text)
}
events :: proc(client:net.TCP_Socket) {
    if !send_text(client,"HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nX-Accel-Buffering: no\r\n\r\nretry: 1000\n\n") {return}
    last_sequence: int = -1
    heartbeat:int
    for {
        s:=snapshot()
        if s.sequence!=last_sequence {
            message:=fmt.tprintf("id: %d-%d\nevent: build\ndata: %s\"server\":\"%d\",\"revision\":%d,\"error\":%s,\"building\":%s%s\n\n",
                server_id,s.sequence,"{",server_id,s.revision,s.failed?"true":"false",s.building?"true":"false","}")
            if !send_text(client,message) {return}
            last_sequence=s.sequence
            heartbeat=0
        } else if heartbeat>=100 {
            if !send_text(client,": heartbeat\n\n") {return}
            heartbeat=0
        }
        free_all(context.temp_allocator)
        time.sleep(100*time.Millisecond)
        heartbeat+=1
    }
}
respond :: proc(client:net.TCP_Socket,status,mime:string,body:[]u8) {
    header:=fmt.tprintf("HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",status,mime,len(body))
    if send_text(client,header) {net.send_tcp(client,body)}
}
serve :: proc(client:net.TCP_Socket) {
    defer net.close(client)
    _=net.set_option(client,.Receive_Timeout,5*time.Second)
    _=net.set_option(client,.Send_Timeout,5*time.Second)
    request:[8192]u8
    n:int
    for n<len(request) {
        received,err:=net.recv_tcp(client,request[n:])
        if err!=nil || received==0 {return}
        n+=received
        if strings.contains(string(request[:n]),"\r\n\r\n") {break}
    }
    parts:=strings.split(string(request[:n])," ",context.temp_allocator)
    if len(parts)<2 || parts[0]!="GET" {return}
    path:=strings.split(parts[1],"?",context.temp_allocator)[0]
    if path=="/__events" {events(client);return}
    if path=="/" || path=="/index.html" {
        send_text(client,"HTTP/1.1 302 Found\r\nLocation: /buttons\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
        return
    }
    file,mime:string
    if _,ok:=routes.index(path);ok {
        file="web/index.html";mime="text/html; charset=utf-8"
    } else {
        switch path {
        case "/app.js": file="web/app.js";mime="text/javascript"
        case "/app.wasm": file="web/app.wasm";mime="application/wasm"
        case "/fonts/WorkSans.ttf": file="web/fonts/WorkSans.ttf";mime="font/ttf"
        case "/fonts/Hasklig-Regular.ttf": file="web/fonts/Hasklig-Regular.ttf";mime="font/ttf"
        case "/favicon.svg": file="web/favicon.svg";mime="image/svg+xml"
        case "/favicon.ico": file="web/favicon.ico";mime="image/x-icon"
        case: respond(client,"404 Not Found","text/plain",transmute([]u8)string("Not found"));return
        }
    }
    sync.mutex_lock(&assets_mutex)
    data,e:=os.read_entire_file(file,context.temp_allocator)
    sync.mutex_unlock(&assets_mutex)
    if e!=nil {respond(client,"503 Service Unavailable","text/plain",transmute([]u8)string("Build unavailable. Check terminal."));return}
    respond(client,"200 OK",mime,data)
}
main :: proc() {
    server_id=time.to_unix_nanoseconds(time.now())
    initial:=fingerprint();free_all(context.temp_allocator)
    port:=os.get_env("KRIYA_PORT",context.temp_allocator)
    if port=="" {port="8000"}
    address:=fmt.aprintf("127.0.0.1:%s",port)
    endpoint,valid:=net.parse_endpoint(address)
    if !valid {fmt.eprintln("Invalid KRIYA_PORT:",port);os.exit(1)}
    listener,err:=net.listen_tcp(endpoint)
    if err!=nil {fmt.eprintln("Cannot listen on",address,err);os.exit(1)}
    defer net.close(listener)
    build()
    thread.create_and_start_with_poly_data(initial,watch,self_cleanup=true)
    fmt.printfln("Kriya → http://%s/buttons  (Ctrl+C to stop)",address)
    for {
        client,_,e:=net.accept_tcp(listener)
        if e==nil {thread.create_and_start_with_poly_data(client,serve,self_cleanup=true)}
    }
}
