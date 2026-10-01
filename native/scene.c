/* A Graphics, walked into triangles.  Directives are scoped by lists, as in the language; coordinates go
   through an affine map from the plot range to pixels (y down), which Inset and Rotate compose onto.
   Fills: convex polygons as fans, others by stencil then cover (even-odd).  Strokes: a quad per segment,
   round joins and caps as fans; translucent ones through the stencil, so overlaps are not drawn twice.
   Text: CoreText glyphs from the atlas, placed by the text's box and offset as the front end places it. */
#include "wanimgpu.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

typedef struct { float a, b, c, d, e, f; } Aff;      /* (x, y) -> (a x + c y + e, b x + d y + f) */
static inline void ap(const Aff *t, float x, float y, float *X, float *Y) { *X = t->a * x + t->c * y + t->e; *Y = t->b * x + t->d * y + t->f; }
static Aff mul(Aff p, Aff q) {                         /* p after q */
    return (Aff){p.a * q.a + p.c * q.b, p.b * q.a + p.d * q.b, p.a * q.c + p.c * q.d, p.b * q.c + p.d * q.d,
        p.a * q.e + p.c * q.f + p.e, p.b * q.e + p.d * q.f + p.f};
}
static float scaleOf(const Aff *t) { return sqrtf(fabsf(t->a * t->d - t->b * t->c)); }

typedef struct {
    Aff T;
    float col[4];               /* the colour (straight), its alpha the colour's own */
    float op;                   /* Opacity */
    int faceSet, faceNone; float face[4]; float faceOp;
    int edgeOn; float edge[4]; float edgeW;
    float lw; int cap;          /* line width in pixels; 0 butt, 1 round, 2 square */
    float gw;                   /* the graphic's width in pixels: Thickness and Scaled sizes */
    const char *family; float fsize; int weight, italic; int tcolSet; float tcol[4];
    int clip[4];
} St;

static Frame *F;
static int pair(const WNode *p, const WNode **x, const WNode **y, float *fx, float *fy);
static int atlasFull;
static const char *unsupported;                    /* the first thing met that cannot be drawn as the front end would */
static void cannot(const char *what) { if (!unsupported) unsupported = what; }
static void reserveV(int n) {
    if (F->nv + n > F->cv) { F->cv = (F->nv + n) * 2; F->v = realloc(F->v, sizeof(Vtx) * F->cv); }
}
static void addCmd(int pipe, int stencil, int tex, int first, int count, const int *clip) {
    if (count <= 0) return;
    if (F->nc > 0) {
        Cmd *l = &F->c[F->nc - 1];
        if (stencil == S_NONE && l->stencil == S_NONE && l->pipe == pipe && l->tex == tex && l->first + l->count == first && !memcmp(l->clip, clip, sizeof l->clip)) {
            l->count += count; return;
        }
    }
    if (F->nc == F->cc) { F->cc = F->cc ? 2 * F->cc : 1024; F->c = realloc(F->c, sizeof(Cmd) * F->cc); }
    Cmd *c = &F->c[F->nc++];
    c->pipe = pipe; c->stencil = stencil; c->tex = tex; c->first = first; c->count = count; memcpy(c->clip, clip, sizeof c->clip);
}
static inline void vtx(float x, float y, float u, float v, const float *pm) {
    Vtx *p = &F->v[F->nv++]; p->x = x; p->y = y; p->u = u; p->v = v; p->r = pm[0]; p->g = pm[1]; p->b = pm[2]; p->a = pm[3];
}
static void premul(const float *c, float op, float *pm) { float a = c[3] * op; pm[0] = c[0] * a; pm[1] = c[1] * a; pm[2] = c[2] * a; pm[3] = a; }
static void quadCover(float x0, float y0, float x1, float y1, const float *pm, const int *clip) {
    reserveV(6); int first = F->nv;
    vtx(x0, y0, 0, 0, pm); vtx(x1, y0, 0, 0, pm); vtx(x1, y1, 0, 0, pm);
    vtx(x0, y0, 0, 0, pm); vtx(x1, y1, 0, 0, pm); vtx(x0, y1, 0, 0, pm);
    addCmd(P_COLOR, S_COVER, 0, first, 6, clip);
}

/* ---- colours and directives ---- */
static int hsb(double h, double s, double b, float *o) {
    h = fmod(h, 1); if (h < 0) h += 1;
    double i = floor(h * 6), f = h * 6 - i, p = b * (1 - s), q = b * (1 - f * s), t = b * (1 - (1 - f) * s);
    double r, g, bb;
    switch ((int)i % 6) { case 0: r = b; g = t; bb = p; break; case 1: r = q; g = b; bb = p; break; case 2: r = p; g = b; bb = t; break;
        case 3: r = p; g = q; bb = b; break; case 4: r = t; g = p; bb = b; break; default: r = b; g = p; bb = q; }
    o[0] = (float)r; o[1] = (float)g; o[2] = (float)bb; return 1;
}
/* a colour into o (rgba), or 0 if e is not one */
static int colour(const WNode *e, float *o) {
    if (!e || e->k != W_FUNC) return 0;
    const WNode *a = e; int n = e->n;
    WNode *const *args = e->u.args;
    if (n == 1 && (wis(args[0], "List") || args[0]->k == W_ARR) && (wis(e, "RGBColor") || wis(e, "GrayLevel") || wis(e, "Hue"))) {
        /* RGBColor[{r, g, b}] */
        const WNode *l = args[0]; int m = wlen(l);
        double v[4] = {0, 0, 0, 1};
        for (int k = 0; k < m && k < 4; k++) v[k] = l->k == W_ARR ? warr(l, k) : wnum(l->u.args[k]);
        if (wis(e, "RGBColor")) { o[0] = (float)v[0]; o[1] = (float)v[1]; o[2] = (float)v[2]; o[3] = m > 3 ? (float)v[3] : 1; return 1; }
        if (wis(e, "GrayLevel")) { o[0] = o[1] = o[2] = (float)v[0]; o[3] = m > 1 ? (float)v[1] : 1; return 1; }
        hsb(v[0], m > 1 ? v[1] : 1, m > 2 ? v[2] : 1, o); o[3] = m > 3 ? (float)v[3] : 1; return 1;
    }
    (void)a;
    if (wis(e, "RGBColor") && n >= 3) { for (int k = 0; k < 3; k++) o[k] = (float)wnum(args[k]); o[3] = n > 3 ? (float)wnum(args[3]) : 1; return 1; }
    if (wis(e, "GrayLevel") && n >= 1) { o[0] = o[1] = o[2] = (float)wnum(args[0]); o[3] = n > 1 ? (float)wnum(args[1]) : 1; return 1; }
    if (wis(e, "Hue") && n >= 1) { hsb(wnum(args[0]), n > 1 ? wnum(args[1]) : 1, n > 2 ? wnum(args[2]) : 1, o); o[3] = n > 3 ? (float)wnum(args[3]) : 1; return 1; }
    if (wis(e, "CMYKColor") && n >= 4) {
        double c = wnum(args[0]), m = wnum(args[1]), y = wnum(args[2]), k = wnum(args[3]);
        o[0] = (float)((1 - c) * (1 - k)); o[1] = (float)((1 - m) * (1 - k)); o[2] = (float)((1 - y) * (1 - k)); o[3] = n > 4 ? (float)wnum(args[4]) : 1; return 1;
    }
    return 0;
}
static int weightOf(const WNode *v) {
    if (!v) return 400;
    double n = wnum(v); if (!isnan(n)) return (int)n;
    const char *s = v->k == W_STR || v->k == W_SYM ? v->u.s : "";
    if (!strcmp(s, "Thin")) return 100; if (!strcmp(s, "ExtraLight") || !strcmp(s, "UltraLight")) return 200;
    if (!strcmp(s, "Light")) return 300; if (!strcmp(s, "Medium")) return 500;
    if (!strcmp(s, "SemiBold") || !strcmp(s, "DemiBold")) return 600; if (!strcmp(s, "Bold")) return 700;
    if (!strcmp(s, "ExtraBold") || !strcmp(s, "Heavy")) return 800; if (!strcmp(s, "Black")) return 900;
    return 400;
}
static float lengthPx(const WNode *v, const St *s) {     /* a size: points, or Scaled[f] of the graphic's width */
    if (wis(v, "Scaled") && v->n >= 1) return (float)wnum(v->u.args[0]) * s->gw;
    double n = wnum(v); return isnan(n) ? -1 : (float)n;
}
static int textOption(St *s, const WNode *e) {          /* a text style option or symbol; 1 if it was one */
    if (wis(e, "Rule") && e->n == 2 && e->u.args[0]->k == W_SYM) {
        const char *k = e->u.args[0]->u.s; const WNode *v = e->u.args[1];
        if (!strcmp(k, "FontFamily") && v->k == W_STR) { s->family = v->u.s; return 1; }
        if (!strcmp(k, "FontSize")) { float px = lengthPx(v, s); if (px > 0) s->fsize = px; return 1; }
        if (!strcmp(k, "FontWeight")) { s->weight = weightOf(v); return 1; }
        if (!strcmp(k, "FontSlant")) { s->italic = (v->k == W_STR || v->k == W_SYM) && (!strcmp(v->u.s, "Italic") || !strcmp(v->u.s, "Oblique")); return 1; }
        if (!strcmp(k, "FontColor")) { if (colour(v, s->tcol)) s->tcolSet = 1; return 1; }
        return 1;                                         /* other options: ignored */
    }
    if (wsym(e, "Bold")) { s->weight = 700; return 1; }
    if (wsym(e, "Italic")) { s->italic = 1; return 1; }
    if (wsym(e, "Plain")) { s->weight = 400; s->italic = 0; return 1; }
    double n = wnum(e); if (!isnan(n)) { s->fsize = (float)n; return 1; }
    return 0;
}
/* a graphics directive; 1 if e was one */
static int directive(St *s, const WNode *e) {
    float c[4];
    if (colour(e, c)) { memcpy(s->col, c, sizeof c); return 1; }
    if (wis(e, "Opacity") && e->n >= 1) {
        s->op = (float)wnum(e->u.args[0]);
        if (e->n > 1 && colour(e->u.args[1], c)) memcpy(s->col, c, sizeof c);
        return 1;
    }
    if (wis(e, "Thickness") && e->n >= 1) { double t = wnum(e->u.args[0]); if (!isnan(t)) s->lw = (float)t * s->gw; return 1; }
    if (wis(e, "AbsoluteThickness") && e->n >= 1) { double t = wnum(e->u.args[0]); if (!isnan(t)) s->lw = (float)t; return 1; }
    if (wis(e, "CapForm")) {
        const WNode *v = e->n ? e->u.args[0] : NULL;
        s->cap = wstr(v, "Round") ? 1 : wstr(v, "Square") ? 2 : 0; return 1;
    }
    if (wis(e, "FaceForm")) {
        if (e->n == 0) { s->faceSet = 1; s->faceNone = 1; return 1; }
        St t = *s; t.op = 1;
        for (int k = 0; k < e->n; k++) {
            const WNode *a = e->u.args[k];
            if (wis(a, "List")) for (int j = 0; j < a->n; j++) directive(&t, a->u.args[j]); else directive(&t, a);
        }
        s->faceSet = 1; s->faceNone = 0; memcpy(s->face, t.col, sizeof s->face); s->faceOp = t.op; return 1;
    }
    if (wis(e, "EdgeForm")) {
        if (e->n == 0) { s->edgeOn = 0; return 1; }
        St t = *s; t.op = 1; t.col[0] = t.col[1] = t.col[2] = 0; t.col[3] = 1; t.lw = 1;
        for (int k = 0; k < e->n; k++) {
            const WNode *a = e->u.args[k];
            if (wis(a, "List")) for (int j = 0; j < a->n; j++) directive(&t, a->u.args[j]); else directive(&t, a);
        }
        s->edgeOn = 1; memcpy(s->edge, t.col, sizeof s->edge); s->edge[3] *= t.op; s->edgeW = t.lw; return 1;
    }
    if (wis(e, "Directive")) { for (int k = 0; k < e->n; k++) directive(s, e->u.args[k]); return 1; }
    if (wis(e, "JoinForm") || wis(e, "PointSize") || wis(e, "AbsolutePointSize")) return 1;
    if (wis(e, "Dashing") || wis(e, "AbsoluteDashing")) {
        const WNode *d = e->n ? e->u.args[0] : NULL;
        if (!(e->n == 0 || wlen(d) == 0 || wsym(d, "None"))) cannot("Dashing");
        return 1;
    }
    return 0;
}

/* ---- geometry ---- */
static int convex(const float *p, int n) {
    if (n < 3) return 0;
    int sign = 0; double turn = 0;
    for (int k = 0; k < n; k++) {
        const float *a = p + 2 * k, *b = p + 2 * ((k + 1) % n), *c = p + 2 * ((k + 2) % n);
        double x1 = b[0] - a[0], y1 = b[1] - a[1], x2 = c[0] - b[0], y2 = c[1] - b[1];
        double cr = x1 * y2 - y1 * x2;
        if (fabs(cr) > 1e-9) { int sg = cr > 0 ? 1 : -1; if (sign && sg != sign) return 0; sign = sg; }
        turn += atan2(cr, x1 * x2 + y1 * y2);
    }
    return fabs(fabs(turn) - 2 * M_PI) < 0.1;
}
/* a filled polygon, pixel coordinates; vc: per-vertex colours (premultiplied) or NULL */
static void fill(const float *p, int n, const float *pm, const float *vc, const int *clip) {
    if (n < 3 || (pm[3] <= 0 && !vc)) return;
    int cvx = vc || convex(p, n);
    reserveV(3 * (n - 2)); int first = F->nv;
    for (int k = 1; k < n - 1; k++) {
        vtx(p[0], p[1], 0, 0, vc ? vc : pm);
        vtx(p[2 * k], p[2 * k + 1], 0, 0, vc ? vc + 4 * k : pm);
        vtx(p[2 * k + 2], p[2 * k + 3], 0, 0, vc ? vc + 4 * (k + 1) : pm);
    }
    if (cvx) { addCmd(P_COLOR, S_NONE, 0, first, 3 * (n - 2), clip); return; }
    addCmd(P_COLOR, S_WRITE_EVENODD, 0, first, 3 * (n - 2), clip);
    float x0 = p[0], x1 = p[0], y0 = p[1], y1 = p[1];
    for (int k = 1; k < n; k++) { x0 = fminf(x0, p[2 * k]); x1 = fmaxf(x1, p[2 * k]); y0 = fminf(y0, p[2 * k + 1]); y1 = fmaxf(y1, p[2 * k + 1]); }
    quadCover(x0, y0, x1, y1, pm, clip);
}
static int arcSegments(float r) { int n = (int)ceilf(6 * sqrtf(fmaxf(r, 0.5f))); return n < 8 ? 8 : n > 256 ? 256 : n; }
static void fan(float cx, float cy, float r, float a0, float a1, const float *pm) {     /* a disk or its sector, vertices only */
    int n = (int)ceilf(arcSegments(r) * fabsf(a1 - a0) / (2 * (float)M_PI)); if (n < 2) n = 2;
    reserveV(3 * n);
    for (int k = 0; k < n; k++) {
        float t0 = a0 + (a1 - a0) * k / n, t1 = a0 + (a1 - a0) * (k + 1) / n;
        vtx(cx, cy, 0, 0, pm); vtx(cx + r * cosf(t0), cy + r * sinf(t0), 0, 0, pm); vtx(cx + r * cosf(t1), cy + r * sinf(t1), 0, 0, pm);
    }
}
/* a polyline of width w (pixels) */
static void stroke(const float *p, int n, int closed, float w, int cap, const float *pm, const int *clip) {
    if (n < 2 || w <= 0 || pm[3] <= 0) return;
    int segs = closed ? n : n - 1;
    float h = w / 2;
    int first = F->nv;
    for (int k = 0; k < segs; k++) {
        const float *a = p + 2 * k, *b = p + 2 * ((k + 1) % n);
        float dx = b[0] - a[0], dy = b[1] - a[1], L = sqrtf(dx * dx + dy * dy);
        if (L < 1e-6f) continue;
        float nx = -dy / L * h, ny = dx / L * h, ex = 0, ey = 0, sx = 0, sy = 0;
        if (cap == 2 && !closed) { if (k == 0) { sx = -dx / L * h; sy = -dy / L * h; } if (k == segs - 1) { ex = dx / L * h; ey = dy / L * h; } }
        reserveV(6);
        vtx(a[0] + nx + sx, a[1] + ny + sy, 0, 0, pm); vtx(b[0] + nx + ex, b[1] + ny + ey, 0, 0, pm); vtx(b[0] - nx + ex, b[1] - ny + ey, 0, 0, pm);
        vtx(a[0] + nx + sx, a[1] + ny + sy, 0, 0, pm); vtx(b[0] - nx + ex, b[1] - ny + ey, 0, 0, pm); vtx(a[0] - nx + sx, a[1] - ny + sy, 0, 0, pm);
    }
    /* joins, and round caps: disks at the points */
    if (w > 1.5f) for (int k = 0; k < n; k++) {
        int end = !closed && (k == 0 || k == n - 1);
        if (end && cap != 1) continue;
        fan(p[2 * k], p[2 * k + 1], h, 0, 2 * (float)M_PI, pm);
    }
    int count = F->nv - first;
    if (pm[3] > 0.999f) { addCmd(P_COLOR, S_NONE, 0, first, count, clip); return; }
    addCmd(P_COLOR, S_WRITE_ONE, 0, first, count, clip);
    float x0 = 1e30f, x1 = -1e30f, y0 = 1e30f, y1 = -1e30f;
    for (int k = first; k < first + count; k++) { x0 = fminf(x0, F->v[k].x); x1 = fmaxf(x1, F->v[k].x); y0 = fminf(y0, F->v[k].y); y1 = fmaxf(y1, F->v[k].y); }
    quadCover(x0, y0, x1, y1, pm, clip);
}
static float *mapPts(const St *s, const float *p, int n) {
    float *o = arena_alloc(sizeof(float) * 2 * (n ? n : 1));
    for (int k = 0; k < n; k++) ap(&s->T, p[2 * k], p[2 * k + 1], &o[2 * k], &o[2 * k + 1]);
    return o;
}
static void fillColour(const St *s, float *pm) {
    if (s->faceSet) premul(s->face, s->faceOp, pm); else premul(s->col, s->op, pm);
}
static void edgeOf(const St *s, const float *px, int n, int closed) {
    if (!s->edgeOn) return;
    float pm[4]; premul(s->edge, 1, pm);
    stroke(px, n, closed, s->edgeW, 0, pm, s->clip);
}
/* an ellipse (or its arc) through T, as pixel points */
static float *ellipse(const St *s, float cx, float cy, float rx, float ry, float a0, float a1, int sector, int *np) {
    float r = fmaxf(rx, ry) * scaleOf(&s->T);
    int n = (int)ceilf(arcSegments(r) * fabsf(a1 - a0) / (2 * (float)M_PI)); if (n < 3) n = 3;
    float *p = arena_alloc(sizeof(float) * 2 * (n + 2)); int m = 0;
    if (sector) { ap(&s->T, cx, cy, &p[0], &p[1]); m = 1; }
    for (int k = 0; k <= n; k++) {
        if (!sector && k == n && fabsf(a1 - a0) >= 2 * (float)M_PI - 1e-4f) break;
        float t = a0 + (a1 - a0) * k / n;
        ap(&s->T, cx + rx * cosf(t), cy + ry * sinf(t), &p[2 * m], &p[2 * m + 1]); m++;
    }
    *np = m; return p;
}

/* ---- text ---- */
static void textBox(const St *s, const Layout *L, float *w, float *h) { *w = L->advance; *h = L->ascent + L->descent; (void)s; }
static const char *textOf(const WNode *e, St *s) {      /* the string of Text's first argument, its style applied to s */
    if (e->k == W_STR) return e->u.s;
    if (wis(e, "Style") && e->n >= 1) {
        for (int k = 1; k < e->n; k++) { float c[4]; if (colour(e->u.args[k], c)) { memcpy(s->tcol, c, sizeof c); s->tcolSet = 1; } else textOption(s, e->u.args[k]); }
        return textOf(e->u.args[0], s);
    }
    if (e->k == W_INT) { char *b = arena_alloc(32); snprintf(b, 32, "%lld", (long long)e->u.i); return b; }
    if (e->k == W_REAL) { char *b = arena_alloc(32); snprintf(b, 32, "%g", e->u.r); return b; }
    if (e->k == W_SYM) return e->u.s;
    return NULL;
}
/* the anchor, box size and layout of a Text; 0 if it cannot be drawn */
static int textPlace(St *s, const WNode *e, const Layout **L, float *ax, float *ay, float *ox, float *oy) {
    if (e->n < 1) return 0;
    const char *str = textOf(e->u.args[0], s);
    if (!str) { cannot("Text of a typeset expression"); return 0; }
    if (!*str) return 0;
    *L = text_layout(s->family, s->weight, s->italic, s->fsize, str);
    float x = 0, y = 0;
    if (e->n > 1) {
        const WNode *xn, *yn; float a, b;
        int k = pair(e->u.args[1], &xn, &yn, &a, &b);
        if (k == 2) { x = a; y = b; } else if (k == 1) { x = (float)wnum(xn); y = (float)wnum(yn); }
    }
    ap(&s->T, x, y, ax, ay);
    *ox = 0; *oy = 0;
    if (e->n > 2) {
        const WNode *o = e->u.args[2];
        if (o->k == W_ARR && o->dims[0] == 2) { *ox = (float)warr(o, 0); *oy = (float)warr(o, 1); }
        else if (wis(o, "List") && o->n == 2) { *ox = (float)wnum(o->u.args[0]); *oy = (float)wnum(o->u.args[1]); }
    }
    return 1;
}
static void drawText(St *s0, const WNode *e) {
    St s = *s0; const Layout *L; float ax, ay, ox, oy;
    if (!textPlace(&s, e, &L, &ax, &ay, &ox, &oy)) return;
    float w, h; textBox(&s, L, &w, &h);
    float left = -w * (ox + 1) / 2, top = -h * (1 - oy) / 2, base = top + L->ascent;
    float pm[4];
    if (s.tcolSet) premul(s.tcol, s.op, pm); else premul(s.col, s.op, pm);
    if (pm[3] <= 0) return;
    /* the text turns with the map (Rotate), but keeps its size */
    float ang = atan2f(s.T.b, s.T.a), sc = scaleOf(&s.T);
    int turned = fabsf(ang) > 1e-4f;
    float cs = cosf(ang), sn = sinf(ang);
    (void)sc;
    reserveV(6 * L->n); int first = F->nv;
    for (int k = 0; k < L->n; k++) {
        const Glyph *g = &L->g[k];
        float px = left + g->x, py = base + g->y;
        GlyphQuad q;
        if (!turned) {
            float X = ax + px, Y = roundf(ay + py);
            float fx = floorf(X); int phase = (int)floorf((X - fx) * 4);
            if (text_glyph(g->font, g->glyph, phase, &q)) { atlasFull = 1; return; }
            if (q.x1 <= q.x0) continue;
            float x0 = fx + q.x0, x1 = fx + q.x1, y0 = Y + q.y0, y1 = Y + q.y1;
            vtx(x0, y0, q.u0, q.v0, pm); vtx(x1, y0, q.u1, q.v0, pm); vtx(x1, y1, q.u1, q.v1, pm);
            vtx(x0, y0, q.u0, q.v0, pm); vtx(x1, y1, q.u1, q.v1, pm); vtx(x0, y1, q.u0, q.v1, pm);
        } else {
            if (text_glyph(g->font, g->glyph, 0, &q)) { atlasFull = 1; return; }
            if (q.x1 <= q.x0) continue;
            float cx[4] = {px + q.x0, px + q.x1, px + q.x1, px + q.x0}, cy[4] = {py + q.y0, py + q.y0, py + q.y1, py + q.y1};
            float X[4], Y[4];
            for (int j = 0; j < 4; j++) { X[j] = ax + cs * cx[j] - sn * cy[j]; Y[j] = ay + sn * cx[j] + cs * cy[j]; }
            vtx(X[0], Y[0], q.u0, q.v0, pm); vtx(X[1], Y[1], q.u1, q.v0, pm); vtx(X[2], Y[2], q.u1, q.v1, pm);
            vtx(X[0], Y[0], q.u0, q.v0, pm); vtx(X[2], Y[2], q.u1, q.v1, pm); vtx(X[3], Y[3], q.u0, q.v1, pm);
        }
    }
    addCmd(P_GLYPH, S_NONE, -1, first, F->nv - first, s.clip);
}

/* ---- images ---- */
static uint64_t sampleHash(const uint8_t *d, size_t n, uint64_t h) {
    size_t step = n > (1 << 18) ? n / (1 << 18) : 1;
    for (size_t k = 0; k < n; k += step) { h ^= d[k]; h *= 1099511628211ULL; }
    return h;
}
/* an Image as a texture: its id, width and height; 0 if it cannot be read */
static int imageTex(const WNode *im, int *w, int *h) {
    if (!wis(im, "Image") || im->n < 1 || im->u.args[0]->k != W_ARR) return 0;
    const WNode *a = im->u.args[0];
    if (a->rank != 2 && a->rank != 3) return 0;
    int H = (int)a->dims[0], W = (int)a->dims[1], C = a->rank == 3 ? (int)a->dims[2] : 1;
    if (C < 1 || C > 4) return 0;
    WNode *il = wopt(im, "Interleaving");
    if (il && wsym(il, "False")) return 0;
    int isByte = a->atype == 0x10;
    size_t es = isByte ? 1 : a->atype == 0x22 ? 4 : 8;
    uint64_t key = sampleHash(a->u.data, (size_t)a->n * es, 1469598103934665603ULL ^ ((uint64_t)W << 32 | (uint64_t)H << 8 | (uint64_t)C));
    *w = W; *h = H;
    int id = tex_find(W, H, key);
    if (id) return id;
    uint8_t *rgba = malloc((size_t)W * H * 4);
    if (isByte && (C == 3 || C == 4)) {                   /* the usual case, directly */
        const uint8_t *d = a->u.data;
        for (int64_t k = 0; k < (int64_t)W * H; k++) {
            unsigned al = C == 4 ? d[4 * k + 3] : 255;
            for (int j = 0; j < 3; j++) rgba[4 * k + j] = (uint8_t)((d[C * k + j] * al + 127) / 255);
            rgba[4 * k + 3] = (uint8_t)al;
        }
        id = tex_image(rgba, W, H, key); free(rgba);
        return id;
    }
    for (int64_t k = 0; k < (int64_t)W * H; k++) {
        float c[4] = {0, 0, 0, 1};
        for (int j = 0; j < C; j++) { double v = warr(a, k * C + j); c[j] = (float)(isByte ? v / 255.0 : v); }
        float r, g, b, al;
        if (C == 1) { r = g = b = c[0]; al = 1; } else if (C == 2) { r = g = b = c[0]; al = c[1]; } else { r = c[0]; g = c[1]; b = c[2]; al = C == 4 ? c[3] : 1; }
        al = fminf(fmaxf(al, 0), 1);
        rgba[4 * k] = (uint8_t)lroundf(fminf(fmaxf(r, 0), 1) * al * 255); rgba[4 * k + 1] = (uint8_t)lroundf(fminf(fmaxf(g, 0), 1) * al * 255);
        rgba[4 * k + 2] = (uint8_t)lroundf(fminf(fmaxf(b, 0), 1) * al * 255); rgba[4 * k + 3] = (uint8_t)lroundf(al * 255);
    }
    id = tex_image(rgba, W, H, key);
    free(rgba);
    return id;
}

/* ---- insets and rotation ---- */
static void walk(St *s, const WNode *e);
static void graphicsInto(St *s, const WNode *g, float rx, float ry, float rw, float rh);
static float frac(const WNode *v, float lo, float hi, float fallback) {   /* Left, Center, Right, or a coordinate */
    if (!v) return fallback;
    if (wsym(v, "Left") || wsym(v, "Bottom")) return 0;
    if (wsym(v, "Right") || wsym(v, "Top")) return 1;
    if (wsym(v, "Center")) return 0.5f;
    if (wis(v, "Scaled") && v->n) return (float)wnum(v->u.args[0]);
    double n = wnum(v); if (isnan(n) || hi == lo) return fallback;
    return ((float)n - lo) / (hi - lo);
}
static int pair(const WNode *p, const WNode **x, const WNode **y, float *fx, float *fy) {
    if (!p) return 0;
    if (p->k == W_ARR && p->rank == 1 && p->dims[0] == 2) { *x = *y = NULL; *fx = (float)warr(p, 0); *fy = (float)warr(p, 1); return 2; }
    if (wis(p, "List") && p->n == 2) { *x = p->u.args[0]; *y = p->u.args[1]; return 1; }
    return 0;
}
static int plotRange(const WNode *g, float *pr) {       /* {{x0, x1}, {y0, y1}} */
    WNode *r = wopt(g, "PlotRange");
    if (!r) return 0;
    if (r->k == W_ARR && r->rank == 2 && r->dims[0] == 2 && r->dims[1] == 2) { for (int k = 0; k < 4; k++) pr[k] = (float)warr(r, k); return 1; }
    if (wis(r, "List") && r->n == 2) {
        for (int k = 0; k < 2; k++) {
            const WNode *a = r->u.args[k];
            if (a->k == W_ARR && a->dims[0] == 2) { pr[2 * k] = (float)warr(a, 0); pr[2 * k + 1] = (float)warr(a, 1); }
            else if (wis(a, "List") && a->n == 2) { pr[2 * k] = (float)wnum(a->u.args[0]); pr[2 * k + 1] = (float)wnum(a->u.args[1]); }
            else return 0;
        }
        return !isnan(pr[0] + pr[1] + pr[2] + pr[3]);
    }
    return 0;
}
/* the rectangle an Inset covers, in the parent's coordinates */
static int insetRect(const St *s, const WNode *e, float *rx, float *ry, float *rw, float *rh, int *texid, float *ipr) {
    const WNode *obj = e->u.args[0];
    float natW, natH; float pr[4] = {0, 1, 0, 1};
    *texid = 0;
    if (wis(obj, "Image")) {
        int w, h; *texid = imageTex(obj, &w, &h);
        if (!*texid) return 0;
        natW = (float)w; natH = (float)h; pr[1] = natW; pr[3] = natH;
        WNode *is = wopt(obj, "ImageSize");
        double isz = is ? wnum(is) : NAN; if (!isnan(isz)) { natH *= (float)isz / natW; natW = (float)isz; }
    } else if (wis(obj, "Graphics")) {
        if (!plotRange(obj, pr)) return 0;
        WNode *is = wopt(obj, "ImageSize"); double isz = is ? wnum(is) : NAN;
        WNode *ar = wopt(obj, "AspectRatio"); double asp = ar ? wnum(ar) : NAN;
        if (isnan(asp)) asp = (pr[3] - pr[2]) / (pr[1] - pr[0]);
        natW = isnan(isz) ? 360 : (float)isz; natH = natW * (float)asp;
    } else { cannot("Inset of something other than an Image or a Graphics"); return 0; }
    memcpy(ipr, pr, sizeof pr);
    float px = 0, py = 0;
    const WNode *xn, *yn; float a, b;
    if (e->n > 1) {
        int k = pair(e->u.args[1], &xn, &yn, &a, &b);
        if (k == 2) { px = a; py = b; } else if (k == 1) { px = (float)wnum(xn); py = (float)wnum(yn); }
    }
    float sc = scaleOf(&s->T); if (sc <= 0) sc = 1;
    float sw = natW / sc, sh = natH / sc;                 /* its natural size, in the parent's units */
    if (e->n > 3) {
        const WNode *z = e->u.args[3];
        double n = wnum(z);
        if (!isnan(n)) { sw = (float)n; sh = (float)n * natH / natW; }
        else { int k = pair(z, &xn, &yn, &a, &b); if (k == 2) { sw = a; sh = b; } else if (k == 1) { sw = (float)wnum(xn); sh = (float)wnum(yn); } }
    }
    float fx = 0.5f, fy = 0.5f;
    if (e->n > 2) {
        int k = pair(e->u.args[2], &xn, &yn, &a, &b);
        if (k == 2) { fx = (a - pr[0]) / (pr[1] - pr[0]); fy = (b - pr[2]) / (pr[3] - pr[2]); }
        else if (k == 1) { fx = frac(xn, pr[0], pr[1], 0.5f); fy = frac(yn, pr[2], pr[3], 0.5f); }
    }
    *rx = px - fx * sw; *ry = py - fy * sh; *rw = sw; *rh = sh;
    return 1;
}
static void drawInset(St *s, const WNode *e) {
    if (e->n < 1) return;
    float rx, ry, rw, rh, pr[4]; int tex;
    if (!insetRect(s, e, &rx, &ry, &rw, &rh, &tex, pr)) return;
    if (tex) {
        float X[4], Y[4];
        ap(&s->T, rx, ry + rh, &X[0], &Y[0]); ap(&s->T, rx + rw, ry + rh, &X[1], &Y[1]);
        ap(&s->T, rx + rw, ry, &X[2], &Y[2]); ap(&s->T, rx, ry, &X[3], &Y[3]);
        float pm[4] = {1, 1, 1, 1};                       /* an inset is drawn whole: Opacity does not reach it */
        reserveV(6); int first = F->nv;
        vtx(X[0], Y[0], 0, 0, pm); vtx(X[1], Y[1], 1, 0, pm); vtx(X[2], Y[2], 1, 1, pm);
        vtx(X[0], Y[0], 0, 0, pm); vtx(X[2], Y[2], 1, 1, pm); vtx(X[3], Y[3], 0, 1, pm);
        addCmd(P_TEX, S_NONE, tex, first, 6, s->clip);
        return;
    }
    /* a graphic keeps its aspect ratio, centred in the rectangle, unless it is AspectRatio -> Full */
    const WNode *g = e->u.args[0];
    WNode *ar = wopt(g, "AspectRatio");
    if (!(ar && wsym(ar, "Full"))) {
        double asp = ar ? wnum(ar) : NAN;
        if (isnan(asp)) asp = (pr[3] - pr[2]) / (pr[1] - pr[0]);
        float sc = scaleOf(&s->T);
        float pw = rw * sc, ph = rh * sc;                 /* in pixels, where the ratio is meant */
        if (ph / pw > asp) { float nh = pw * (float)asp / sc; ry += (rh - nh) / 2; rh = nh; }
        else { float nw = ph / (float)asp / sc; rx += (rw - nw) / 2; rw = nw; }
    }
    graphicsInto(s, g, rx, ry, rw, rh);
}
static int centre(St *s, const WNode *e, float *cx, float *cy) {        /* in pixels */
    if (wis(e, "Text")) {
        St t = *s; const Layout *L; float ax, ay, ox, oy, w, h;
        if (!textPlace(&t, e, &L, &ax, &ay, &ox, &oy)) return 0;
        textBox(&t, L, &w, &h);
        *cx = ax - ox * w / 2; *cy = ay + oy * h / 2; return 1;
    }
    if (wis(e, "Inset")) {
        float rx, ry, rw, rh, pr[4]; int tex;
        if (!insetRect(s, e, &rx, &ry, &rw, &rh, &tex, pr)) return 0;
        ap(&s->T, rx + rw / 2, ry + rh / 2, cx, cy); return 1;
    }
    return 0;
}
static void drawRotate(St *s, const WNode *e) {
    if (e->n < 2) return;
    double th = wnum(e->u.args[1]);
    if (isnan(th)) return;
    float cx, cy;
    const WNode *xn, *yn; float a, b;
    if (e->n > 2 && pair(e->u.args[2], &xn, &yn, &a, &b)) {
        if (xn) { a = (float)wnum(xn); b = (float)wnum(yn); }
        ap(&s->T, a, b, &cx, &cy);
    } else if (!centre(s, e->u.args[0], &cx, &cy)) { walk(s, e->u.args[0]); return; }
    /* counterclockwise on the page, which in pixels (y down) is the other way */
    float c = cosf((float)-th), sn = sinf((float)-th);
    Aff R = {c, sn, -sn, c, cx - c * cx + sn * cy, cy - sn * cx - c * cy};
    St t = *s; t.T = mul(R, s->T);
    walk(&t, e->u.args[0]);
}

/* ---- primitives ---- */
static void eachPolygon(St *s, const WNode *pts, const WNode *vcols) {
    float *p; int n = wpoints(pts, &p);
    if (n < 0) {                                  /* a list of polygons */
        if (wis(pts, "List")) for (int k = 0; k < pts->n; k++) eachPolygon(s, pts->u.args[k], NULL);
        else if (pts && pts->k == W_ARR && pts->rank == 3) {
            /* packed {{{x, y}, ...}, ...} */
            int m = (int)pts->dims[0], q = (int)pts->dims[1];
            for (int k = 0; k < m; k++) {
                float *pp = arena_alloc(sizeof(float) * 2 * q);
                for (int j = 0; j < 2 * q; j++) pp[j] = (float)warr(pts, (int64_t)k * q * 2 + j);
                float *px = mapPts(s, pp, q), pm[4];
                if (!s->faceNone) { fillColour(s, pm); fill(px, q, pm, NULL, s->clip); }
                edgeOf(s, px, q, 1);
            }
        }
        return;
    }
    float *px = mapPts(s, p, n);
    if (!s->faceNone) {
        float pm[4]; fillColour(s, pm);
        float *vc = NULL;
        if (vcols && wlen(vcols) == n && wis(vcols, "List")) {
            vc = arena_alloc(sizeof(float) * 4 * n);
            for (int k = 0; k < n; k++) { float c[4] = {0, 0, 0, 1}; colour(vcols->u.args[k], c); premul(c, s->faceSet ? s->faceOp : s->op, vc + 4 * k); }
        }
        fill(px, n, pm, vc, s->clip);
    }
    edgeOf(s, px, n, 1);
}
static void eachLine(St *s, const WNode *pts) {
    float *p; int n = wpoints(pts, &p);
    if (n < 0) {
        if (wis(pts, "List")) for (int k = 0; k < pts->n; k++) eachLine(s, pts->u.args[k]);
        return;
    }
    float pm[4]; premul(s->col, s->op, pm);
    stroke(mapPts(s, p, n), n, 0, s->lw, s->cap, pm, s->clip);
}
static int centreRadii(const WNode *e, float *cx, float *cy, float *rx, float *ry) {
    const WNode *xn, *yn; float a, b;
    *cx = *cy = 0; *rx = *ry = 1;
    if (e->n > 0) { int k = pair(e->u.args[0], &xn, &yn, &a, &b); if (k == 2) { *cx = a; *cy = b; } else if (k == 1) { *cx = (float)wnum(xn); *cy = (float)wnum(yn); } else return 0; }
    if (e->n > 1) {
        double r = wnum(e->u.args[1]);
        if (!isnan(r)) *rx = *ry = (float)r;
        else { int k = pair(e->u.args[1], &xn, &yn, &a, &b); if (k == 2) { *rx = a; *ry = b; } else if (k == 1) { *rx = (float)wnum(xn); *ry = (float)wnum(yn); } else return 0; }
    }
    return 1;
}
static void arcAngles(const WNode *e, float *a0, float *a1, int *sector) {
    *a0 = 0; *a1 = 2 * (float)M_PI; *sector = 0;
    if (e->n > 2) {
        const WNode *xn, *yn; float a, b;
        int k = pair(e->u.args[2], &xn, &yn, &a, &b);
        if (k == 1) { a = (float)wnum(xn); b = (float)wnum(yn); }
        if (k) { *a0 = a; *a1 = b; *sector = 1; }
    }
}
static void walk(St *s, const WNode *e) {
    if (!e) return;
    if (wis(e, "List")) {
        St t = *s;
        for (int k = 0; k < e->n; k++) walk(&t, e->u.args[k]);
        return;
    }
    if (e->k != W_FUNC) return;
    if (directive(s, e)) return;
    const char *h = e->head && e->head->k == W_SYM ? e->head->u.s : "";
    if (!strcmp(h, "Polygon")) { if (e->n) eachPolygon(s, e->u.args[0], wopt(e, "VertexColors")); return; }
    if (!strcmp(h, "Line")) { if (e->n) eachLine(s, e->u.args[0]); return; }
    if (!strcmp(h, "Text")) { drawText(s, e); return; }
    if (!strcmp(h, "Inset")) { drawInset(s, e); return; }
    if (!strcmp(h, "Rotate")) { drawRotate(s, e); return; }
    if (!strcmp(h, "Disk") || !strcmp(h, "Circle")) {
        float cx, cy, rx, ry, a0, a1; int sector, n;
        if (!centreRadii(e, &cx, &cy, &rx, &ry)) return;
        arcAngles(e, &a0, &a1, &sector);
        int disk = h[0] == 'D';
        float *p = ellipse(s, cx, cy, rx, ry, a0, a1, disk && sector, &n);
        if (disk) {
            if (!s->faceNone) { float pm[4]; fillColour(s, pm); fill(p, n, pm, NULL, s->clip); }
            edgeOf(s, p, n, 1);
        } else { float pm[4]; premul(s->col, s->op, pm); stroke(p, n, !sector, s->lw, s->cap, pm, s->clip); }
        return;
    }
    if (!strcmp(h, "Rectangle")) {
        const WNode *xn, *yn; float a, b, x0 = 0, y0 = 0, x1, y1;
        if (e->n > 0) { int k = pair(e->u.args[0], &xn, &yn, &a, &b); if (k == 1) { a = (float)wnum(xn); b = (float)wnum(yn); } if (k) { x0 = a; y0 = b; } }
        x1 = x0 + 1; y1 = y0 + 1;
        if (e->n > 1 && !wis(e->u.args[1], "Rule")) { int k = pair(e->u.args[1], &xn, &yn, &a, &b); if (k == 1) { a = (float)wnum(xn); b = (float)wnum(yn); } if (k) { x1 = a; y1 = b; } }
        if (x1 < x0) { float t = x0; x0 = x1; x1 = t; }
        if (y1 < y0) { float t = y0; y0 = y1; y1 = t; }
        float rr = 0; WNode *rn = wopt(e, "RoundingRadius"); if (rn) { double v = wnum(rn); if (!isnan(v)) rr = (float)v; }
        rr = fminf(rr, fminf(x1 - x0, y1 - y0) / 2);
        float *p; int n;
        if (rr <= 0) { float q[8] = {x0, y0, x1, y0, x1, y1, x0, y1}; p = mapPts(s, q, 4); n = 4; }
        else {
            int seg = arcSegments(rr * scaleOf(&s->T)) / 4 + 2;
            float *q = arena_alloc(sizeof(float) * 2 * 4 * (seg + 1)); n = 0;
            float cxs[4] = {x1 - rr, x0 + rr, x0 + rr, x1 - rr}, cys[4] = {y1 - rr, y1 - rr, y0 + rr, y0 + rr};
            for (int c = 0; c < 4; c++) for (int k = 0; k <= seg; k++) {
                float t = (float)M_PI / 2 * (c + (float)k / seg);
                q[2 * n] = cxs[c] + rr * cosf(t); q[2 * n + 1] = cys[c] + rr * sinf(t); n++;
            }
            p = mapPts(s, q, n);
        }
        if (!s->faceNone) { float pm[4]; fillColour(s, pm); fill(p, n, pm, NULL, s->clip); }
        edgeOf(s, p, n, 1);
        return;
    }
    if (!strcmp(h, "Point")) {
        float *p; int n = e->n ? wpoints(e->u.args[0], &p) : -1;
        if (n < 0 && e->n) { const WNode *xn, *yn; float a, b; int k = pair(e->u.args[0], &xn, &yn, &a, &b);
            if (!k) return; if (k == 1) { a = (float)wnum(xn); b = (float)wnum(yn); } p = arena_alloc(8); p[0] = a; p[1] = b; n = 1; }
        float pm[4]; premul(s->col, s->op, pm);
        for (int k = 0; k < n; k++) { float X, Y; ap(&s->T, p[2 * k], p[2 * k + 1], &X, &Y); int first = F->nv; fan(X, Y, 2, 0, 2 * (float)M_PI, pm); addCmd(P_COLOR, S_NONE, 0, first, F->nv - first, s->clip); }
        return;
    }
    if (!strcmp(h, "Style")) {
        St t = *s;
        for (int k = 1; k < e->n; k++) if (!directive(&t, e->u.args[k])) textOption(&t, e->u.args[k]);
        if (e->n) walk(&t, e->u.args[0]);
        return;
    }
    if (!strcmp(h, "GraphicsGroup") || !strcmp(h, "Annotation") || !strcmp(h, "Tooltip") || !strcmp(h, "Mouseover") || !strcmp(h, "EventHandler")) {
        if (e->n) { St t = *s; walk(&t, e->u.args[0]); }
        return;
    }
    if (!strcmp(h, "Graphics")) { float pr[4]; if (plotRange(e, pr)) graphicsInto(s, e, pr[0], pr[2], pr[1] - pr[0], pr[3] - pr[2]); else cannot("Graphics without an explicit PlotRange"); return; }
    cannot(h);
}

/* a Graphics drawn into a rectangle of the parent's coordinates (the whole frame, at the top) */
static void baseStyle(St *s, const WNode *g) {
    WNode *bs = wopt(g, "BaseStyle");
    if (!bs) return;
    if (wis(bs, "List")) { for (int k = 0; k < bs->n; k++) if (!directive(s, bs->u.args[k])) textOption(s, bs->u.args[k]); }
    else if (!directive(s, bs)) textOption(s, bs);
}
static void graphicsInto(St *s, const WNode *g, float rx, float ry, float rw, float rh) {
    float pr[4];
    if (!plotRange(g, pr) || pr[1] == pr[0] || pr[3] == pr[2]) return;
    St t = *s;
    Aff M = {rw / (pr[1] - pr[0]), 0, 0, rh / (pr[3] - pr[2]), rx - pr[0] * rw / (pr[1] - pr[0]), ry - pr[2] * rh / (pr[3] - pr[2])};
    t.T = mul(s->T, M);
    float X0, Y0, X1, Y1; ap(&s->T, rx, ry, &X0, &Y0); ap(&s->T, rx + rw, ry + rh, &X1, &Y1);
    t.gw = fabsf(X1 - X0);
    t.col[0] = t.col[1] = t.col[2] = 0; t.col[3] = 1; t.op = 1; t.faceSet = 0; t.faceNone = 0; t.edgeOn = 0; t.lw = 1; t.cap = 0; t.tcolSet = 0;
    baseStyle(&t, g);
    float bx0 = fminf(X0, X1), bx1 = fmaxf(X0, X1), by0 = fminf(Y0, Y1), by1 = fmaxf(Y0, Y1);
    WNode *bg = wopt(g, "Background"); float c[4];
    if (bg && colour(bg, c)) {
        float pm[4]; premul(c, 1, pm);
        float q[8] = {pr[0], pr[2], pr[1], pr[2], pr[1], pr[3], pr[0], pr[3]};
        fill(mapPts(&t, q, 4), 4, pm, NULL, s->clip);
    }
    WNode *clip = wopt(g, "PlotRangeClipping");
    if (clip && wsym(clip, "True")) {
        int x0 = (int)floorf(bx0), y0 = (int)floorf(by0), x1 = (int)ceilf(bx1), y1 = (int)ceilf(by1);
        int cx0 = s->clip[0], cy0 = s->clip[1], cx1 = s->clip[0] + s->clip[2], cy1 = s->clip[1] + s->clip[3];
        if (x0 < cx0) x0 = cx0; if (y0 < cy0) y0 = cy0; if (x1 > cx1) x1 = cx1; if (y1 > cy1) y1 = cy1;
        t.clip[0] = x0; t.clip[1] = y0; t.clip[2] = x1 > x0 ? x1 - x0 : 0; t.clip[3] = y1 > y0 ? y1 - y0 : 0;
        if (!t.clip[2] || !t.clip[3]) return;
    }
    if (g->n) walk(&t, g->u.args[0]);
}

void frame_begin(Frame *f, int w, int h) {
    f->nv = 0; f->nc = 0; f->width = w; f->height = h;
    f->clear[0] = f->clear[1] = f->clear[2] = f->clear[3] = 1;
}
int scene_draw(Frame *f, WNode *g) {
    F = f; atlasFull = 0; unsupported = NULL;
    if (!wis(g, "Graphics")) return 1;
    float pr[4];
    if (!plotRange(g, pr)) return 2;
    WNode *bg = wopt(g, "Background"); float c[4];
    if (bg && colour(bg, c)) { f->clear[0] = c[0] * c[3]; f->clear[1] = c[1] * c[3]; f->clear[2] = c[2] * c[3]; f->clear[3] = c[3]; }
    else if (bg && wsym(bg, "None")) { f->clear[0] = f->clear[1] = f->clear[2] = f->clear[3] = 0; }
    St s; memset(&s, 0, sizeof s);
    s.T = (Aff){1, 0, 0, -1, 0, (float)f->height};      /* the frame's rectangle in pixels, y up */
    s.op = 1; s.col[3] = 1; s.lw = 1; s.gw = (float)f->width;
    s.family = "Arial"; s.fsize = 10; s.weight = 400;
    s.clip[0] = 0; s.clip[1] = 0; s.clip[2] = f->width; s.clip[3] = f->height;
    /* the plot range fills the frame; its own Background was the clear colour */
    WNode *keep = wopt(g, "Background"); (void)keep;
    graphicsInto(&s, g, 0, 0, (float)f->width, (float)f->height);
    return unsupported ? 4 : atlasFull ? 3 : 0;
}
const char *scene_unsupported(void) { return unsupported; }
