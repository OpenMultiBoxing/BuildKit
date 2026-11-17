/*
 * runtime9.exe's app init: Tk's wish init (winMain.c, built with TK_LOCAL_APPINIT=OmbAppInit) plus our binary
 * extensions linked in as static packages, so `load {} Twapi` / `load {} Cffi` (their pkgIndex.tcl) need no DLL:
 * Tcl would copy a DLL from the exe's zip to %TEMP% to load it, where Smart App Control blocks it (unsigned).
 */
#include "tcl.h"

extern int Tcl_AppInit(Tcl_Interp *interp);
extern int Twapi_Init(Tcl_Interp *interp);
extern int Cffi_Init(Tcl_Interp *interp);

int
OmbAppInit(Tcl_Interp *interp)
{
    /* NULL interp: only registered, initialized by `load {} Name` when the package is required */
    Tcl_StaticLibrary(NULL, "Twapi", Twapi_Init, NULL);
    Tcl_StaticLibrary(NULL, "Cffi", Cffi_Init, NULL);
    return Tcl_AppInit(interp);
}
