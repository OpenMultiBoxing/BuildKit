# cffi linked into the runtime as a static package (made by runtime9.yml)
package ifneeded cffi 2.0.3 [list apply {{dir} {
    load {} Cffi
    set ::cffi::dll_path {}
    set ::cffi::package_dir $dir
}} $dir]
