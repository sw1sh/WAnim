---
Template: Symbol
Name: CanvasText
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/CanvasText
Keywords: [text, canvas, baseline, font, tracking, letter spacing, typography]
SeeAlso: [CanvasFont, CanvasTextWidth, CanvasWrap, Text]
RelatedGuides: [WAnim]
---

## Usage

<code>[CanvasText]()["*text*", {*x*, *y*}, *font*, *colour*]</code> draws *text* with its alphabetic baseline at canvas point {*x*, *y*}, the way a browser canvas's fillText does.

## Details & Options

- Canvas coordinates are pixels with $y$ down, on the canvas of the [AnimatedGraphics]() drawing it ("CanvasSize").
- *font* is a [CanvasFont](); its size is in pixels and follows the current [CanvasTransform]().
- Widths come from per-face advance tables measured once through the front end and cached, so [CanvasTextWidth]() agrees with what is drawn; font sizes are emitted as fractions of the canvas width, so text keeps its proportions at any `ImageSize`.

| Option | Default | Description |
| --- | --- | --- |
| Alignment | Left | Left, Center or Right about x |
| Opacity | 1 | opacity, multiplied by any CanvasOpacity |
| "Tracking" | 0 | extra space between letters, in pixels |

## Basic Examples

Text on its baseline, with the baseline drawn:

```wl
AnimatedGraphics[{CanvasLine[{{0, 120}, {600, 120}}, Red], CanvasText["Baseline", {40, 120}, CanvasFont["Source Sans 3", 80, 700], Black]}, "CanvasSize" -> {600, 200}, Background -> White][0, ImageSize -> 360]
```

<!-- => the word sitting on a red line -->

---

Centred, and tracked:

```wl
AnimatedGraphics[{CanvasText["CENTRED", {300, 80}, CanvasFont["Source Sans 3", 40, 600], Black, Alignment -> Center], CanvasText["TRACKED", {300, 160}, CanvasFont["Source Sans 3", 20, 600], Red, Alignment -> Center, "Tracking" -> 8]}, "CanvasSize" -> {600, 200}, Background -> White][0, ImageSize -> 360]
```

<!-- => two centred lines, the second with wide letter spacing -->
