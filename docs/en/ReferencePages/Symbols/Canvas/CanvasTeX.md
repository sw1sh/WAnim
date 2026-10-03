---
Template: Symbol
Name: CanvasTeX
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/CanvasTeX
Keywords: [TeX, LaTeX, MaTeX, formula, math, canvas, caption, typesetting]
SeeAlso: [CanvasText, CanvasTeXWidth, CanvasFont, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[CanvasTeX]()["*tex*", {*x*, *y*}, *size*, *colour*]</code> typesets the TeX formula *tex* with its baseline at canvas point {*x*, *y*}, its type *size* pixels.

<code>[CanvasTeX]()["*text* $*tex*$ *text*", {*x*, *y*}, *font*, *colour*]</code> sets text in the [CanvasFont]() *font* with the mathematics between dollars typeset inline, on the same baseline.

## Details & Options

- Formulas are typeset by MaTeX (which needs a LaTeX installation) and drawn as glyph outlines: polygons filled even-odd, so the holes of letters are cut, and fraction bars and root signs drawn as bars. They are sharp at any size, fade with [CanvasOpacity]() and draw on the GPU ([GPUGraphics]()).
- A formula is typeset once and kept on disk. Exporting a film typesets every formula in it before its frames are drawn, so the kernels that draw them find each one ready.
- A formula MaTeX cannot typeset is reported once and drawn as nothing.

| Option | Default | Description |
| --- | --- | --- |
| Alignment | Left | Left, Center or Right about x |
| Opacity | 1 | opacity, multiplied by any CanvasOpacity |

## Basic Examples

A formula on the canvas:

```wl
AnimatedGraphics[{CanvasTeX["\\Delta x\\,\\Delta p \\ge \\frac{\\hbar}{2}", {300, 130}, 72, Black, Alignment -> Center]}, "CanvasSize" -> {600, 200}, Background -> White][0, ImageSize -> 360]
```

<!-- => the uncertainty relation, typeset -->

---

A caption with mathematics inline:

```wl
AnimatedGraphics[{CanvasTeX["a qubit: $|\\psi\\rangle = \\alpha|0\\rangle + \\beta|1\\rangle$", {30, 110}, CanvasFont["Source Sans 3", 36], Black]}, "CanvasSize" -> {600, 200}, Background -> White][0, ImageSize -> 360]
```

<!-- => text with a ket expression set in TeX -->
