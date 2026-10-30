# Spike: show a zoomed live region of another window using DWM thumbnails
# Usage: runtime.exe zoomtest.tcl "title glob" ?scale? ?clickthrough? ?srcX srcY srcW srcH? ?dstX dstY?
# Without a source rect: drag a selection rectangle over the source window (Esc cancels).
# Zoom window (when not clickthrough): drag to move, wheel to zoom, right click to reselect, Esc to quit.
lappend auto_path [file join [file dirname [info script]] OpenMultiBoxing.vfs lib]
package require Tk
package require twapi
package require cffi

cffi::Wrapper create dwmapi [file join $env(windir) system32 dwmapi.dll]
cffi::Wrapper create user32 [file join $env(windir) system32 user32.dll]
cffi::Struct create RECT {left long top long right long bottom long}
cffi::Struct create POINT {x long y long}
cffi::Struct create DWM_THUMBNAIL_PROPERTIES {
    dwFlags ulong rcDestination struct.RECT rcSource struct.RECT
    opacity uchar fVisible int fSourceClientAreaOnly int
}
# HWND/HTHUMBNAIL as 64 bit ints (win64 only)
dwmapi stdcall DwmRegisterThumbnail long {dest ulonglong src ulonglong thumb {ulonglong out}}
dwmapi stdcall DwmUpdateThumbnailProperties long {thumb ulonglong props {struct.DWM_THUMBNAIL_PROPERTIES byref}}
dwmapi stdcall DwmUnregisterThumbnail long {thumb ulonglong}
user32 stdcall ClientToScreen int {hwnd ulonglong pt {struct.POINT inout}}

set DWM_TNP_ALL 0x1f

lassign $argv pattern scale click sx sy sw sh dx dy
if {$scale eq ""} {set scale 2}
if {$click eq ""} {set click 0}
set src [lindex [twapi::find_windows -match glob -text $pattern -toplevel true -visible true] 0]
if {$src eq ""} {
    tk_messageBox -icon error -message "No window matching $pattern"
    exit 1
}
set srcId [expr {[lindex $src 0]}]
wm withdraw .

# Returns the screen position and size of the source client area
proc SourceClient {} {
    global src srcId
    set pt [dict create x 0 y 0]
    ClientToScreen $srcId pt
    lassign [twapi::get_window_client_area_size $src] w h
    list [dict get $pt x] [dict get $pt y] $w $h
}

# Transparent overlay on the source client area to drag a rectangle on
proc Select {} {
    global thumb
    if {[info exists thumb]} {
        DwmUnregisterThumbnail $thumb
        unset thumb
    }
    destroy .z
    lassign [SourceClient] x y w h
    toplevel .sel -cursor crosshair
    wm overrideredirect .sel 1
    wm attributes .sel -topmost 1 -alpha 0.35
    wm geometry .sel ${w}x${h}+$x+$y
    canvas .sel.c -background gray20 -highlightthickness 0
    pack .sel.c -fill both -expand 1
    bind .sel.c <ButtonPress-1> {
        set ::selStart [list %x %y]
        .sel.c delete r
        .sel.c create rectangle %x %y %x %y -outline red -width 2 -tags r
    }
    bind .sel.c <B1-Motion> {.sel.c coords r {*}$::selStart %x %y}
    bind .sel.c <ButtonRelease-1> {SelectDone {*}$::selStart %x %y}
    bind .sel <Escape> exit
    update
    focus -force .sel.c
}

proc SelectDone {x1 y1 x2 y2} {
    global sx sy sw sh
    if {abs($x2-$x1) < 5 || abs($y2-$y1) < 5} {
        return
    }
    set sx [expr {min($x1,$x2)}]
    set sy [expr {min($y1,$y2)}]
    set sw [expr {abs($x2-$x1)}]
    set sh [expr {abs($y2-$y1)}]
    destroy .sel
    Zoom
}

proc Zoom {} {
    global src srcId sx sy sw sh dx dy scale click thumb DWM_TNP_ALL
    if {$dx eq ""} {
        # next to the source client area
        lassign [SourceClient] x y w h
        set dx [expr {$x + $w}]
        set dy $y
    }
    set dw [expr {round($sw*$scale)}]
    set dh [expr {round($sh*$scale)}]
    if {![winfo exists .z]} {
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
        } else {
            bind .z <ButtonPress-1> {focus -force .z; set ::moveFrom [list %X %Y [winfo rootx .z] [winfo rooty .z]]}
            bind .z <B1-Motion> {
                lassign $::moveFrom mx my wx wy
                set ::dx [expr {$wx + %X - $mx}]
                set ::dy [expr {$wy + %Y - $my}]
                wm geometry .z +$::dx+$::dy
            }
            bind .z <Button-3> Select
            bind .z <MouseWheel> {set ::scale [expr {max(0.1, $::scale * (%D > 0 ? 1.25 : 0.8))}]; Zoom}
            bind .z <Escape> exit
        }
        set hr [DwmRegisterThumbnail $dest $srcId thumb]
        if {$hr != 0} {
            tk_messageBox -icon error -message "DwmRegisterThumbnail failed: $hr"
            exit 1
        }
    } else {
        wm geometry .z ${dw}x${dh}
    }
    set props [dict create dwFlags $DWM_TNP_ALL\
        rcDestination [dict create left 0 top 0 right $dw bottom $dh]\
        rcSource [dict create left $sx top $sy right [expr {$sx+$sw}] bottom [expr {$sy+$sh}]]\
        opacity 255 fVisible 1 fSourceClientAreaOnly 1]
    DwmUpdateThumbnailProperties $thumb $props
    wm title .z "zoom $sx,$sy ${sw}x$sh x$scale"
}

# closing the source ends the test
proc Check {} {
    global src
    if {![twapi::window_exists $src]} {
        exit
    }
    after 1000 Check
}
Check

if {$sh eq ""} {
    Select
} else {
    Zoom
}
