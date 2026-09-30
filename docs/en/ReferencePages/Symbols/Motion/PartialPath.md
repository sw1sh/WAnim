---
Template: Symbol
Name: PartialPath
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/PartialPath
Keywords: [partial, path, create, draw, outline, Manim Create]
SeeAlso: [Morph, Tween]
RelatedGuides: [WAnim]
---

## Usage

<code>[PartialPath]()[*shape*, *u*]</code> is the first *u* of *shape*'s outline, as a [Line]().

## Details & Options

- It is Manim's Create: *u* going from 0 to 1 draws the shape.
- A [Line]() or [BSplineCurve]() is drawn from its first point; a closed shape counterclockwise from due east of its centre.
- A list of shapes gives a list of partial paths.

## Basic Examples

A circle two-thirds drawn:

```wl
Graphics[{Thick, PartialPath[Circle[], 2/3]}]
```

<!-- => an arc of 240 degrees -->

---

A plot drawn in stages:

```wl
Graphics[Table[{Hue[u], Translate[PartialPath[Line[Table[{x, Sin[x]}, {x, 0, 2 Pi, 0.05}]], u], {0, -3 u}]}, {u, 0.25, 1, 0.25}]]
```

<!-- => four sine curves, each longer than the last -->
