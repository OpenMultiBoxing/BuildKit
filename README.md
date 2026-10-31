# BuildKit
Dependencies to build [WOB/OBM](https://github.com/WowOpenBox/WowOpenBox#wowopenbox) binaries, ie a single binary with Tcl/Tk+TWAPI+misc dependencies

[OpenMultiBoxing_RR](OpenMultiBoxing_RR/) is a small program to start OpenMultiBoxing.exe as a child program in debug mode (which allows that child to set window focus)

Note that the license of each component is their own

Source of info and data:

http://kitcreator.rkeene.org/fossil/home

## Signable build: runtime-zip.exe + build.ps1

`build.ps1 -Out OpenMultiBoxing-vX.Y.Z.exe -Version vX.Y.Z` (with OpenMultiBoxing.tcl already in
`OpenMultiBoxing.vfs/app`) makes the exe from [runtime-zip.exe](runtime-zip.exe): sets our icon,
[app.manifest](app.manifest) (high DPI) and version info (from `OpenMultiBoxing.vfs/tclkit.inf`), and appends one zip
with the kit's files and the vfs. No sdx/mt.exe.

Unlike the Metakit runtime.exe below, that exe still works once Authenticode signed (the signature goes after the
VFS, at the end of the file). build.ps1 also fixes a tclvfs `zip::EndOfArchive` bug in the kit's boot code, without
which a signed kit can't find its files (offsets 28 bytes off when the zip end isn't in the last 512 bytes).

runtime-zip.exe: http://kitcreator.rkeene.org/kits/e496d9f89daf0e525e30324eed52774652d7c167/tclkit.exe
Description: Tcl 8.6.10, KitCreator 0.12.0, Platform win64, Zip-kit, Threaded, Packages: tk
(http://kitcreator.rkeene.org/kitcreator: those options and Kit Storage: Zip)

Same as WowOpenBox/BuildKit's.

## Metakit runtime (sdx wrap, can't be signed)

Need to pick MetaKit or you get a vfs error later
Need the runtime to be threaded

For the runtime: (runtime.exe)

URL: http://kitcreator.rkeene.org/kits/building/7dd39658b1f9a7ebf35ca10ca66f0a5630e049dc/
Description: Tcl 8.6.10, KitCreator 0.12.0, Platform win64, Threaded, Packages: mk4tcl, tk

For build time: same without Tk: (tclkit/tclkit.exe)
URL: http://kitcreator.rkeene.org/kits/8ab68b842c29538075259d620218331cae45e995/
Description: Tcl 8.6.10, KitCreator 0.12.0, Platform win64, Without Tcl pkgs/ and all encodings, Unthreaded, Packages: mk4tcl

https://www.magicsplat.com/blog/starpack-example/

twapi bin https://sourceforge.net/projects/twapi/files/Current%20Releases/Tcl%20Windows%20API/twapi-4.5.2/twapi-bin-4.5.2.zip/download

sdx kit : https://chiselapp.com/user/aspect/repository/sdx/uv/sdx-20110317.kit

tooltip is from tklib https://core.tcl-lang.org/tklib/wiki?name=Releases

tkdnd is from https://github.com/petasis/tkdnd/releases

cffi 1.2.0 (win32-x86_64 dll only) is from https://sourceforge.net/projects/magicsplat/files/cffi/cffi1.2.0-bin-win.zip/download (used for DWM thumbnails, see [zoomtest.tcl](zoomtest.tcl): `runtime.exe zoomtest.tcl "title glob" ?scale? ?clickthrough? ?topmost? ?srcX srcY srcW srcH? ?dstX dstY?`, without a source rect: drag to select it)


Manually added our ico to runtime.exe as sdx seems unable to otherwise replace them all
