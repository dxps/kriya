package main

import "core:fmt"
import "core:os"
import "core:net"
import "core:strings"

revision:int
failed:bool
source_hash:u64

fingerprint :: proc()->u64 {
    h:u64=14695981039346656037
    for root in ([]string{"apps","kriya","backends","web/fonts","scripts"}) {
        walker:=os.walker_create(root)
        for info in os.walker_walk(&walker) {
            if info.type==.Directory {continue}
            data,err:=os.read_entire_file(info.fullpath,context.temp_allocator)
            if err==nil {for b in data {h=(h~u64(b))*1099511628211}}
        }
        os.walker_destroy(&walker)
    }
    data,_:=os.read_entire_file("web/index.html",context.temp_allocator)
    for b in data {h=(h~u64(b))*1099511628211}
    glue,_:=os.read_entire_file("web/odin-library.js",context.temp_allocator)
    for b in glue {h=(h~u64(b))*1099511628211}
    return h
}
build :: proc() {
    fmt.println("Building gallery…")
    p,err:=os.process_start({command=[]string{"sh","scripts/build-web.sh"},stdout=os.stdout,stderr=os.stderr})
    if err!=nil {fmt.eprintln(err);failed=true;return}
    state,wait_err:=os.process_wait(p)
    failed=wait_err!=nil || state.exit_code!=0
    if !failed {revision+=1;fmt.println("Build ready.")}
}
respond :: proc(client:net.TCP_Socket,status,mime:string,body:[]u8) {
    header:=fmt.tprintf("HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",status,mime,len(body))
    net.send_tcp(client,transmute([]u8)header)
    net.send_tcp(client,body)
}
serve :: proc(client:net.TCP_Socket) {
    defer net.close(client)
    request:[8192]u8
    n,err:=net.recv_tcp(client,request[:])
    if err!=nil || n==0 {return}
    parts:=strings.split(string(request[:n])," ",context.temp_allocator)
    if len(parts)<2 || parts[0]!="GET" {return}
    path:=parts[1]
    if path=="/__dev" {
        current:=fingerprint()
        if current!=source_hash {source_hash=current;build()}
        body:=fmt.tprintf("%s\"revision\":%d,\"error\":%s%s","{",revision,failed?"true":"false","}")
        respond(client,"200 OK","application/json",transmute([]u8)body)
        return
    }
    file,mime:string
    switch path {
    case "/","/index.html": file="web/index.html";mime="text/html; charset=utf-8"
    case "/app.js": file="web/app.js";mime="text/javascript"
    case "/app.wasm": file="web/app.wasm";mime="application/wasm"
    case "/fonts/WorkSans.ttf": file="web/fonts/WorkSans.ttf";mime="font/ttf"
    case: respond(client,"404 Not Found","text/plain",[]u8{'N','o','t',' ','f','o','u','n','d'});return
    }
    data,e:=os.read_entire_file(file,context.temp_allocator)
    if e!=nil {respond(client,"503 Service Unavailable","text/plain",transmute([]u8)string("Build unavailable. Check terminal."));return}
    respond(client,"200 OK",mime,data)
}
main :: proc() {
    source_hash=fingerprint();build()
    endpoint,_:=net.parse_endpoint("127.0.0.1:8000")
    listener,err:=net.listen_tcp(endpoint)
    if err!=nil {fmt.eprintln("Cannot listen on 127.0.0.1:8000:",err);os.exit(1)}
    defer net.close(listener)
    fmt.println("Kriya → http://localhost:8000  (Ctrl+C to stop)")
    for {
        client,_,e:=net.accept_tcp(listener)
        if e==nil {serve(client)}
        free_all(context.temp_allocator)
    }
}
