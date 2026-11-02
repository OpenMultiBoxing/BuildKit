del /q OpenMultiBoxing.vfs\app\*.tkapp 2>nul
copy ..\OpenMultiBoxing\OpenMultiBoxing.tcl OpenMultiBoxing.vfs\app\
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Out OpenMultiBoxing.exe -Assets ..\OpenMultiBoxing\msix\Assets
rem .\OpenMultiBoxing.exe -debug
