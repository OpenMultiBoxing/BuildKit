if {[package vsatisfies [package provide Tcl] 9-]} {
    # Tcl 9 zipfs kit: no starkit, add our packages
    lappend auto_path [file join [file dirname [info script]] lib]
} else {
    package require starkit
    starkit::startup
}
source -encoding utf-8 [file join [file dirname [info script]] app OpenMultiBoxing.tcl]
