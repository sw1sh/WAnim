---
Template: Symbol
Name: CanvasScreen
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/CanvasScreen
Keywords: [retro, low resolution, 1-bit, pixel art, display, dithering, screen]
SeeAlso: [RasterScreen, OrderedDither, NotebookSession, CanvasBlock]
RelatedGuides: [WAnim]
---

## Usage

<code>[CanvasScreen]()[{*x*, *y*, *w*, *h*}, *f*]</code> draws *f*[*lw*, *lh*] on a screen of *lw* x *lh* logical pixels and shows it in the canvas rectangle as an old display would.

## Details & Options

- The screen is "Pixel" canvas pixels per logical pixel, so *lw* = *w* / "Pixel"; *f* draws on it with the canvas kit.
- "Depth" -> "Bit" thresholds to one bit ("Threshold", default 160/255), "Gray4" quantizes to the NeXT's four greys, "Color" keeps colour at the low resolution, "Full" draws vector graphics magnified.
- The low-resolution image is enlarged nearest-neighbour, so pixels read as pixels. Pictures shown on a one-bit screen should first be reduced with [OrderedDither]().

| Option | Default | Description |
| --- | --- | --- |
| "Pixel" | 2 | canvas pixels per logical pixel |
| "Depth" | "Full" | "Bit", "Gray4", "Color" or "Full" |
| Background | White | the screen's background |
| "Threshold" | 160/255 | the one-bit threshold |

## Basic Examples

A disk and some text on a one-bit screen at half resolution:

```wl
Graphics[CanvasBlock[{600, 300}, CanvasScreen[{50, 50, 500, 200}, Function[{lw, lh}, {CanvasDisk[{60, 50}, 40, Black], CanvasText["one bit", {120, 60}, CanvasFont["Arimo", 14, 700], Black]}], "Pixel" -> 2, "Depth" -> "Bit"]], PlotRange -> {{0, 600}, {0, 300}}, ImageSize -> 480]
```

<!-- => a blocky disk and pixelated text -->

---

The same in four greys at a third of the resolution:

```wl
Graphics[CanvasBlock[{600, 300}, CanvasScreen[{50, 50, 500, 200}, Function[{lw, lh}, {CanvasDisk[{40, 33}, 26, GrayLevel[0.3]], CanvasText["NeXT", {80, 40}, CanvasFont["Arimo", 12, 700], GrayLevel[0.6]]}], "Pixel" -> 3, "Depth" -> "Gray4"]], PlotRange -> {{0, 600}, {0, 300}}, ImageSize -> 480]
```

<!-- => coarse grey shapes -->
