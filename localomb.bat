copy ..\OpenMultiBoxing\OpenMultiBoxing.tcl OpenMultiBoxing.vfs\app\
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Out OpenMultiBoxing.exe
rem .\OpenMultiBoxing.exe -debug
.\rrenable-debug.exe
