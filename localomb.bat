copy ..\OpenMultiBoxing\OpenMultiBoxing.tcl OpenMultiBoxing.vfs\app\
tclkit\tclkit.exe  sdx/sdx.kit wrap OpenMultiBoxing -runtime runtime.exe
del OpenMultiBoxing.exe
rename OpenMultiBoxing OpenMultiBoxing.exe
rem .\OpenMultiBoxing.exe -debug
.\rrenable-debug.exe
