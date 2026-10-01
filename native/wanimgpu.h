/* wanimgpu: Graphics drawn on the GPU (Metal), without the front end.
   wxf.c     the expression, from its WXF bytes (BinarySerialize)
   scene.c   the Graphics walked into triangles: fills, strokes, images, glyphs
   text.c    text shaped and its glyphs rasterized by CoreText into an atlas
   metal.m   the triangles drawn by Metal, multisampled, and read back
   link.c    the LibraryLink functions */
#ifndef WANIMGPU_H
#define WANIMGPU_H
#include <stdint.h>
#include <stddef.h>

/* ---- an arena: everything parsed or built for one frame, freed at once ---- */
void *arena_alloc(size_t n);
void arena_reset(void);

/* ---- expressions ---- */
enum { W_INT, W_REAL, W_STR, W_SYM, W_FUNC, W_ARR };
typedef struct WNode WNode;
struct WNode {
    uint8_t k;          /* W_* */
    uint8_t atype;      /* array element type (WXF code) */
    uint8_t rank;
    int32_t n;          /* arguments of a function, bytes of a string, elements of an array */
    WNode *head;        /* of a function */
    int64_t *dims;      /* of an array */
    union { int64_t i; double r; const char *s; WNode **args; const uint8_t *data; } u;
};
WNode *wxf_parse(const uint8_t *bytes, size_t len);
int wis(const WNode *e, const char *head);           /* a function with this head */
int wsym(const WNode *e, const char *name);          /* this symbol */
int wstr(const WNode *e, const char *s);             /* this string */
double wnum(const WNode *e);                         /* a number, NAN if not one */
int wlen(const WNode *e);                            /* elements of a list or array, -1 if neither */
WNode *wopt(const WNode *e, const char *name);       /* the value of an option name -> v among the arguments */
double warr(const WNode *a, int64_t k);              /* the k-th element of an array, flattened */
/* a list of points {{x, y}, ...} (packed or not) as 2n floats; n, or -1 if not points */
int wpoints(const WNode *e, float **xy);

/* ---- drawing ---- */
typedef struct { float x, y, u, v, r, g, b, a; } Vtx;
enum { P_COLOR, P_TEX, P_GLYPH };
enum { S_NONE, S_WRITE_NONZERO, S_WRITE_EVENODD, S_WRITE_ONE, S_COVER };
typedef struct { int pipe, stencil, tex, first, count; int clip[4]; } Cmd;   /* clip: x, y, w, h in pixels */
typedef struct {
    Vtx *v; int nv, cv;
    Cmd *c; int nc, cc;
    int width, height;
    float clear[4];
} Frame;
void frame_begin(Frame *f, int w, int h);
int scene_draw(Frame *f, WNode *graphics);           /* 0 on success; 4: something it cannot draw */
const char *scene_unsupported(void);                 /* what, after a 4 */

/* textures: an RGBA8 premultiplied image, by content; 1-based ids, 0 is none */
int tex_image(const uint8_t *rgba, int w, int h, uint64_t key);
int tex_find(int w, int h, uint64_t key);              /* an image already uploaded, or 0 */

/* ---- text ---- */
typedef struct { void *font; uint16_t glyph; float x, y; } Glyph;              /* pen position from the line's origin, y down */
typedef struct { Glyph *g; int n; float advance, ascent, descent, leading; } Layout;
/* the line laid out by CoreText (kerning, fallback fonts); cached, valid until text_reset */
const Layout *text_layout(const char *family, int weight, int italic, float size, const char *utf8);
/* a glyph's place in the atlas, drawn with its origin at a pen position with fraction phase/4 of a pixel:
   the quad relative to the pen's whole pixel, y down; 0, or -1 when the atlas is full */
typedef struct { float x0, y0, x1, y1, u0, v0, u1, v1; } GlyphQuad;
int text_glyph(void *font, uint16_t glyph, int phase, GlyphQuad *q);
void text_reset(void);                                                         /* empty the atlas and the caches */
/* the glyph atlas: A8, ATLAS x ATLAS; dirty rows since the last upload */
#define ATLAS 4096
uint8_t *atlas_pixels(void);
int atlas_dirty(int *y0, int *y1);
void atlas_clean(void);

/* ---- Metal ---- */
int gpu_init(char *err, int errlen);
int gpu_upload_texture(int id, const uint8_t *rgba, int w, int h);
int gpu_render(Frame *f, uint8_t *rgba_out);         /* rgba_out: height x width x 4, straight alpha */

#endif
