---
Template: Symbol
Name: Morph
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Morph
Keywords: [morph, transform, shape, interpolate, Manim Transform]
SeeAlso: [PartialPath, Tween, Stage]
RelatedGuides: [WAnim]
---

## Usage

<code>[Morph]()[*a*, *b*]</code> is a function of *u* giving shape *a* at 0 turning into shape *b* at 1, as a [Polygon]().

<code>[Morph]()[*a*, *b*, *u*]</code> is that shape at *u*.

## Details & Options

- Both outlines are sampled at the same number of points by arc length, starting due east of their centres and running counterclockwise, and the points are blended.
- Shapes: [Disk](), [Circle](), [Rectangle](), [Polygon](), [Triangle](), a closed [Line](), [RegularPolygon]() or any 2D region.
- <code>[Morph]()[*a*, *b*, *n*]</code> samples *n* points (default 120).

## Basic Examples

A square becoming a circle:

```wl
Graphics[{Opacity[0.6], Table[{Hue[u], Morph[Rectangle[{-1, -1}, {1, 1}], Disk[]][u]}, {u, 0, 1, 0.25}]}]
```

<!-- => nested shapes from square to circle -->

---

A triangle into a star:

```wl
Graphics[Morph[Triangle[{{0, 1}, {-1, -1}, {1, -1}}], Polygon[Table[(1 + Mod[k, 2]) {Cos[k Pi/5 + Pi/2], Sin[k Pi/5 + Pi/2]} / 2, {k, 0, 9}]], 0.7]]
```

<!-- => a triangle part-way to a star -->
