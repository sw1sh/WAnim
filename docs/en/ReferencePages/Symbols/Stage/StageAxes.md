---
Template: Symbol
Name: StageAxes
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/StageAxes
Keywords: [axes, coordinate system, plot, graph, area, Riemann, Manim Axes]
SeeAlso: [Stage, PartialPath, Tween]
RelatedGuides: [WAnim]
---

## Usage

<code>*ax* = [StageAxes]()[{$x_0$, $x_1$, *dx*}, {$y_0$, $y_1$, *dy*}]</code> is a pair of axes on a [Stage](), Manim's Axes.

## Details & Options

- *ax*["Primitives"] draws them, ticked every step, with the numbers in "Numbers" and arrow tips.
- <code>*ax*[{*x*, *y*}]</code> is where a data point sits on the stage; a list of points maps each.
- <code>*ax*["Graph", *f*, {*a*, *b*}]</code> is the curve of *f*; <code>*ax*["Area", *f*, *g*, {*a*, *b*}]</code> the region between two functions (*g* may be a constant); <code>*ax*["Riemann", *f*, {*a*, *b*}, *dx*]</code> rectangles under *f*.
- <code>*ax*["VerticalLine", {*x*, *y*}]</code> is a line down to the x axis; <code>*ax*["Labels", *xlabel*, *ylabel*]</code> names the axes.

| Option | Default | Description |
| --- | --- | --- |
| "Size" | {12, 6} | stage units across and up |
| "Center" | {0, 0} | where the axes' box is centred |
| "Color" | White | colour of the axes |
| "Tips" | True | arrow tips |
| "Numbers" | {{}, {}} | tick values to number, {x values, y values} |
| "LongTicks" | {{}, {}} | tick values with longer ticks |

## Basic Examples

A parabola on axes, a dot riding it:

```wl
With[{ax = StageAxes[{0, 10, 1}, {0, 100, 10}, "Tips" -> False]},
    Timeline[{Stage[Function[t, {ax["Primitives"], ax["Labels", "x", "f(x)"], {Pink, ax["Graph", 2 (# - 5)^2 &]}, {White, Disk[ax[{5 t, 2 (5 t - 5)^2}], 0.1]}}], {0, 1}]},
        "Duration" -> 1, Background -> Black]["Graphics", 0.5, ImageSize -> 480]]
```

<!-- => axes, a parabola, a dot on it -->

---

The area between two curves:

```wl
With[{ax = StageAxes[{0, 5, 1}, {0, 6, 1}, "Tips" -> False, "Numbers" -> {{2, 3}, {}}]},
    Timeline[{Stage[Function[t, {ax["Primitives"], {Cyan, ax["Graph", 4 # - #^2 &, {0, 4}]}, {Opacity[0.5], Gray, ax["Area", 0.8 #^2 - 3 # + 4 &, 4 # - #^2 &, {2, 3}]}}], {0, 1}]},
        "Duration" -> 1, Background -> Black]["Graphics", 0.5, ImageSize -> 480]]
```

<!-- => a shaded strip between two curves -->
