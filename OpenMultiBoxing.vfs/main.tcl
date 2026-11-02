if {[package vsatisfies [package provide Tcl] 9-]} {
    # Tcl 9 zipfs kit: no starkit, add our packages
    lappend auto_path [file join [file dirname [info script]] lib]
} else {
    package require starkit
    starkit::startup
}
# the app's script: OpenMultiBoxing.tcl or WowOpenBox.tkapp (same BuildKit for both)
set appScript [lindex [lsort [glob -nocomplain -directory [file join [file dirname [info script]] app] *.tcl *.tkapp]] 0]
source -encoding utf-8 $appScript
unset appScript
