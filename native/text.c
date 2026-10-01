/* Text by CoreText -- the shaping and the glyphs the front end itself uses on macOS.  A line is laid out
   once per font, size and string (kerning, fallback fonts for missing characters); each glyph is
   rasterized once per size and quarter-pixel phase into a single-channel atlas the GPU samples. */
#include "wanimgpu.h"
#include <CoreText/CoreText.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* ---- faces: a family at a weight and slant, the closest the family has ---- */
typedef struct { char *family; int weight, italic; CTFontDescriptorRef desc; } Face;
static Face *faces; static int nfaces, cfaces;
/* CSS weights to CoreText's weight trait */
static double ctweight(int w) {
    static const double t[] = {-0.8, -0.6, -0.4, 0.0, 0.23, 0.3, 0.4, 0.56, 0.62};
    int k = (w + 50) / 100 - 1; if (k < 0) k = 0; if (k > 8) k = 8;
    return t[k];
}
static CTFontDescriptorRef face(const char *family, int weight, int italic) {
    for (int k = 0; k < nfaces; k++)
        if (faces[k].weight == weight && faces[k].italic == italic && !strcmp(faces[k].family, family)) return faces[k].desc;
    CFStringRef name = CFStringCreateWithCString(NULL, family, kCFStringEncodingUTF8);
    CFDictionaryRef attrs = CFDictionaryCreate(NULL, (const void **)&kCTFontFamilyNameAttribute, (const void **)&name, 1,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CTFontDescriptorRef fam = CTFontDescriptorCreateWithAttributes(attrs);
    CFArrayRef all = CTFontDescriptorCreateMatchingFontDescriptors(fam, NULL);
    CTFontDescriptorRef best = NULL; double bestd = 1e9, target = ctweight(weight);
    for (CFIndex k = 0; all && k < CFArrayGetCount(all); k++) {
        CTFontDescriptorRef d = CFArrayGetValueAtIndex(all, k);
        CFDictionaryRef tr = CTFontDescriptorCopyAttribute(d, kCTFontTraitsAttribute);
        double w = 0; uint32_t sym = 0;
        if (tr) {
            CFNumberRef n = CFDictionaryGetValue(tr, kCTFontWeightTrait); if (n) CFNumberGetValue(n, kCFNumberDoubleType, &w);
            CFNumberRef s = CFDictionaryGetValue(tr, kCTFontSymbolicTrait); if (s) CFNumberGetValue(s, kCFNumberSInt32Type, &sym);
            CFRelease(tr);
        }
        double dd = fabs(w - target) + (((sym & kCTFontItalicTrait) != 0) != (italic != 0) ? 10 : 0);
        if (dd < bestd) { bestd = dd; best = d; }
    }
    if (best) CFRetain(best);
    else best = CTFontDescriptorCreateWithNameAndSize(CFSTR("Helvetica"), 12);   /* a family that is not installed */
    if (all) CFRelease(all);
    CFRelease(fam); CFRelease(attrs); CFRelease(name);
    if (nfaces == cfaces) { cfaces = cfaces ? 2 * cfaces : 16; faces = realloc(faces, sizeof(Face) * cfaces); }
    faces[nfaces++] = (Face){strdup(family), weight, italic, best};
    return best;
}

/* ---- fonts at a size (quarter points), kept alive: glyphs refer to them ---- */
typedef struct { CTFontDescriptorRef desc; int q; CTFontRef font; } Sized;
static Sized *sized; static int nsized, csized;
static CTFontRef fontAt(CTFontDescriptorRef d, float size) {
    int q = (int)lroundf(size * 4);
    for (int k = nsized - 1; k >= 0; k--) if (sized[k].desc == d && sized[k].q == q) return sized[k].font;
    CTFontRef f = CTFontCreateWithFontDescriptor(d, q / 4.0, NULL);
    if (nsized == csized) { csized = csized ? 2 * csized : 64; sized = realloc(sized, sizeof(Sized) * csized); }
    sized[nsized++] = (Sized){d, q, f};
    return f;
}
/* fallback fonts CoreText picks for a run, retained for as long as the caches */
static CTFontRef *kept; static int nkept, ckept;
static CTFontRef keep(CTFontRef f) {
    for (int k = 0; k < nkept; k++) if (CFEqual(kept[k], f)) return kept[k];
    if (nkept == ckept) { ckept = ckept ? 2 * ckept : 32; kept = realloc(kept, sizeof(CTFontRef) * ckept); }
    CFRetain(f); kept[nkept++] = f;
    return f;
}

/* ---- layouts, by font and string ---- */
typedef struct { CTFontRef font; char *s; uint64_t h; Layout lay; } LEntry;
static LEntry *lays; static int clays, nlays;
static uint64_t fnv(const char *s, uint64_t h) { while (*s) { h ^= (uint8_t)*s++; h *= 1099511628211ULL; } return h; }
static void layclear(void) {
    for (int k = 0; k < clays; k++) if (lays[k].s) { free(lays[k].s); free(lays[k].lay.g); }
    memset(lays, 0, sizeof(LEntry) * clays); nlays = 0;
}
const Layout *text_layout(const char *family, int weight, int italic, float size, const char *utf8) {
    CTFontRef font = fontAt(face(family, weight, italic), size);
    uint64_t h = fnv(utf8, 1469598103934665603ULL ^ (uint64_t)(uintptr_t)font);
    if (!clays) { clays = 1 << 16; lays = calloc(clays, sizeof(LEntry)); }
    if (nlays > clays / 2) layclear();
    int k = (int)(h & (clays - 1));
    for (; lays[k].s; k = (k + 1) & (clays - 1))
        if (lays[k].h == h && lays[k].font == font && !strcmp(lays[k].s, utf8)) return &lays[k].lay;
    LEntry *e = &lays[k];
    e->font = font; e->h = h; e->s = strdup(utf8); nlays++;
    CFStringRef str = CFStringCreateWithCString(NULL, utf8, kCFStringEncodingUTF8);
    if (!str) str = CFStringCreateWithCString(NULL, "", kCFStringEncodingUTF8);
    CFDictionaryRef attrs = CFDictionaryCreate(NULL, (const void **)&kCTFontAttributeName, (const void **)&font, 1,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef as = CFAttributedStringCreate(NULL, str, attrs);
    CTLineRef line = CTLineCreateWithAttributedString(as);
    CGFloat asc, desc, lead;
    e->lay.advance = (float)CTLineGetTypographicBounds(line, &asc, &desc, &lead);
    /* the line's metrics are its font's, whatever the fallbacks */
    e->lay.ascent = (float)CTFontGetAscent(font); e->lay.descent = (float)CTFontGetDescent(font); e->lay.leading = (float)CTFontGetLeading(font);
    CFIndex total = CTLineGetGlyphCount(line);
    e->lay.g = malloc(sizeof(Glyph) * (total ? total : 1)); e->lay.n = 0;
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    for (CFIndex r = 0; r < CFArrayGetCount(runs); r++) {
        CTRunRef run = CFArrayGetValueAtIndex(runs, r);
        CTFontRef rf = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
        rf = keep(rf ? rf : font);
        CFIndex n = CTRunGetGlyphCount(run);
        CGGlyph *gs = malloc(sizeof(CGGlyph) * (n ? n : 1)); CGPoint *ps = malloc(sizeof(CGPoint) * (n ? n : 1));
        CTRunGetGlyphs(run, CFRangeMake(0, 0), gs); CTRunGetPositions(run, CFRangeMake(0, 0), ps);
        for (CFIndex j = 0; j < n; j++) e->lay.g[e->lay.n++] = (Glyph){(void *)rf, gs[j], (float)ps[j].x, -(float)ps[j].y};
        free(gs); free(ps);
    }
    CFRelease(line); CFRelease(as); CFRelease(attrs); CFRelease(str);
    return &e->lay;
}

/* ---- the atlas: shelves of glyph bitmaps ---- */
static uint8_t *atlas; static int shelfX, shelfY, shelfH, dirty0 = ATLAS, dirty1 = -1;
typedef struct { void *font; uint32_t key; GlyphQuad q; int used; } GEntry;
#define GCAP (1 << 18)
static GEntry *gl; static int ngl;
uint8_t *atlas_pixels(void) { if (!atlas) atlas = calloc(ATLAS, ATLAS); return atlas; }
int atlas_dirty(int *y0, int *y1) { *y0 = dirty0; *y1 = dirty1; return dirty1 >= dirty0; }
void atlas_clean(void) { dirty0 = ATLAS; dirty1 = -1; }
void text_reset(void) {
    atlas_pixels(); memset(atlas, 0, (size_t)ATLAS * ATLAS);
    shelfX = shelfY = shelfH = 0; dirty0 = 0; dirty1 = ATLAS - 1;
    if (gl) memset(gl, 0, sizeof(GEntry) * GCAP); ngl = 0;
    if (lays) layclear();
}
int text_glyph(void *fontp, uint16_t glyph, int phase, GlyphQuad *q) {
    if (!gl) { gl = calloc(GCAP, sizeof(GEntry)); atlas_pixels(); }
    uint32_t key = ((uint32_t)glyph << 2) | (uint32_t)(phase & 3);
    uint64_t h = ((uint64_t)(uintptr_t)fontp * 0x9E3779B97F4A7C15ULL) ^ key;
    int k = (int)((h ^ (h >> 29)) & (GCAP - 1));
    for (; gl[k].used; k = (k + 1) & (GCAP - 1))
        if (gl[k].font == fontp && gl[k].key == key) { *q = gl[k].q; return 0; }
    if (ngl > GCAP / 2) return -1;
    CTFontRef font = fontp;
    CGGlyph g = glyph; CGRect r;
    CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationHorizontal, &g, &r, 1);
    GlyphQuad out = {0};
    if (r.size.width > 0 && r.size.height > 0) {
        int pad = 2;
        int x0 = (int)floor(r.origin.x + phase / 4.0) - pad, y0 = (int)floor(r.origin.y) - pad;
        int w = (int)ceil(r.origin.x + phase / 4.0 + r.size.width) + pad - x0, h2 = (int)ceil(r.origin.y + r.size.height) + pad - y0;
        if (w > ATLAS || h2 > 512) return -1;
        if (shelfX + w > ATLAS) { shelfY += shelfH + 1; shelfX = 0; shelfH = 0; }
        if (shelfY + h2 > ATLAS) return -1;
        /* draw the glyph alone, white on transparent, the origin at (phase/4 - x0, -y0) */
        uint8_t *buf = calloc((size_t)w * h2, 1);
        CGContextRef cx = CGBitmapContextCreate(buf, w, h2, 8, w, NULL, kCGImageAlphaOnly);
        CGContextSetShouldAntialias(cx, true); CGContextSetShouldSmoothFonts(cx, false);
        CGContextSetAllowsFontSubpixelPositioning(cx, true); CGContextSetShouldSubpixelPositionFonts(cx, true);
        CGContextSetGrayFillColor(cx, 1, 1);
        CGPoint at = {phase / 4.0 - x0, -y0};
        CTFontDrawGlyphs(font, &g, &at, 1, cx);
        CGContextRelease(cx);
        for (int y = 0; y < h2; y++) memcpy(atlas + (size_t)(shelfY + y) * ATLAS + shelfX, buf + (size_t)y * w, w);
        free(buf);
        /* the bitmap's top row is its highest y: from the baseline, y down, it spans -(y0 + h2) .. -y0 */
        out = (GlyphQuad){(float)x0, (float)(-(y0 + h2)), (float)(x0 + w), (float)(-y0),
            (float)shelfX / ATLAS, (float)shelfY / ATLAS, (float)(shelfX + w) / ATLAS, (float)(shelfY + h2) / ATLAS};
        if (shelfY < dirty0) dirty0 = shelfY;
        if (shelfY + h2 - 1 > dirty1) dirty1 = shelfY + h2 - 1;
        shelfX += w + 1; if (h2 > shelfH) shelfH = h2;
    }
    gl[k] = (GEntry){fontp, key, out, 1}; ngl++;
    *q = out;
    return 0;
}
