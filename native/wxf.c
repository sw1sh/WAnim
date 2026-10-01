/* The expression from its WXF bytes: https://reference.wolfram.com/language/tutorial/WXFFormatDescription.html
   Arrays are not copied: an array node points into the bytes, which outlive the frame's drawing. */
#include "wanimgpu.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* ---- arena ---- */
typedef struct Block { struct Block *next; size_t used, cap; char data[]; } Block;
static Block *blocks;
void *arena_alloc(size_t n) {
    n = (n + 15) & ~(size_t)15;
    if (!blocks || blocks->used + n > blocks->cap) {
        size_t cap = n > (1 << 22) ? n : (1 << 22);
        Block *b = malloc(sizeof(Block) + cap);
        if (!b) return NULL;
        b->next = blocks; b->used = 0; b->cap = cap; blocks = b;
    }
    void *p = blocks->data + blocks->used;
    blocks->used += n;
    return p;
}
void arena_reset(void) {
    /* keep the newest block, free the rest */
    if (!blocks) return;
    Block *b = blocks->next;
    while (b) { Block *n = b->next; free(b); b = n; }
    blocks->next = NULL; blocks->used = 0;
}

/* ---- parsing ---- */
typedef struct { const uint8_t *p, *end; int bad; } Rd;
static uint64_t varint(Rd *r) {
    uint64_t v = 0; int s = 0;
    while (r->p < r->end) {
        uint8_t b = *r->p++;
        v |= (uint64_t)(b & 0x7f) << s;
        if (!(b & 0x80)) return v;
        s += 7;
        if (s > 63) break;
    }
    r->bad = 1; return 0;
}
static int need(Rd *r, size_t n) { if ((size_t)(r->end - r->p) < n) { r->bad = 1; return 0; } return 1; }
static WNode *node(int k) { WNode *e = arena_alloc(sizeof(WNode)); memset(e, 0, sizeof *e); e->k = k; return e; }
static const char *copystr(const uint8_t *s, size_t n) { char *c = arena_alloc(n + 1); memcpy(c, s, n); c[n] = 0; return c; }
static int elemsize(int t) {
    switch (t) {
        case 0x00: case 0x10: return 1;
        case 0x01: case 0x11: return 2;
        case 0x02: case 0x12: case 0x22: return 4;
        case 0x03: case 0x13: case 0x23: case 0x33: return 8;
        case 0x34: return 16;
        default: return 0;
    }
}
static WNode *expr(Rd *r);
static WNode *symbol(const uint8_t *s, size_t n) {
    WNode *e = node(W_SYM);
    if (n > 7 && !memcmp(s, "System`", 7)) { s += 7; n -= 7; }
    e->u.s = copystr(s, n); e->n = (int32_t)n;
    return e;
}
static WNode *expr(Rd *r) {
    if (r->bad || !need(r, 1)) return NULL;
    uint8_t t = *r->p++;
    WNode *e;
    switch (t) {
        case 'C': if (!need(r, 1)) return NULL; e = node(W_INT); e->u.i = (int8_t)r->p[0]; r->p += 1; return e;
        case 'j': { if (!need(r, 2)) return NULL; int16_t v; memcpy(&v, r->p, 2); r->p += 2; e = node(W_INT); e->u.i = v; return e; }
        case 'i': { if (!need(r, 4)) return NULL; int32_t v; memcpy(&v, r->p, 4); r->p += 4; e = node(W_INT); e->u.i = v; return e; }
        case 'L': { if (!need(r, 8)) return NULL; int64_t v; memcpy(&v, r->p, 8); r->p += 8; e = node(W_INT); e->u.i = v; return e; }
        case 'r': { if (!need(r, 8)) return NULL; double v; memcpy(&v, r->p, 8); r->p += 8; e = node(W_REAL); e->u.r = v; return e; }
        case 'I': case 'R': {       /* big integer, big real: as text */
            uint64_t n = varint(r); if (!need(r, n)) return NULL;
            e = node(W_REAL); e->u.r = strtod(copystr(r->p, n), NULL); r->p += n; return e;
        }
        case 'S': case 'B': {
            uint64_t n = varint(r); if (!need(r, n)) return NULL;
            e = node(W_STR); e->u.s = copystr(r->p, n); e->n = (int32_t)n; r->p += n; return e;
        }
        case 's': {
            uint64_t n = varint(r); if (!need(r, n)) return NULL;
            e = symbol(r->p, n); r->p += n; return e;
        }
        case 'f': {
            uint64_t n = varint(r);
            e = node(W_FUNC); e->n = (int32_t)n;
            e->head = expr(r);
            e->u.args = arena_alloc(sizeof(WNode *) * (n ? n : 1));
            for (uint64_t k = 0; k < n && !r->bad; k++) e->u.args[k] = expr(r);
            return r->bad ? NULL : e;
        }
        case 'A': {                 /* an association: Association[rules] */
            uint64_t n = varint(r);
            e = node(W_FUNC); e->n = (int32_t)n;
            e->head = symbol((const uint8_t *)"Association", 11);
            e->u.args = arena_alloc(sizeof(WNode *) * (n ? n : 1));
            for (uint64_t k = 0; k < n && !r->bad; k++) {
                if (!need(r, 1)) return NULL;
                uint8_t rt = *r->p++;
                WNode *rule = node(W_FUNC); rule->n = 2;
                rule->head = symbol((const uint8_t *)(rt == ':' ? "RuleDelayed" : "Rule"), rt == ':' ? 11 : 4);
                rule->u.args = arena_alloc(2 * sizeof(WNode *));
                rule->u.args[0] = expr(r); rule->u.args[1] = expr(r);
                e->u.args[k] = rule;
            }
            return r->bad ? NULL : e;
        }
        case 0xC1: case 0xC2: {     /* packed array, numeric array */
            if (!need(r, 1)) return NULL;
            int at = *r->p++;
            uint64_t rank = varint(r);
            e = node(W_ARR); e->atype = (uint8_t)at; e->rank = (uint8_t)rank;
            e->dims = arena_alloc(sizeof(int64_t) * (rank ? rank : 1));
            uint64_t total = 1;
            for (uint64_t k = 0; k < rank; k++) { e->dims[k] = (int64_t)varint(r); total *= (uint64_t)e->dims[k]; }
            size_t bytes = total * (size_t)elemsize(at);
            if (!elemsize(at) || !need(r, bytes)) { r->bad = 1; return NULL; }
            e->u.data = r->p; e->n = (int32_t)total; r->p += bytes;
            return e;
        }
        default: r->bad = 1; return NULL;
    }
}
WNode *wxf_parse(const uint8_t *b, size_t len) {
    Rd r = {b, b + len, 0};
    if (len < 2 || b[0] != '8' || b[1] != ':') return NULL;   /* compressed WXF ("8C:") is not read */
    r.p += 2;
    return expr(&r);
}

/* ---- reading ---- */
int wis(const WNode *e, const char *h) { return e && e->k == W_FUNC && e->head && e->head->k == W_SYM && !strcmp(e->head->u.s, h); }
int wsym(const WNode *e, const char *s) { return e && e->k == W_SYM && !strcmp(e->u.s, s); }
int wstr(const WNode *e, const char *s) { return e && e->k == W_STR && !strcmp(e->u.s, s); }
double warr(const WNode *a, int64_t k) {
    const uint8_t *p = a->u.data + k * elemsize(a->atype);
    switch (a->atype) {
        case 0x00: return (int8_t)*p;
        case 0x10: return *p;
        case 0x01: { int16_t v; memcpy(&v, p, 2); return v; }
        case 0x11: { uint16_t v; memcpy(&v, p, 2); return v; }
        case 0x02: { int32_t v; memcpy(&v, p, 4); return v; }
        case 0x12: { uint32_t v; memcpy(&v, p, 4); return v; }
        case 0x03: { int64_t v; memcpy(&v, p, 8); return (double)v; }
        case 0x13: { uint64_t v; memcpy(&v, p, 8); return (double)v; }
        case 0x22: { float v; memcpy(&v, p, 4); return v; }
        case 0x23: { double v; memcpy(&v, p, 8); return v; }
        default: return NAN;
    }
}
double wnum(const WNode *e) {
    if (!e) return NAN;
    if (e->k == W_INT) return (double)e->u.i;
    if (e->k == W_REAL) return e->u.r;
    if (wis(e, "Rational") && e->n == 2) return wnum(e->u.args[0]) / wnum(e->u.args[1]);
    if (wis(e, "Times")) { double v = 1; for (int k = 0; k < e->n; k++) v *= wnum(e->u.args[k]); return v; }
    if (wis(e, "Plus")) { double v = 0; for (int k = 0; k < e->n; k++) v += wnum(e->u.args[k]); return v; }
    if (wis(e, "Minus") && e->n == 1) return -wnum(e->u.args[0]);
    if (wsym(e, "Pi")) return M_PI;
    if (wsym(e, "Degree")) return M_PI / 180;
    if (wis(e, "DirectedInfinity")) return INFINITY;
    return NAN;
}
int wlen(const WNode *e) {
    if (!e) return -1;
    if (wis(e, "List")) return e->n;
    if (e->k == W_ARR) return (int)e->dims[0];
    return -1;
}
WNode *wopt(const WNode *e, const char *name) {
    if (!e || e->k != W_FUNC) return NULL;
    for (int k = 0; k < e->n; k++) {         /* the first setting wins, as in Options */
        WNode *a = e->u.args[k];
        if ((wis(a, "Rule") || wis(a, "RuleDelayed")) && a->n == 2 && wsym(a->u.args[0], name)) return a->u.args[1];
    }
    return NULL;
}
int wpoints(const WNode *e, float **xy) {
    if (!e) return -1;
    if (e->k == W_ARR) {
        if (e->rank != 2 || e->dims[1] != 2) return -1;
        int n = (int)e->dims[0];
        float *o = arena_alloc(sizeof(float) * 2 * (n ? n : 1));
        for (int k = 0; k < 2 * n; k++) o[k] = (float)warr(e, k);
        *xy = o; return n;
    }
    if (!wis(e, "List")) return -1;
    int n = e->n;
    float *o = arena_alloc(sizeof(float) * 2 * (n ? n : 1));
    for (int k = 0; k < n; k++) {
        WNode *p = e->u.args[k];
        double x, y;
        if (p->k == W_ARR && p->rank == 1 && p->dims[0] == 2) { x = warr(p, 0); y = warr(p, 1); }
        else if (wis(p, "List") && p->n == 2) { x = wnum(p->u.args[0]); y = wnum(p->u.args[1]); }
        else return -1;
        if (isnan(x) || isnan(y)) return -1;
        o[2 * k] = (float)x; o[2 * k + 1] = (float)y;
    }
    *xy = o; return n;
}
