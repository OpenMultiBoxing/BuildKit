del /q OpenMultiBoxing.vfs\app\OpenMultiBoxing.tcl 2>nul
copy ..\WowOpenBox\WowOpenBox.tcl OpenMultiBoxing.vfs\app\WowOpenBox.tkapp
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 -Out WOB2027.exe -Assets ..\WowOpenBox\msix\Assets -Inf wob.inf
rem .\WOB2027.exe -debug
