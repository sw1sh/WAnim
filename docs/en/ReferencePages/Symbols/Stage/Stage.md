---
Template: Symbol
Name: Stage
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Stage
Keywords: [stage, scene, Manim, math coordinates, camera, animation, graphics]
SeeAlso: [Tween, Morph, PartialPath, StageAxes, StageBrace, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[Stage]()[*f*, {$t_0$, $t_1$}]</code> is a layer drawing *f*[*t*], ordinary graphics primitives in math coordinates, over the canvas.

## Details & Options

- The stage is Manim's frame by default: 14.2 by 8 units, origin at the centre, y up.
- *f*[*t*] may also be a [Graphics3D](), which fills the stage; an [Inset]() of one mixes 3D and 2D.
- Sizes are pixels of a 1080p frame and scale with it: `FontSize -> n`, <code>[Style]()[*s*, *n*]</code>, <code>[AbsoluteThickness]()[*n*]</code>, <code>[AbsolutePointSize]()[*n*]</code>. Manim's font size 48 reads as about 72.
- Unless the primitives say otherwise, text is FontColor in FontFamily at FontSize, and lines are "Thickness" pixels wide.
- [PlotRange]() may be a function of time, a camera that pans and zooms; so may "Screen", a display that moves and grows.

| Option | Default | Description |
| --- | --- | --- |
| PlotRange | {{-64/9, 64/9}, {-4, 4}} | the coordinates the stage shows |
| "Screen" | Automatic | a canvas rectangle {x, y, w, h}, or the whole canvas |
| Background | None | the stage's own background |
| FontSize | 72 | text size, pixels of a 1080p frame |
| FontColor | White | text and default colour |
| "Thickness" | 4 | default line width, pixels |

## Basic Examples

A square turning into a circle while a line sweeps round:

```wl
Timeline[{Stage[Function[t, {{EdgeForm[White], FaceForm[Orange], Morph[Rectangle[{-1, -1}, {1, 1}], Disk[{0, 0}, 1]][Tween[{0, 1}][t]]},
    {White, Line[{{3, 0}, {3, 0} + 2 {Cos[Pi t], Sin[Pi t]}}]}}], {0, 2}]}, "Duration" -> 2, Background -> Black]["Graphics", 0.6, ImageSize -> 480]
```

<!-- => a half-rounded orange square, a line at an angle -->

---

A camera that zooms in:

```wl
Timeline[{Stage[Function[t, {White, Table[Disk[{x, 0}, 0.2], {x, -6, 6, 2}]}], {0, 2}, PlotRange -> Function[t, With[{s = 1 - 0.6 Tween[{0, 2}][t]}, s {{-64/9, 64/9}, {-4, 4}}]]]},
    "Duration" -> 2, Background -> Black]["Graphics", 1.9, ImageSize -> 480]
```

<!-- => three large dots filling the frame -->

## Scope

A 3D picture on the stage, with text over it:

```wl
Timeline[{Stage[Function[t, {Inset[Graphics3D[Sphere[], Boxed -> False, ViewPoint -> {2 Cos[t], 2 Sin[t], 1}], {0, 0}, Center, {8, 8}], Text["a sphere", {-5, 3}]}], {0, 2}]},
    "Duration" -> 2, Background -> Black]["Graphics", 1, ImageSize -> 480]
```

<!-- => a sphere and a caption -->
