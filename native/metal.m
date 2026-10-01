/* The triangles drawn by Metal: premultiplied colours blended over, 4x multisampled, the stencil for
   concave fills and translucent strokes; images as textures kept by content across frames; the glyph atlas
   updated by the rows that changed.  The frame is resolved and read back straight-alpha. */
#import <Metal/Metal.h>
#include "wanimgpu.h"
#include <string.h>

static NSString *const shaders = @
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct O { float4 pos [[position]]; float2 uv; float4 c; };\n"
"vertex O vs(const device float *vb [[buffer(0)]], constant float2 &size [[buffer(1)]], uint vid [[vertex_id]]) {\n"
"  const device float *v = vb + vid * 8; O o;\n"
"  o.pos = float4(v[0] / size.x * 2 - 1, 1 - v[1] / size.y * 2, 0, 1); o.uv = float2(v[2], v[3]); o.c = float4(v[4], v[5], v[6], v[7]); return o; }\n"
"fragment float4 fsColor(O in [[stage_in]]) { return in.c; }\n"
"fragment float4 fsTex(O in [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]]) { return t.sample(s, in.uv) * in.c; }\n"
"fragment float4 fsGlyph(O in [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]]) { return in.c * t.sample(s, in.uv).r; }\n";

#define SAMPLES 4
static id<MTLDevice> dev;
static id<MTLCommandQueue> queue;
static id<MTLRenderPipelineState> pipes[3], stencilPipe;
static id<MTLDepthStencilState> dss[5];
static id<MTLSamplerState> linear;
static id<MTLTexture> msaa, stencilTex, resolved, atlasTex;
static int tw, th;
static id<MTLBuffer> vbuf;

/* ---- textures by content ---- */
#define NTEX 512
static id<MTLTexture> texs[NTEX + 1];
static uint64_t keys[NTEX + 1], used[NTEX + 1], tick;
int tex_find(int w, int h, uint64_t key) {
    tick++;
    for (int k = 1; k <= NTEX; k++) if (texs[k] && keys[k] == key && (int)texs[k].width == w && (int)texs[k].height == h) { used[k] = tick; return k; }
    return 0;
}
int tex_image(const uint8_t *rgba, int w, int h, uint64_t key) {
    if (!dev) return 0;
    int found = tex_find(w, h, key); if (found) return found;
    int slot = 0; uint64_t oldest = UINT64_MAX;
    for (int k = 1; k <= NTEX; k++) { if (!texs[k]) { slot = k; break; } if (used[k] < oldest) { oldest = used[k]; slot = k; } }
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:w height:h mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead; d.storageMode = MTLStorageModeShared;
    texs[slot] = [dev newTextureWithDescriptor:d];
    [texs[slot] replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:rgba bytesPerRow:(NSUInteger)w * 4];
    keys[slot] = key; used[slot] = tick;
    return slot;
}

static id<MTLRenderPipelineState> pipeline(id<MTLLibrary> lib, NSString *frag, BOOL writes, char *err, int errlen) {
    MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new];
    d.vertexFunction = [lib newFunctionWithName:@"vs"];
    d.fragmentFunction = [lib newFunctionWithName:frag];
    d.rasterSampleCount = SAMPLES;
    MTLRenderPipelineColorAttachmentDescriptor *c = d.colorAttachments[0];
    c.pixelFormat = MTLPixelFormatRGBA8Unorm;
    c.writeMask = writes ? MTLColorWriteMaskAll : MTLColorWriteMaskNone;
    c.blendingEnabled = YES;
    c.sourceRGBBlendFactor = c.sourceAlphaBlendFactor = MTLBlendFactorOne;
    c.destinationRGBBlendFactor = c.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    d.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    d.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    NSError *e = nil;
    id<MTLRenderPipelineState> p = [dev newRenderPipelineStateWithDescriptor:d error:&e];
    if (!p && err) snprintf(err, errlen, "pipeline: %s", e.localizedDescription.UTF8String);
    return p;
}
static id<MTLDepthStencilState> stencilState(MTLStencilOperation front, MTLStencilOperation back, MTLCompareFunction cmp, BOOL on) {
    MTLDepthStencilDescriptor *d = [MTLDepthStencilDescriptor new];
    if (on) {
        MTLStencilDescriptor *f = [MTLStencilDescriptor new], *b = [MTLStencilDescriptor new];
        f.stencilCompareFunction = b.stencilCompareFunction = cmp;
        f.depthStencilPassOperation = front; b.depthStencilPassOperation = back;
        f.stencilFailureOperation = b.stencilFailureOperation = MTLStencilOperationKeep;
        d.frontFaceStencil = f; d.backFaceStencil = b;
    }
    return [dev newDepthStencilStateWithDescriptor:d];
}
int gpu_init(char *err, int errlen) {
    if (dev) return 0;
    @autoreleasepool {
        dev = MTLCreateSystemDefaultDevice();
        if (!dev) { snprintf(err, errlen, "no Metal device"); return 1; }
        queue = [dev newCommandQueue];
        NSError *e = nil;
        id<MTLLibrary> lib = [dev newLibraryWithSource:shaders options:nil error:&e];
        if (!lib) { snprintf(err, errlen, "shaders: %s", e.localizedDescription.UTF8String); dev = nil; return 1; }
        pipes[P_COLOR] = pipeline(lib, @"fsColor", YES, err, errlen);
        pipes[P_TEX] = pipeline(lib, @"fsTex", YES, err, errlen);
        pipes[P_GLYPH] = pipeline(lib, @"fsGlyph", YES, err, errlen);
        stencilPipe = pipeline(lib, @"fsColor", NO, err, errlen);
        if (!pipes[0] || !pipes[1] || !pipes[2] || !stencilPipe) { dev = nil; return 1; }
        dss[S_NONE] = stencilState(MTLStencilOperationKeep, MTLStencilOperationKeep, MTLCompareFunctionAlways, NO);
        dss[S_WRITE_NONZERO] = stencilState(MTLStencilOperationIncrementWrap, MTLStencilOperationDecrementWrap, MTLCompareFunctionAlways, YES);
        dss[S_WRITE_EVENODD] = stencilState(MTLStencilOperationInvert, MTLStencilOperationInvert, MTLCompareFunctionAlways, YES);
        dss[S_WRITE_ONE] = stencilState(MTLStencilOperationReplace, MTLStencilOperationReplace, MTLCompareFunctionAlways, YES);
        dss[S_COVER] = stencilState(MTLStencilOperationZero, MTLStencilOperationZero, MTLCompareFunctionNotEqual, YES);
        MTLSamplerDescriptor *sd = [MTLSamplerDescriptor new];
        sd.minFilter = sd.magFilter = MTLSamplerMinMagFilterLinear;
        sd.sAddressMode = sd.tAddressMode = MTLSamplerAddressModeClampToEdge;
        linear = [dev newSamplerStateWithDescriptor:sd];
        MTLTextureDescriptor *ad = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:ATLAS height:ATLAS mipmapped:NO];
        ad.usage = MTLTextureUsageShaderRead; ad.storageMode = MTLStorageModeShared;
        atlasTex = [dev newTextureWithDescriptor:ad];
        text_reset();
    }
    return 0;
}
static void targets(int w, int h) {
    if (w == tw && h == th) return;
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:w height:h mipmapped:NO];
    d.textureType = MTLTextureType2DMultisample; d.sampleCount = SAMPLES; d.usage = MTLTextureUsageRenderTarget; d.storageMode = MTLStorageModeMemoryless;
    msaa = [dev newTextureWithDescriptor:d];
    MTLTextureDescriptor *s = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8 width:w height:h mipmapped:NO];
    s.textureType = MTLTextureType2DMultisample; s.sampleCount = SAMPLES; s.usage = MTLTextureUsageRenderTarget; s.storageMode = MTLStorageModeMemoryless;
    stencilTex = [dev newTextureWithDescriptor:s];
    MTLTextureDescriptor *r = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:w height:h mipmapped:NO];
    r.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead; r.storageMode = MTLStorageModeShared;
    resolved = [dev newTextureWithDescriptor:r];
    tw = w; th = h;
}
int gpu_render(Frame *f, uint8_t *out) {
    if (!dev) return 1;
    @autoreleasepool {
        int w = f->width, h = f->height;
        targets(w, h);
        int y0, y1;
        if (atlas_dirty(&y0, &y1)) {
            [atlasTex replaceRegion:MTLRegionMake2D(0, y0, ATLAS, y1 - y0 + 1) mipmapLevel:0 withBytes:atlas_pixels() + (size_t)y0 * ATLAS bytesPerRow:ATLAS];
            atlas_clean();
        }
        size_t vb = sizeof(Vtx) * (size_t)(f->nv ? f->nv : 1);
        if (!vbuf || vbuf.length < vb) vbuf = [dev newBufferWithLength:vb * 3 / 2 options:MTLResourceStorageModeShared];
        memcpy(vbuf.contents, f->v, sizeof(Vtx) * (size_t)f->nv);
        MTLRenderPassDescriptor *rp = [MTLRenderPassDescriptor renderPassDescriptor];
        rp.colorAttachments[0].texture = msaa; rp.colorAttachments[0].resolveTexture = resolved;
        rp.colorAttachments[0].loadAction = MTLLoadActionClear; rp.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
        rp.colorAttachments[0].clearColor = MTLClearColorMake(f->clear[0], f->clear[1], f->clear[2], f->clear[3]);
        rp.depthAttachment.texture = stencilTex; rp.depthAttachment.loadAction = MTLLoadActionClear; rp.depthAttachment.storeAction = MTLStoreActionDontCare;
        rp.stencilAttachment.texture = stencilTex; rp.stencilAttachment.loadAction = MTLLoadActionClear; rp.stencilAttachment.storeAction = MTLStoreActionDontCare;
        rp.stencilAttachment.clearStencil = 0;
        id<MTLCommandBuffer> cb = [queue commandBuffer];
        id<MTLRenderCommandEncoder> en = [cb renderCommandEncoderWithDescriptor:rp];
        float size[2] = {(float)w, (float)h};
        [en setVertexBuffer:vbuf offset:0 atIndex:0];
        [en setVertexBytes:size length:sizeof size atIndex:1];
        [en setFragmentSamplerState:linear atIndex:0];
        [en setCullMode:MTLCullModeNone];
        [en setStencilReferenceValue:1];
        int lastPipe = -2, lastSt = -1, lastTex = -2, lastClip[4] = {-1, -1, -1, -1};
        for (int k = 0; k < f->nc; k++) {
            Cmd *c = &f->c[k];
            int writes = c->stencil == S_WRITE_NONZERO || c->stencil == S_WRITE_EVENODD || c->stencil == S_WRITE_ONE;
            int pk = writes ? -1 : c->pipe;
            if (pk != lastPipe) { [en setRenderPipelineState:writes ? stencilPipe : pipes[c->pipe]]; lastPipe = pk; }
            if (c->stencil != lastSt) { [en setDepthStencilState:dss[c->stencil]]; [en setStencilReferenceValue:c->stencil == S_COVER ? 0 : 1]; lastSt = c->stencil; }
            if (memcmp(c->clip, lastClip, sizeof lastClip)) {
                int x = c->clip[0] < 0 ? 0 : c->clip[0], y = c->clip[1] < 0 ? 0 : c->clip[1];
                int cw = c->clip[2], ch = c->clip[3];
                if (x + cw > w) cw = w - x; if (y + ch > h) ch = h - y;
                if (cw <= 0 || ch <= 0) continue;
                [en setScissorRect:(MTLScissorRect){(NSUInteger)x, (NSUInteger)y, (NSUInteger)cw, (NSUInteger)ch}];
                memcpy(lastClip, c->clip, sizeof lastClip);
            }
            if (c->pipe != P_COLOR && c->tex != lastTex) {
                id<MTLTexture> t = c->tex < 0 ? atlasTex : texs[c->tex];
                if (!t) continue;
                [en setFragmentTexture:t atIndex:0]; lastTex = c->tex;
            }
            [en drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:c->first vertexCount:c->count];
        }
        [en endEncoding];
        [cb commit];
        [cb waitUntilCompleted];
        if (cb.error) return 2;
        [resolved getBytes:out bytesPerRow:(NSUInteger)w * 4 fromRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0];
        /* straight alpha, as images are */
        size_t n = (size_t)w * h;
        for (size_t k = 0; k < n; k++) {
            uint8_t a = out[4 * k + 3];
            if (a && a < 255) for (int j = 0; j < 3; j++) { int v = (out[4 * k + j] * 255 + a / 2) / a; out[4 * k + j] = (uint8_t)(v > 255 ? 255 : v); }
        }
    }
    return 0;
}
