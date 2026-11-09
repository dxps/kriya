package routes

Section :: struct {
    title:string,
    path:cstring,
}

SECTIONS :: [?]Section{
    {"Buttons", "/buttons"},
    {"Inputs", "/inputs"},
    {"Dropdowns", "/dropdowns"},
    {"Checkboxes", "/checkboxes"},
    {"Typography", "/typography"},
    {"Composition", "/composition"},
}

index :: proc(path:string)->(int,bool) {
    for section,i in SECTIONS {
        if path==string(section.path) {return i,true}
    }
    return 0,false
}
