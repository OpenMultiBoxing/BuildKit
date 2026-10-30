#
# Tcl package index file - generated from pkgIndex.tcl.in
#

package ifneeded cffi 1.2.0 \
    [list apply [list {dir} {
        set dllname "tclcffi120.dll"
        set package "cffi"
        set package_ns ::$package

        # First try to load from current directory. If that fails, try from
        # arch-specific subdirectories
        set path [file join $dir $dllname]
        if {[catch {uplevel #0 [list load $path $package]}]} {
            package require platform
            foreach platform [platform::patterns [platform::identify]] {
                if {$platform eq "tcl"} continue
                set path [file join $dir $platform $dllname]
                if {![catch {uplevel #0 [list load $path $package]}]} {
                    break
                }
            }
        }
        if {[namespace exists $package_ns]} {
            # Load was successful
            set ${package_ns}::dll_path $path
            set ${package_ns}::package_dir $dir
        }
    }] $dir]
