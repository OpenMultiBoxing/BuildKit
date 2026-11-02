# BuildKit
Dependencies to build [WOB/OBM](https://github.com/WowOpenBox/WowOpenBox#wowopenbox) binaries, ie a single binary with Tcl/Tk+TWAPI+misc dependencies

[OpenMultiBoxing_RR](OpenMultiBoxing_RR/) is a small program to start OpenMultiBoxing.exe as a child program in debug mode (which allows that child to set window focus)

Note that the license of each component is their own

Source of info and data:

http://kitcreator.rkeene.org/fossil/home

## Tcl/Tk 9: runtime9.exe

`build.ps1` defaults to [runtime9.exe](runtime9.exe) and [app9.manifest](app9.manifest): a static
Tcl/Tk 9.1.0 wish built by [.github/workflows/runtime9.yml](.github/workflows/runtime9.yml) (static C runtime: only
Windows' own DLLs needed), with the Tcl/Tk libraries in its zip. Tcl 9's zipfs mounts the exe's zip at `//zipfs:/app`
and runs its `main.tcl` (no tclkit/starkit/tclvfs). `OpenMultiBoxing.vfs/lib` has the Tcl 9 packages: twapi 5.2.0
and cffi 2.0.3 from that workflow (built against Tcl 9.0.4, stubs), tooltip 2.0.2 from tklib 0.9. No tkdnd (unused).

To update them (new Tcl/Tk, twapi or cffi release):
1. Change `TCL_TAG`, `TWAPI_TAG` or `CFFI_TAG` in `runtime9.yml` on a branch. Pushing that file to `main` also runs
   it; otherwise Actions > "Tcl 9 runtime" > Run workflow (on the branch).
2. `gh run download <run id> -R OpenMultiBoxing/BuildKit -n runtime9 -D out`
3. Copy `out/runtime9.exe` here, replace `OpenMultiBoxing.vfs/lib/twapi*` and `cffi*` with `out/lib/*`. Same for
   WowOpenBox/BuildKit, which uses these same files.
4. Build the app and run its tests (`tests/run.sh` with `OMB_EXE` set to it), then PR.

## Signable build: runtime-zip.exe + build.ps1

Used by both OpenMultiBoxing and WowOpenBox (WOB2027):
- `build.ps1 -Out OpenMultiBoxing-vX.Y.Z.exe -Version vX.Y.Z -Assets ..\OpenMultiBoxing\msix\Assets` (with
  OpenMultiBoxing.tcl already in `OpenMultiBoxing.vfs/app`)
- `build.ps1 -Out WOB2027-vX.Y.Z.exe -Version vX.Y.Z -Assets ..\WowOpenBox\msix\Assets -Inf wob.inf` (with
  WowOpenBox.tkapp in `OpenMultiBoxing.vfs/app`)

It makes the exe from the runtime (runtime9.exe, was [runtime-zip.exe](runtime-zip.exe)): sets the app's icon (made
from its Store icons, `-Assets`), the manifest (high DPI) and version info (from [omb.inf](omb.inf) or
[wob.inf](wob.inf)), and appends one zip with the kit's files and the vfs. No sdx/mt.exe. `main.tcl` runs the app
script found in `app/`.

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
