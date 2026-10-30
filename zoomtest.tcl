# Spike: show a zoomed live region of another window using DWM thumbnails
# Usage: runtime.exe zoomtest.tcl "title glob" ?srcX srcY srcW srcH? ?scale? ?dstX dstY? ?clickthrough?
lappend auto_path [file join [file dirname [info script]] OpenMultiBoxing.vfs lib]
package require Tk
package require twapi
package require cffi

cffi::Wrapper create dwmapi [file join $env(windir) system32 dwmapi.dll]
cffi::Struct create RECT {left long top long right long bottom long}
cffi::Struct create DWM_THUMBNAIL_PROPERTIES {
    dwFlags ulong rcDestination struct.RECT rcSource struct.RECT
    opacity uchar fVisible int fSourceClientAreaOnly int
}
# HWND/HTHUMBNAIL as 64 bit ints (win64 only)
dwmapi stdcall DwmRegisterThumbnail long {dest ulonglong src ulonglong thumb {ulonglong out}}
dwmapi stdcall DwmUpdateThumbnailProperties long {thumb ulonglong props {struct.DWM_THUMBNAIL_PROPERTIES byref}}
dwmapi stdcall DwmUnregisterThumbnail long {thumb ulonglong}

set DWM_TNP_ALL 0x1f

lassign $argv pattern sx sy sw sh scale dx dy click
foreach {v d} {sx 0 sy 0 sw 200 sh 200 scale 2 dx 100 dy 100 click 1} {
    if {[set $v] eq ""} {set $v $d}
}
set src [lindex [twapi::find_windows -match glob -text $pattern -toplevel true -visible true] 0]
if {$src eq ""} {
    puts stderr "No window matching $pattern"
    exit 1
}
puts "Source: $src [twapi::get_window_text $src]"
set dw [expr {round($sw*$scale)}]
set dh [expr {round($sh*$scale)}]

wm withdraw .
toplevel .z -background black
wm overrideredirect .z 1
wm attributes .z -topmost 1
wm geometry .z ${dw}x${dh}+$dx+$dy
update
set dest [expr {[wm frame .z]}]
if {$click} {
    # layered (via -alpha) + transparent = click-through, plus no activate and no taskbar entry
    wm attributes .z -alpha 0.99
    set h [list $dest HWND]
    lassign [twapi::get_window_style $h] style exstyle
    twapi::set_window_style $h $style [expr {$exstyle | 0x08080020 | 0x80}]
}

set hr [DwmRegisterThumbnail $dest [expr {[lindex $src 0]}] thumb]
puts "DwmRegisterThumbnail -> $hr thumb=$thumb"
set props [dict create dwFlags $DWM_TNP_ALL\
    rcDestination [dict create left 0 top 0 right $dw bottom $dh]\
    rcSource [dict create left $sx top $sy right [expr {$sx+$sw}] bottom [expr {$sy+$sh}]]\
    opacity 255 fVisible 1 fSourceClientAreaOnly 1]
puts "DwmUpdateThumbnailProperties -> [DwmUpdateThumbnailProperties $thumb $props]"

# Escape (while focused) or closing the source ends the test
bind .z <Escape> exit
proc Check {} {
    global src thumb
    if {![twapi::window_exists $src]} {
        DwmUnregisterThumbnail $thumb
        exit
    }
    after 1000 Check
}
Check
