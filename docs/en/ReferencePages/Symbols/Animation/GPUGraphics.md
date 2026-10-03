---
Template: Symbol
Name: GPUGraphics
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/GPUGraphics
Keywords: [GPU, Metal, rasterize, render, fast, frames, video]
SeeAlso: [AnimatedGraphics, Rasterize, Graphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[GPUGraphics]()[*graphics*]</code> draws a [Graphics]() on the GPU, without the front end, into an [Image]().

<code>[GPUGraphics]()[*primitives*, *opts*]</code> takes what [Graphics]() takes.

## Details & Options

- It draws polygons (with VertexColors), lines, disks, circles, rectangles (rounded), points, text in any installed font, and insets of images and of graphics, under colours, Opacity, FaceForm, EdgeForm, Thickness, CapForm, Rotate and Style: everything the canvas kit and the film tools emit. It is tens of times faster than [Rasterize]().
- The plot range must be explicit. Anything else (curves, arrows, dashing, typeset boxes, 3D) gives a [Failure]() saying what, so a caller can rasterize with the front end instead: exporting an [AnimatedGraphics]() does exactly that, frame by frame.
- The native renderer is C, Metal and CoreText through LibraryLink, built for macOS on Apple silicon.

## Basic Examples

A frame drawn on the GPU:

```wl
GPUGraphics[{Orange, Disk[{0, 0}, 1], White, Text[Style["GPU", 40], {0, 0}]}, PlotRange -> {{-2, 2}, {-1.2, 1.2}}, ImageSize -> 400, Background -> Black]
```

<!-- => an orange disk with GPU written on it, as an Image -->

---

What it does not draw, it says:

```wl
GPUGraphics[{Arrow[{{0, 0}, {1, 1}}]}, PlotRange -> {{0, 1}, {0, 1}}]["Message"]
```

<!-- => "unsupported: Arrow" -->
