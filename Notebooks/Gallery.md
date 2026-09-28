---
Template: ComputationalEssay
Name: "WAnim Gallery"
Author: Nikolay Murzin
Date: 2026
Description: "The Manim example gallery, scene by scene, in the Wolfram Language with WAnim"
Abstract: "Manim's gallery is the standard tour of what an animation library can do: shapes and braces, value trackers and updaters, plots, moving and zoomed cameras, 3D scenes. Here is every one of its scenes written with WAnim. A scene is a Timeline; its picture is a Stage, a function of time that returns ordinary Wolfram Language graphics in Manim's coordinates. Values that move are Tweens, a shape turning into another is a Morph, a path being drawn is a PartialPath, and plots sit on StageAxes. There are no updaters: every frame is computed from the time alone."
Keywords: [WAnim, Manim, animation, gallery, Timeline, Stage, Tween]
Sources: ["[Manim example gallery](https://docs.manim.community/en/stable/examples.html)", "[WAnim](https://github.com/sw1sh/WAnim)"]
---

## Setting Up

The paclet:

```wl
Needs["WolframInstitute`WAnim`"]
```

Manim's colours:

```wl
mc = <|"Blue" -> RGBColor["#58C4DD"], "BlueD" -> RGBColor["#29ABCA"], "Green" -> RGBColor["#83C167"], "GreenB" -> RGBColor["#A6CF8C"], "Red" -> RGBColor["#FC6255"],
    "RedD" -> RGBColor["#E65A4C"], "RedE" -> RGBColor["#CF5044"], "Yellow" -> RGBColor["#FFFF00"], "YellowD" -> RGBColor["#F4D345"], "YellowB" -> RGBColor["#FFEA94"],
    "YellowA" -> RGBColor["#FFF1B6"], "Orange" -> RGBColor["#FF862F"], "Pink" -> RGBColor["#D147BD"], "Purple" -> RGBColor["#9A72AC"], "Maroon" -> RGBColor["#C55F73"],
    "Grey" -> RGBColor["#888888"], "Gold" -> RGBColor["#F0AC5F"]|>
```

Three small conveniences: a dot, a scene of a given length on black, and playing it as an animated image:

```wl
dot[p_, col_ : White, r_ : 0.08] := {col, Disk[p, r]};
scene[layers_, dur_, bg_ : Black] := Timeline[Flatten[{layers}], "Duration" -> dur, Background -> bg];
play[tl_] := tl["AnimatedImage", "FrameRate" -> 15, ImageSize -> 480];
```

A shape grown or scaled about a point:

```wl
scaled[g_, s_, c_] := GeometricTransformation[g, ScalingTransform[{1, 1} Max[s, 0.001], c]];
```

## Basic Concepts

### The Logo

Manim's logo, assembled piece by piece, with a W for its letter:

```wl
logo = Module[{grow = Tween[{#, # + 0.5}, "OutBack"] &},
    Stage[Function[t, Translate[{
        scaled[{RGBColor["#e07a5f"], Triangle[{{1, 1}, {1 - Sqrt[3]/2, -0.5}, {1 + Sqrt[3]/2, -0.5}}]}, grow[0][t], {1, 0}],
        scaled[{RGBColor["#525893"], Rectangle[{-1, 0}, {1, 2}]}, grow[0.3][t], {0, 1}],
        scaled[{RGBColor["#87c2a5"], Disk[{-1, 0}, 1]}, grow[0.6][t], {-1, 0}],
        Text[Style["\[DoubleStruckCapitalW]", 330, FontColor -> RGBColor[0.2, 0.2, 0.2, Tween[{1.1, 1.6}][t]]], {-2.25, 1.5}]}, {0.52, -0.65}]], {0, 3}]];
play[scene[logo, 3, RGBColor["#ece6e2"]]]
```

### Brace Annotation

A line between two dots, braced along it and across it:

```wl
braces = With[{a = {-2, -1}, b = {2, 1}},
    Stage[Function[t, {{mc["Orange"], PartialPath[Line[{a, b}], Tween[{0, 1}][t]]}, dot[a], dot[b],
        {Opacity[Tween[{1, 1.5}][t]], StageBrace[{{-2, -1.1}, {2, -1.1}}], Text["Horizontal distance", StageBrace[{{-2, -1.1}, {2, -1.1}}, "Tip"]],
            StageBrace[{b, a}], Text[Style[TraditionalForm[x - Subscript[x, 1]], 72], StageBrace[{b, a}, "Tip"]]}}], {0, 2.5}]];
play[scene[braces, 2.5]]
```

### Vector Arrow

A vector on the number plane:

```wl
plane[] := {{mc["BlueD"], AbsoluteThickness[2], Table[Line[{{x, -4}, {x, 4}}], {x, -7, 7}], Table[Line[{{-7.2, y}, {7.2, y}}], {y, -4, 4}]},
    {White, AbsoluteThickness[2], Line[{{-7.2, 0}, {7.2, 0}}], Line[{{0, -4}, {0, 4}}]}};
vectorArrow = Stage[Function[t, With[{p = Tween[{0.2, 1.2}, {{0, 0}, {2, 2}}][t]}, {plane[], dot[{0, 0}],
    {White, Arrowheads[0.025], If[Norm[p] > 0.01, Arrow[{{0, 0}, p}], {}]},
    Text["(0, 0)", {0, -0.45}], {Opacity[Tween[{1.1, 1.4}][t]], Text["(2, 2)", {2.25, 2}, {-1, 0}]}}]], {0, 2}];
play[scene[vectorArrow, 2]]
```

### Gradient Image from an Array

An image made from an array of numbers, framed:

```wl
gradient = Image[Table[i / 255., {256}, {i, 0, 255}]];
gradientImage = Stage[Function[t, {Inset[gradient, {0, 0}, Center, 4 Tween[{0, 1}][t] + 0.001],
    {mc["Green"], FaceForm[], EdgeForm[{mc["Green"], AbsoluteThickness[4]}], PartialPath[Rectangle[{-2, -2}, {2, 2}], Tween[{0.8, 1.8}][t]]}}], {0, 2}];
play[scene[gradientImage, 2]]
```

### Boolean Operations

Two ellipses and the regions they make; each result flies to its corner:

```wl
e1 = Disk[{-4, -0.5}, {2, 2.5}]; e2 = Disk[{-2, -0.5}, {2, 2.5}];
region[r_] := BoundaryDiscretizeRegion[r]["BoundaryPolygons"];
ops = {{"Intersection", mc["Green"], region[RegionIntersection[e1, e2]], {5, 2.5}, 0.25},
    {"Union", mc["Orange"], region[RegionUnion[e1, e2]], {5, 0.1}, 0.3},
    {"Exclusion", mc["Yellow"], region[RegionSymmetricDifference[e1, e2]], {5, -2.5}, 0.3},
    {"Difference", mc["Pink"], region[RegionDifference[e1, e2]], {1.6, 0.1}, 0.3}};
boolean = Stage[Function[t, With[{fade = Tween[{0, 1}][t]}, {
    {Opacity[fade], FaceForm[Opacity[0.5, mc["Blue"]]], EdgeForm[{mc["Blue"], AbsoluteThickness[10]}], e1, FaceForm[Opacity[0.5, mc["Red"]]], EdgeForm[{mc["Red"], AbsoluteThickness[10]}], e2,
        White, Text[Style["Boolean Operation", Underlined], {-3, 2.6}]},
    Table[With[{k = i, op = ops[[i]]}, With[{u = Tween[{2 k - 1, 2 k}][t], c = RegionCentroid[RegionUnion @@ op[[3]]]},
        If[t < 2 k - 1, {}, {{FaceForm[Opacity[0.5, op[[2]]]], EdgeForm[{op[[2]], AbsoluteThickness[4]}],
            GeometricTransformation[op[[3]], TranslationTransform[u (op[[4]] - c)] @* ScalingTransform[{1, 1} (1 - u (1 - op[[5]])), c]]},
            {Opacity[Tween[{2 k, 2 k + 0.5}][t]], White, Text[Style[op[[1]], 35], op[[4]] + {0, 0.9 op[[5]] / 0.3}]}}]]], {i, 4}]}]], {0, 9}];
play[scene[boolean, 9]]
```

## Animations

### Point Moving on Shapes

A circle grows, a dot hops onto it, runs around it, then spins about a point:

```wl
pointOnShapes = Stage[Function[t, With[{p = Which[t < 1, {0, 0}, t < 2, Tween[{1, 2}, {{0, 0}, {1, 0}}][t],
        t < 4, {Cos[Pi (t - 2)], Sin[Pi (t - 2)]}, True, {2, 0} + RotationMatrix[2 Pi Tween[{4, 5.5}][t]] . {-1, 0}]},
    {{mc["Blue"], scaled[Circle[{0, 0}, 1], Tween[{0, 1}][t], {0, 0}]}, {White, Line[{{3, 0}, {5, 0}}]}, dot[p]}]], {0, 6.5}];
play[scene[pointOnShapes, 6.5]]
```

### Moving Around

A square shifted, recoloured, shrunk and turned, one move per second:

```wl
movingAround = Stage[Function[t, With[{c = Tween[{0, 1}, {{0, 0}, {-1, 0}}][t], s = Tween[{2, 3}, {1, 0.3}][t], a = Tween[{3, 4}, {0, 0.4}][t],
        col = Tween[{1, 2}, {mc["Blue"], mc["Orange"]}][t]},
    {EdgeForm[{mc["Blue"], AbsoluteThickness[4]}], FaceForm[col],
        GeometricTransformation[Rectangle[{-1, -1}, {1, 1}], TranslationTransform[c] @* RotationTransform[a] @* ScalingTransform[{s, s}]]}]], {0, 4}];
play[scene[movingAround, 4]]
```

### Moving Angle

An angle driven by a tracked value, its arc and its label following:

```wl
theta = Tween[{{1, 110}, {2, 40}, {3, 180}, {3.5, 180}, {4.5, 350}}];
movingAngle = Stage[Function[t, With[{th = theta[t] Degree, lab = Tween[{3, 3.5}, {White, mc["Red"]}][t]},
    {White, Line[{{-1, 0}, {1, 0}}], Line[{{-1, 0}, {-1, 0} + 2 {Cos[th], Sin[th]}}], Circle[{-1, 0}, 0.5, {0, th}],
        Text[Style[TraditionalForm[\[Theta]], 72, lab], {-1, 0} + 0.8 {Cos[th / 2], Sin[th / 2]}]}]], {0, 4.5}];
play[scene[movingAngle, 4.5]]
```

### Moving Dots

Two dots on two trackers, a line kept between them:

```wl
movingDots = Stage[Function[t, With[{d1 = {Tween[{0, 1}, {0, 5}][t], 0}, d2 = {0.58, Tween[{1, 2}, {0, 4}][t]}},
    {{mc["Red"], Line[{d1, d2}]}, dot[d1, mc["Blue"]], dot[d2, mc["Green"]]}]], {0, 3}];
play[scene[movingDots, 3]]
```

### Moving a Group to a Destination

A row of dots moved so that its red one lands on the yellow:

```wl
movingGroup = Stage[Function[t, With[{v = Tween[{0, 1}, {{0, 0}, {4, 3} - {1.2, 0}}][t]},
    {dot[{4, 3}, mc["Yellow"], 0.11], dot[# + v, White, 0.11] & /@ {{-1.6, 0}, {-0.2, 0}, {2.6, 0}}, dot[{1.2, 0} + v, mc["Red"], 0.11]}]], {0, 1.5}];
play[scene[movingGroup, 1.5]]
```

### Moving Frame Box

The product rule, written out; a box around one term moves to the other:

```wl
terms = {Row[{TraditionalForm[HoldForm[Dt[f[x] g[x], x]]], " ="}], TraditionalForm[HoldForm[f[x] Dt[g[x], x]]], "+", TraditionalForm[HoldForm[g[x] Dt[f[x], x]]]};
widths = (Rasterize[Style[#, 72, FontFamily -> "Source Sans 3"], "BoundingBox"][[1]] 128/9 / 1920) & /@ terms;
lefts = -Total[widths + 0.2] / 2 + Most[Accumulate[Prepend[widths + 0.2, 0]]];
box[i_] := {{lefts[[i]] - 0.1, -0.75}, {lefts[[i]] + widths[[i]] + 0.1, 0.75}};
frameBox = Stage[Function[t, {
    MapIndexed[{Opacity[Tween[{0.25 (#2[[1]] - 1), 0.25 (#2[[1]] - 1) + 0.5}][t]], White, Text[Style[#1, 72], {lefts[[#2[[1]]]], 0}, {-1, 0}]} &, terms],
    {FaceForm[], EdgeForm[{mc["Yellow"], AbsoluteThickness[4]}], mc["Yellow"],
        If[t < 3, PartialPath[Rectangle @@ box[2], Tween[{1, 2}][t]], Rectangle @@ Tween[{3, 4}, {box[2], box[4]}][t]]}}], {0, 5}];
play[scene[frameBox, 5]]
```

### Rotation Updater

A line turned forth for two seconds and back for two, as a function of time:

```wl
rotation = Stage[Function[t, With[{a = Which[t < 2, t, t < 4, 4 - t, True, 0]},
    {White, Line[{{0, 0}, {-1, 0}}], mc["Yellow"], Line[{{0, 0}, RotationMatrix[a] . {-1, 0}}]}]], {0, 4.5}];
play[scene[rotation, 4.5]]
```

### Point with Trace

A dot and the path it has drawn so far, which is just its position over all earlier times:

```wl
position[t_] := Which[t < 2, {1, 0} + RotationMatrix[Pi t / 2] . {-1, 0}, t < 3, {2, 0}, t < 4, {2, Tween[{3, 4}][t]}, True, {2 - Tween[{4, 5}][t], 1}];
trace = Stage[Function[t, {White, Line[position /@ Subdivide[0., t, Max[2, Ceiling[60 t]]]], dot[position[t]]}], {0, 6}];
play[scene[trace, 6]]
```

## Plotting

### Sine and Cosine

Two functions on axes with numbered, elongated ticks, drawn in:

```wl
axes1 = StageAxes[{-10, 10.3, 1}, {-1.5, 1.5, 1}, "Size" -> {10, 6}, "Color" -> mc["Green"], "Tips" -> False,
    "Numbers" -> {Range[-10, 10, 2], {}}, "LongTicks" -> {Range[-10, 10, 2], {}}];
sinCos = Stage[Function[t, With[{u = Tween[{0.3, 1.8}][t]}, {axes1["Primitives"], White, axes1["Labels"],
    {mc["Blue"], PartialPath[axes1["Graph", Sin], u]}, {mc["Red"], PartialPath[axes1["Graph", Cos], u]},
    {Opacity[Tween[{1.8, 2.3}][t]], Text[Style[TraditionalForm[Sin[x]], 60, mc["Blue"]], axes1[{-10, Sin[-10]}] + {0, 0.5}],
        Text[Style[TraditionalForm[Cos[x]], 60, mc["Red"]], axes1[{10.3, Cos[10.3]}] + {0.3, 0.3}, {-1, 0}],
        {mc["Yellow"], axes1["VerticalLine", {2 Pi, 1}]}, Text[Style[TraditionalForm[x == 2 Pi], 60], axes1[{2 Pi, 1}] + {0.5, 0.4}]}}]], {0, 3}];
play[scene[sinCos, 3]]
```

### Arg Min

A dot slides down a parabola to its minimum:

```wl
axes2 = StageAxes[{0, 10, 1}, {0, 100, 10}, "Tips" -> False];
argMin = Stage[Function[t, With[{x = Tween[{0, 1}, {0, 5}][t]}, {axes2["Primitives"], axes2["Labels", "x", "f(x)"],
    {mc["Maroon"], axes2["Graph", 2 (# - 5)^2 &]}, dot[axes2[{x, 2 (x - 5)^2}]]}]], {0, 2}];
play[scene[argMin, 2]]
```

### Area Under a Graph

Riemann rectangles, and the area between two curves:

```wl
axes3 = StageAxes[{0, 5, 1}, {0, 6, 1}, "Tips" -> False, "Numbers" -> {{2, 3}, {}}];
c1 = 4 # - #^2 &; c2 = 0.8 #^2 - 3 # + 4 &;
graphArea = Stage[Function[t, {axes3["Primitives"], axes3["Labels"], {mc["Blue"], axes3["Graph", c1, {0, 4}]}, {mc["GreenB"], axes3["Graph", c2, {0, 4}]},
    {mc["Yellow"], axes3["VerticalLine", {2, c1[2]}], axes3["VerticalLine", {3, c1[3]}]},
    {Opacity[0.5 Tween[{0, 1}][t]], mc["Blue"], EdgeForm[Black], axes3["Riemann", c1, {0.3, 0.6}, 0.03]},
    {Opacity[0.5 Tween[{0.5, 1.5}][t]], mc["Grey"], axes3["Area", c2, c1, {2, 3}]}}], {0, 2}];
play[scene[graphArea, 2]]
```

### A Rectangle Under a Hyperbola

A rectangle from the origin to a point on y = 25/x keeps its area as the point moves:

```wl
axes4 = StageAxes[{0, 10, 1}, {0, 10, 1}, "Size" -> {6, 6}, "Tips" -> False];
xt = Tween[{{1, 5}, {2, 10}, {3, 2.5}, {4, 5}}];
polygonOnAxes = Stage[Function[t, With[{x = xt[t]}, {axes4["Primitives"], {mc["YellowD"], axes4["Graph", 25 / # &, {2.5, 10}]},
    {FaceForm[Opacity[0.5 Tween[{0, 1}][t], mc["Blue"]]], EdgeForm[{Opacity[Tween[{0, 1}][t], mc["YellowB"]], AbsoluteThickness[1]}],
        Polygon[axes4[{{x, 25 / x}, {0, 25 / x}, {0, 0}, {x, 0}}]]}, dot[axes4[{x, 25 / x}]]}]], {0, 4}];
play[scene[polygonOnAxes, 4]]
```

### Heat Diagram

A line graph with its vertices, labelled axes, drawn in:

```wl
axes5 = StageAxes[{0, 40, 5}, {-8, 32, 5}, "Size" -> {9, 6}, "Tips" -> False, "Numbers" -> {Range[0, 35, 5], Range[-5, 30, 5]}];
heatPts = axes5[{{0, 20}, {8, 0}, {38, 0}, {39, -5}}];
heat = Stage[Function[t, {axes5["Primitives"], axes5["Labels", TraditionalForm[\[CapitalDelta]Q], "T[\[Degree]C]"],
    {mc["Yellow"], PartialPath[Line[heatPts], Tween[{0, 1.5}][t]], Disk[#, 0.08] & /@ Select[heatPts, Tween[{0, 1.5}][t] > 0 &]}}], {0, 2}];
play[scene[heat, 2]]
```

## Cameras

### Following the Graph

The camera zooms onto a dot, follows it along the sine curve, and pulls back. The stage's plot range is a function of time:

```wl
axes6 = StageAxes[{-1, 10, 1}, {-1, 10, 1}];
along[u_] := axes6[{3 Pi u, Sin[3 Pi u]}];
dotAt[t_] := along[Tween[{1, 2}, "Linear"][t]];
camera[t_] := With[{c = Which[t < 1, Tween[{0, 1}, {{0, 0}, along[0]}][t], t < 2, dotAt[t], True, Tween[{2, 3}, {along[1], {0, 0}}][t]],
        s = Which[t < 1, Tween[{0, 1}, {1, 0.5}][t], t < 2, 0.5, True, Tween[{2, 3}, {0.5, 1}][t]]},
    {c[[1]] + s {-64/9, 64/9}, c[[2]] + s {-4, 4}}];
following = Stage[Function[t, {axes6["Primitives"], {mc["Blue"], axes6["Graph", Sin, {0, 3 Pi}]}, dot[along[0]], dot[along[1]], dot[dotAt[t], mc["Orange"]]}], {0, 3},
    PlotRange -> camera];
play[scene[following, 3]]
```

### A Zoomed Camera

A second camera shows a small frame of the scene, magnified, in a display that pops out, stretches, grows and folds back. The display is a second Stage, placed in a canvas rectangle and looking through the frame:

```wl
zoomImage = Image[{{0, 100, 30, 200}, {255, 0, 5, 33}}, "Byte"];
base[t_] := {Inset[ImageResize[zoomImage, 400, Resampling -> "Nearest"], {0, 0}, Center, {14, 7}], dot[{-2, 2}]};
frameC = Tween[{{8, {-2, 2}}, {9, {-2, -0.5}}}]; frameS = Tween[{{4, {1.8, 0.3}}, {5, {0.9, 0.45}}}];
dispC = {64/9 - 3.2, 1.8}; dispS[t_] := Tween[{{4, {6, 1}}, {5, {3, 1.5}}, {6, {3, 1.5}}, {7, {6, 3}}}][t];
pop[t_] := Min[Tween[{1, 2}][t], 1 - Tween[{10, 11}][t]];
toCanvas[{x_, y_}] := {960 + x 1920 / (128/9), 540 - y 1080 / 8};
zoomed = {Stage[Function[t, {base[t], {FaceForm[], EdgeForm[{mc["Purple"], AbsoluteThickness[3], Opacity[1 - Tween[{11, 12}][t]]}],
        Rectangle[frameC[t] - frameS[t] / 2, frameC[t] + frameS[t] / 2]},
    {mc["Purple"], Opacity[Tween[{0, 1}][t] - Tween[{4, 5}][t]], Text[Style["Frame", 100], frameC[t] - {0, 0.8}]},
    {mc["Red"], Opacity[Tween[{2, 3}][t] - Tween[{4, 5}][t]], Text[Style["Zoomed camera", 100], dispC - {0, 1.2}]},
    {FaceForm[], EdgeForm[{mc["Red"], AbsoluteThickness[3]}], Opacity[pop[t] - Tween[{11, 12}][t]], With[{c = frameC[t] + pop[t] (dispC - frameC[t]), s = frameS[t] + pop[t] (dispS[t] - frameS[t])},
        Rectangle[c - s / 2, c + s / 2]]}}], {0, 13}],
    Stage[Function[t, base[t]], {1, 11}, "Screen" -> Function[t, With[{c = frameC[t] + pop[t] (dispC - frameC[t]), s = frameS[t] + pop[t] (dispS[t] - frameS[t])},
        Join[toCanvas[c + {-1, 1} s / 2], {s[[1]], s[[2]]} {1920 / (128/9), 1080 / 8}]]],
        PlotRange -> Function[t, Transpose[{frameC[t] - frameS[t] / 2, frameC[t] + frameS[t] / 2}]], Background -> Black]};
play[scene[zoomed, 13]]
```

### Text Fixed in the Frame

A 3D scene seen from above and at an angle, with text that stays put. A Stage can hold a 3D picture as an inset under 2D primitives. The camera is far away with a narrow, fixed angle, so the scale holds as it turns:

```wl
view[phi_, theta_] := Sequence[ViewPoint -> 50 {Sin[phi] Cos[theta], Sin[phi] Sin[theta], Cos[phi]}, ViewVertical -> {0, 0, 1}, ViewCenter -> {0.5, 0.5, 0.5},
    ViewAngle -> 2 ArcTan[0.62 / 50], Boxed -> False, Lighting -> "Neutral", Background -> None];
axes3D = {White, Arrowheads[0.02], Arrow[{{-6, 0, 0}, {6, 0, 0}}], Arrow[{{0, -5, 0}, {0, 5, 0}}], Arrow[{{0, 0, -4}, {0, 0, 4}}]};
in3D[g_] := Inset[g, {0, 0}, Center, {128/9, 8}];
fixedText = Stage[Function[t, {in3D[Graphics3D[axes3D, view[75 Degree, -45 Degree + 0.2 Tween[{0, 2}][t]], PlotRange -> {{-6, 6}, {-6, 6}, {-6, 6}}]],
    Text["This is a 3D text", {-64/9 + 0.5, 3.4}, {-1, 0}]}], {0, 2}];
play[scene[fixedText, 2]]
```

### A Light Source Below

A checkered sphere, lit from underneath:

```wl
sphere = ParametricPlot3D[1.5 {Cos[u] Cos[v], Cos[u] Sin[v], Sin[u]}, {u, -Pi/2, Pi/2}, {v, 0, 2 Pi}, Mesh -> {14, 31}, MeshStyle -> None,
    MeshShading -> {{mc["RedD"], mc["RedE"]}, {mc["RedE"], mc["RedD"]}}, PlotPoints -> 40, Axes -> False,
    Lighting -> {{"Directional", White, {{0, 0, -3}, {0, 0, 0}}}, {"Ambient", GrayLevel[0.35]}}];
lightBelow = Stage[Function[t, in3D[Show[Graphics3D[axes3D], sphere, view[75 Degree, 30 Degree + 0.3 Tween[{0, 2}][t]], PlotRange -> {{-6, 6}, {-6, 6}, {-6, 6}}]]], {0, 2}];
play[scene[lightBelow, 2]]
```

### An Orbiting Camera

The camera turns about the scene, then returns:

```wl
orbit = Stage[Function[t, With[{th = 30 Degree + If[t < 1, 0.1 t, 0.1 (1 - Tween[{1, 2}][t])]},
    in3D[Graphics3D[{axes3D, mc["Red"], AbsoluteThickness[4], Line[Table[{Cos[a], Sin[a], 0}, {a, 0, 2 Pi, Pi / 60}]]},
        view[75 Degree, th], PlotRange -> {{-6, 6}, {-6, 6}, {-6, 6}}]]]], {0, 3}];
play[scene[orbit, 3]]
```

### A Wobbling Camera

The camera circles in two angles at once, so the scene seems to sway:

```wl
illusion = Stage[Function[t, in3D[Graphics3D[{axes3D, mc["Red"], AbsoluteThickness[4], Line[Table[{Cos[a], Sin[a], 0}, {a, 0, 2 Pi, Pi / 60}]]},
    view[75 Degree + 0.2 Sin[2 t], 30 Degree + 0.3 Sin[2 t + Pi / 2] - 0.3], PlotRange -> {{-6, 6}, {-6, 6}, {-6, 6}}]]], {0, Pi}];
play[scene[illusion, Pi]]
```

### A Surface

A Gaussian bump, checkered and translucent:

```wl
gauss = ParametricPlot3D[{2 u, 2 v, 2 Exp[-(u^2 + v^2) / (2 0.4^2)]}, {u, -2, 2}, {v, -2, 2}, Mesh -> {23, 23}, MeshStyle -> mc["Green"],
    MeshShading -> {{Opacity[0.5, mc["Orange"]], Opacity[0.5, mc["Blue"]]}, {Opacity[0.5, mc["Blue"]], Opacity[0.5, mc["Orange"]]}}, PlotPoints -> 48, Axes -> False, Lighting -> "Neutral"];
surface = Stage[Function[t, in3D[Show[Graphics3D[axes3D], gauss, view[75 Degree, -30 Degree + 0.4 Tween[{0, 3}][t]], PlotRange -> {{-6, 6}, {-6, 6}, {-6, 6}}]]], {0, 3}];
play[scene[surface, 3]]
```

## Advanced

### The Opening

A title and a formula, a title moved to the corner, a grid drawn in and bent by a non-linear function:

```wl
basel = TraditionalForm[HoldForm[Sum[1/n^2, {n, 1, Infinity}] == Pi^2/6]];
gridLines = Join[Table[{x, y}, {x, -8, 8}, {y, Subdivide[-5., 5., 60]}], Table[{x, y}, {y, -5, 5}, {x, Subdivide[-8., 8., 90]}]];
bend[p_, u_] := p + u {Sin[p[[2]]], Sin[p[[1]]]};
titleAt[t_] := {Tween[{2, 3}, {{0, 0.8}, {-4.7, 3.4}}][t], Tween[{2, 3}, {1, 0.75}][t]};
opening = Stage[Function[t, With[{g = Tween[{5, 8}][t], k = Tween[{4, 5}][t]}, {
    {Opacity[k], MapIndexed[{If[#2[[1]] <= 17 && #1[[1, 1]] == 0 || #2[[1]] > 17 && #1[[1, 2]] == 0, White, mc["BlueD"]], AbsoluteThickness[2],
        PartialPath[Line[bend[#, g] & /@ #1], Clip[3 k - 2 #2[[1]] / Length[gridLines], {0, 1}]]} &, gridLines]},
    {White, Opacity[1 - Tween[{4, 4.5}][t]], Text[Style["This is some typesetting", 72 titleAt[t][[2]]], titleAt[t][[1]]]},
    {White, Opacity[Tween[{0, 1}][t] - Tween[{2, 3}][t]], Text[Style[basel, 72], {0, -0.6 - 0.5 (1 - Tween[{0, 1}][t]) - Tween[{2, 3}][t]}]},
    {White, Opacity[Tween[{4, 4.5}][t] - Tween[{9, 9.5}][t]], Text[Style["This is a grid", 108], {-4.2, 3.4 - 0.4 (1 - Tween[{4, 4.5}][t])}]},
    {White, Opacity[Tween[{9, 9.5}][t]], Text[Style["That was a non-linear function\napplied to the grid", 72], {-6.7, 3.4}, {-1, 0}]}}]], {0, 10.5}];
play[scene[opening, 10.5]]
```

### The Sine Curve from a Unit Circle

A dot goes round the circle; its height, carried across, draws the sine curve:

```wl
angleAt[t_] := 2 Pi 0.25 t;
dotPos[t_] := {-4, 0} + {Cos[angleAt[t]], Sin[angleAt[t]]};
sineCircle = Stage[Function[t, With[{p = dotPos[t], x = -3 + t}, {White, Line[{{-6, 0}, {6, 0}}], Line[{{-4, -2}, {-4, 2}}],
    Text[Style[TraditionalForm[#[[2]]], 72], {#[[1]], -0.45}] & /@ {{-1, \[Pi]}, {1, 2 \[Pi]}, {3, 3 \[Pi]}, {5, 4 \[Pi]}},
    {mc["Red"], Circle[{-4, 0}, 1]}, {mc["Blue"], Line[{{-4, 0}, p}]}, {mc["YellowA"], AbsoluteThickness[2], Line[{p, {x, p[[2]]}}]},
    {mc["YellowD"], Line[Table[{-3 + s, Sin[angleAt[s]]}, {s, Subdivide[0., t, Max[2, Ceiling[40 t]]]}]]}, dot[p, mc["Yellow"]]}]], {0, 8.5}];
play[scene[sineCircle, 8.5]]
```
