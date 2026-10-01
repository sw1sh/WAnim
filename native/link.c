/* LibraryLink: wanimRender[wxf bytes, width, height] -> the frame, a NumericArray {height, width, 4} of bytes */
#include "WolframLibrary.h"
#include "WolframNumericArrayLibrary.h"
#include "wanimgpu.h"
#include <string.h>
#include <stdio.h>

static Frame frame;
static char lastError[256];

DLLEXPORT mint WolframLibrary_getVersion(void) { return WolframLibraryVersion; }
DLLEXPORT int WolframLibrary_initialize(WolframLibraryData lib) { (void)lib; return 0; }
DLLEXPORT void WolframLibrary_uninitialize(WolframLibraryData lib) { (void)lib; }

static int fail(WolframLibraryData lib, const char *msg) {
    strncpy(lastError, msg, sizeof lastError - 1);
    (void)lib;
    return LIBRARY_FUNCTION_ERROR;
}
DLLEXPORT int wanimRender(WolframLibraryData lib, mint argc, MArgument *args, MArgument res) {
    if (argc != 3) return LIBRARY_FUNCTION_ERROR;
    WolframNumericArrayLibrary_Functions na = lib->numericarrayLibraryFunctions;
    MNumericArray in = MArgument_getMNumericArray(args[0]);
    mint w = MArgument_getInteger(args[1]), h = MArgument_getInteger(args[2]);
    if (w < 1 || h < 1 || w > 16384 || h > 16384) return fail(lib, "bad size");
    char err[256] = "";
    if (gpu_init(err, sizeof err)) return fail(lib, err);
    const uint8_t *bytes = na->MNumericArray_getData(in);
    mint len = na->MNumericArray_getFlattenedLength(in);
    arena_reset();
    WNode *g = wxf_parse(bytes, (size_t)len);
    if (!g) return fail(lib, "not WXF");
    frame_begin(&frame, (int)w, (int)h);
    int r = scene_draw(&frame, g);
    if (r == 3) { text_reset(); frame_begin(&frame, (int)w, (int)h); r = scene_draw(&frame, g); }   /* the atlas filled up: once more, from empty */
    if (r == 4) { char m[200]; snprintf(m, sizeof m, "unsupported: %s", scene_unsupported()); return fail(lib, m); }
    if (r) return fail(lib, r == 1 ? "not a Graphics" : r == 2 ? "no explicit PlotRange" : "too much text");
    MNumericArray out;
    mint dims[3] = {h, w, 4};
    if (na->MNumericArray_new(MNumericArray_Type_UBit8, 3, dims, &out)) return fail(lib, "out of memory");
    if (gpu_render(&frame, na->MNumericArray_getData(out))) { na->MNumericArray_free(out); return fail(lib, "render failed"); }
    MArgument_setMNumericArray(res, out);
    return LIBRARY_NO_ERROR;
}
/* the last error, as a string */
DLLEXPORT int wanimError(WolframLibraryData lib, mint argc, MArgument *args, MArgument res) {
    (void)lib; (void)argc; (void)args;
    MArgument_setUTF8String(res, lastError);
    return LIBRARY_NO_ERROR;
}
