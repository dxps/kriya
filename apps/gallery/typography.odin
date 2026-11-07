package main
import ui "kriya:ui"

draw_typography :: proc(c:^ui.Context) {
    ui.label(c,302,280,"Work Sans",48)
    ui.label(c,302,328,"A clear voice for everyday interfaces.",24)
    ui.label(c,302,374,"ABCDEFGHIJKLMNOPQRSTUVWXYZ",18)
    ui.label(c,302,410,"abcdefghijklmnopqrstuvwxyz 0123456789",18)
}
