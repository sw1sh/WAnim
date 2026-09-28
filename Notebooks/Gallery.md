---
Template: ComputationalEssay
Name: "WAnim Gallery"
Author: Nikolay Murzin
Date: 2026
Description: "The Manim example gallery, scene by scene, in the Wolfram Language with WAnim"
Abstract: "Manim's gallery is the standard tour of what an animation library can do: shapes and braces, value trackers and updaters, plots, moving and zoomed cameras, 3D scenes. Here is every one of its scenes written with WAnim, following Manim's code. Mobjects are AnimatedObjects, TeX is typeset with MaTeX, and self.play is an object playing an effect: Creation (Write, Create, FadeIn, GrowFromCenter), Transform, Scale, Rotate, Translate. Axes are ordinary Plots. A scene is a Timeline whose picture is a Stage: a function of time, or a list of objects playing on its clock. A ValueTracker is a Tween, and where Manim needs updaters the picture is simply computed from the time."
Keywords: [WAnim, Manim, animation, gallery, AnimatedObject, MaTeX, Timeline, Stage, Tween]
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

A scene of a given length on black; played as an animated image, or its last frame for Manim's still scenes; and Manim's dot:

```wl
scene[layers_, dur_, bg_ : Black] := Timeline[Flatten[{layers}], "Duration" -> dur, Background -> bg];
play[tl_] := tl["AnimatedImage", "FrameRate" -> 15, ImageSize -> 480];
still[tl_] := tl["Image", tl["Duration"] - 10^-3, ImageSize -> 480];
dot[p_, col_ : White, r_ : 0.08] := {col, Disk[p, r]};
```

Plots styled like Manim's axes, for insetting on a stage (Plot holds its arguments, so the options go in evaluated, last, after a plot's own):

```wl
manimPlot = Sequence[AxesStyle -> Directive[White, AbsoluteThickness[2]], TicksStyle -> Directive[White, FontSize -> 30], LabelStyle -> Directive[White, FontSize -> 40], Background -> None,
    PlotRangePadding -> None, AspectRatio -> Full];
```

## Basic Concepts

### Manim's Logo, as a W

A blackboard W over a triangle, a square and a circle, the group moved to the centre:

```wl
logo = AnimatedObject[{AnimatedObject[RegularPolygon[{1, 0}, {1, Pi/2}, 3], RGBColor["#e07a5f"]], AnimatedObject[Rectangle[{-1, 0}, {1, 2}], RGBColor["#525893"]],
    AnimatedObject[Disk[{-1, 0}], RGBColor["#87c2a5"]], AnimatedObject["\\mathbb{W}", RGBColor["#343434"]]["Apply", "Scale", 3.5]["Apply", "Translate", 2.25 Left + 1.5 Up]}]["Centralize"];
still[scene[Stage[{logo}, {0, 1}], 1, RGBColor["#ece6e2"]]]
```

### Brace Annotation

A line between two dots, braced below and across:

```wl
line = AnimatedObject[Line[{{-2, -1}, {2, 1}}], mc["Orange"]];
braces = Stage[{line, dot[{-2, -1}], dot[{2, 1}],
    Brace[line, White, AnimatedObject["\\text{Horizontal distance}", White]["Apply", "Scale", 0.3]],
    Brace[line, White, AnimatedObject["x - x_1", White]["Apply", "Scale", 0.3], "Direction" -> RotationTransform[Pi/2][{4, 2}]]}, {0, 1}];
still[scene[braces, 1]]
```

### Vector Arrow

A vector on the number plane:

```wl
plane = {{mc["BlueD"], AbsoluteThickness[2], Table[Line[{{x, -4}, {x, 4}}], {x, -7, 7}], Table[Line[{{-7.2, y}, {7.2, y}}], {y, -4, 4}]},
    {White, AbsoluteThickness[2], Line[{{-7.2, 0}, {7.2, 0}}], Line[{{0, -4}, {0, 4}}]}};
vectorArrow = Stage[{plane, dot[{0, 0}], {White, Arrowheads[0.025], Arrow[{{0, 0}, {2, 2}}]}, Text["(0, 0)", {0, -0.45}], Text["(2, 2)", {2.25, 2}, {-1, 0}]}, {0, 1}];
still[scene[vectorArrow, 1]]
```

### Gradient Image from an Array

An image made from an array of numbers, framed:

```wl
gradientImage = Stage[{Inset[Image[Table[i / 255., {256}, {i, 0, 255}]], {0, 0}, Center, 4],
    {FaceForm[], EdgeForm[{mc["Green"], AbsoluteThickness[4]}], Rectangle[{-2, -2}, {2, 2}]}}, {0, 1}];
still[scene[gradientImage, 1]]
```

### Boolean Operations

Two ellipses fade in; each boolean region then shrinks off to its corner, one per second, and is named. A scene's later animations are layers that start later:

```wl
e1 = Disk[{-4, -0.5}, {2, 2.5}]; e2 = Disk[{-2, -0.5}, {2, 2.5}];
regionObject[r_, col_] := AnimatedObject[BoundaryDiscretizeRegion[r]["BoundaryPolygons"], {FaceForm[Opacity[0.5, col]], EdgeForm[{col, AbsoluteThickness[4]}]}];
ops = {{"Intersection", RegionIntersection, mc["Green"], {5, 2.5}, 0.25}, {"Union", RegionUnion, mc["Orange"], {5, 0.1}, 0.3},
    {"Exclusion", RegionSymmetricDifference, mc["Yellow"], {5, -2.5}, 0.3}, {"Difference", RegionDifference, mc["Pink"], {1.6, 0.1}, 0.3}};
boolean = {Stage[{AnimatedObject[{AnimatedObject[e1, {FaceForm[Opacity[0.5, mc["Blue"]]], EdgeForm[{mc["Blue"], AbsoluteThickness[10]}]}],
        AnimatedObject[e2, {FaceForm[Opacity[0.5, mc["Red"]]], EdgeForm[{mc["Red"], AbsoluteThickness[10]}]}],
        AnimatedObject["\\underline{\\text{Boolean Operation}}", White]["Apply", "Scale", 0.5]["Apply", "Translate", {-3, 2.6}]}]["Play", "Creation", Method -> "FadeIn"]}, {0, 9}],
    MapIndexed[With[{k = 2 #2[[1]] - 1, obj = regionObject[#1[[2]][e1, e2], #1[[3]]]},
        {Stage[{obj["Play", AnimationEffect[{AnimationEffect["Scale", #1[[5]]], AnimationEffect["Translate", #1[[4]] - obj["Center"]]}]]}, {k, 9}],
         Stage[{AnimatedObject["\\text{" <> #1[[1]] <> "}", White]["Apply", "Scale", 0.25]["Apply", "Translate", #1[[4]] + {0, 0.9 #1[[5]] / 0.3}]["Play", "Creation", Method -> "FadeIn"]}, {k + 1, 9}]}] &, ops]};
play[scene[boolean, 9]]
```

## Animations

### Point Moving on Shapes

A circle grows from its centre; a dot moves onto it, runs around it, then spins about a point. Running along a path is an effect written as a function of the object and time:

```wl
alongCircle = AnimationEffect[#Object["TransformPrimitives", TranslationTransform[{Cos[Pi #t], Sin[Pi #t]} - {1, 0}]] &, "Duration" -> 2];
pointOnShapes = Stage[{AnimatedObject[Circle[], mc["Blue"]]["Play", "Creation", Method -> "GrowFromCenter"], {White, Line[{{3, 0}, {5, 0}}]},
    AnimatedObject[Disk[{0, 0}, 0.08], White]["Wait"]["Play", "Translate", Right]["Play", alongCircle]["Play", "Rotate", 2 Pi, {2, 0}, "Duration" -> 1.5, "Rate" -> "Linear"]}, {0, 6.5}];
play[scene[pointOnShapes, 6.5]]
```

### Moving Around

A square shifted, recoloured, shrunk and turned, one move per second; recolouring is an effect on the object's directive:

```wl
recolour[a_, b_] := AnimationEffect[#Object["SetDirective", Blend[{a, b}, Easing["Smooth"][#t]]] &];
movingAround = Stage[{AnimatedObject[Rectangle[{-1, -1}, {1, 1}], mc["Blue"]]["Play", "Translate", Left]["Play", recolour[mc["Blue"], mc["Orange"]]]["Play", "Scale", 0.3]["Play", "Rotate", 0.4]}, {0, 4}];
play[scene[movingAround, 4]]
```

### Moving Angle

An angle driven by a tracked value, its arc and its label following. A ValueTracker and its animations are one Tween through keyframes:

```wl
theta = Tween[{{1, 110}, {2, 40}, {3, 180}, {3.5, 180}, {4.5, 350}}];
thetaLabel = AnimatedObject["\\theta", White]["Apply", "Scale", 0.4];
movingAngle = Stage[Function[t, With[{th = theta[t] Degree}, {White, Line[{{-1, 0}, {1, 0}}], Line[{{-1, 0}, {-1, 0} + 2 {Cos[th], Sin[th]}}], Circle[{-1, 0}, 0.5, {0, th}],
    thetaLabel["SetDirective", Tween[{3, 3.5}, {White, mc["Red"]}][t]]["TransformPrimitives", TranslationTransform[{-1, 0} + 0.8 {Cos[th / 2], Sin[th / 2]}]]}]], {0, 4.5}];
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
group = AnimatedObject[{dot[{-1.6, 0}, White, 0.11], dot[{-0.2, 0}, White, 0.11], dot[{1.2, 0}, mc["Red"], 0.11], dot[{2.6, 0}, White, 0.11]}];
movingGroup = Stage[{dot[{4, 3}, mc["Yellow"], 0.11], group["Play", "Translate", {4, 3} - {1.2, 0}]["Wait", "Duration" -> 0.5]}, {0, 1.5}];
play[scene[movingGroup, 1.5]]
```

### Moving Frame Box

The product rule written out; a box drawn round one term becomes a box round the other. The formula is typeset once, in parts, and each box is taken from its part:

```wl
text = AnimatedObject[{"\\frac{d}{dx}f(x)g(x)=", "f(x)\\frac{d}{dx}g(x)", "+", "g(x)\\frac{d}{dx}f(x)"}];
frameBox = Stage[{text["Play", "Creation", Method -> "Write"],
    text["Part", 2]["SurroundingRectangle"]["Play", "Creation", Method -> "Create", "Delay" -> 1]["Wait"]["Play", "Transform", text["Part", 4]["SurroundingRectangle"]]}, {0, 5}];
play[scene[frameBox, 5]]
```

### Rotation Updater

A line turned forth for two seconds and back for two:

```wl
rotation = Stage[{AnimatedObject[Line[{{0, 0}, {-1, 0}}], White], AnimatedObject[Line[{{0, 0}, {-1, 0}}], mc["Yellow"]]["Play", "Rotate", 2, {0, 0}, "Duration" -> 2, "Rate" -> "Linear"][
    "Play", "Rotate", -2, {0, 0}, "Duration" -> 2, "Rate" -> "Linear"]}, {0, 4.5}];
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

Two functions on axes with numbered ticks, a vertical line at 2π, and labels:

```wl
sinCos = Stage[{Inset[Plot[{Sin[x], Cos[x]}, {x, -10, 10.3}, PlotStyle -> {Directive[mc["Blue"], AbsoluteThickness[4]], Directive[mc["Red"], AbsoluteThickness[4]]},
    Ticks -> {Range[-10, 10, 2], {-1, 1}}, AxesLabel -> {"x", "y"}, PlotRange -> {-1.5, 1.5}, AxesStyle -> Directive[mc["Green"], AbsoluteThickness[2]],
    Epilog -> {mc["Yellow"], AbsoluteThickness[4], Line[{{2 Pi, 0}, {2 Pi, 1}}],
        Text[Style[TraditionalForm[x == 2 \[Pi]], White, 48], {2 Pi, 1.25}], Text[Style[TraditionalForm[Sin[x]], mc["Blue"], 48], {-10, 0.8}, {-1, 0}],
        Text[Style[TraditionalForm[Cos[x]], mc["Red"], 48], {10.3, -0.6}, {1, 0}]}, Evaluate[manimPlot]], {0, 0}, Center, {10, 6}]}, {0, 1}];
still[scene[sinCos, 1]]
```

### Arg Min

A dot slides down a parabola to its minimum:

```wl
argMin = Stage[Function[t, With[{x = Tween[{0, 1}, {0, 5}][t]},
    Inset[Plot[2 (u - 5)^2, {u, 0, 10}, PlotStyle -> Directive[mc["Maroon"], AbsoluteThickness[4]], AxesLabel -> {"x", "f(x)"}, Ticks -> None,
        Epilog -> {White, AbsolutePointSize[16], Point[{x, 2 (x - 5)^2}]}, Evaluate[manimPlot]], {0, 0}, Center, {12, 6}]]], {0, 2}];
play[scene[argMin, 2]]
```

### Area Under a Graph

Riemann rectangles, and the area between two curves:

```wl
c1 = 4 # - #^2 &; c2 = 0.8 #^2 - 3 # + 4 &;
graphArea = Stage[{Inset[Plot[{c1[x], c2[x]}, {x, 0, 4}, PlotStyle -> {Directive[mc["Blue"], AbsoluteThickness[4]], Directive[mc["GreenB"], AbsoluteThickness[4]]},
    PlotRange -> {{0, 5}, {0, 6}}, Ticks -> {{2, 3}, None}, AxesLabel -> {"x", "y"},
    Epilog -> {{mc["Yellow"], AbsoluteThickness[4], Line[{{2, 0}, {2, c1[2]}}], Line[{{3, 0}, {3, c1[3]}}]},
        {EdgeForm[Black], FaceForm[Opacity[0.5, mc["Blue"]]], Table[Rectangle[{x, 0}, {x + 0.03, c1[x]}], {x, 0.3, 0.57, 0.03}]},
        {FaceForm[Opacity[0.5, mc["Grey"]]], Polygon[Join[Table[{x, c2[x]}, {x, 2, 3, 0.02}], Table[{x, c1[x]}, {x, 3, 2, -0.02}]]]}}, Evaluate[manimPlot]], {0, 0}, Center, {12, 6}]}, {0, 1}];
still[scene[graphArea, 1]]
```

### A Rectangle Under a Hyperbola

A rectangle from the origin to a point on y = 25/x keeps its area as the point moves; it is drawn in first:

```wl
xt = Tween[{{1, 5}, {2, 10}, {3, 2.5}, {4, 5}}];
polygonOnAxes = Stage[Function[t, With[{x = xt[t]}, Inset[Plot[25 / u, {u, 2.5, 10}, PlotStyle -> Directive[mc["YellowD"], AbsoluteThickness[4]], PlotRange -> {{0, 10}, {0, 10}},
    Ticks -> None, Epilog -> {{FaceForm[Opacity[0.5 Tween[{0, 1}][t], mc["Blue"]]], EdgeForm[], Rectangle[{0, 0}, {x, 25 / x}]},
        {mc["YellowB"], AbsoluteThickness[1], PartialPath[Rectangle[{0, 0}, {x, 25 / x}], Tween[{0, 1}][t]]}, {White, AbsolutePointSize[16], Point[{x, 25 / x}]}}, Evaluate[manimPlot]],
    {0, 0}, Center, {6, 6}]]], {0, 4}];
play[scene[polygonOnAxes, 4]]
```

### Heat Diagram

A line graph with its vertices, labelled axes:

```wl
heat = Stage[{Inset[ListLinePlot[{{0, 20}, {8, 0}, {38, 0}, {39, -5}}, Mesh -> All, MeshStyle -> AbsolutePointSize[12], PlotStyle -> Directive[mc["Yellow"], AbsoluteThickness[4]],
    PlotRange -> {{0, 40}, {-8, 32}}, Ticks -> {Range[0, 35, 5], Range[-5, 30, 5]}, AxesLabel -> {"\[CapitalDelta]Q", "T[\[Degree]C]"}, Evaluate[manimPlot]], {0, 0}, Center, {9, 6}]}, {0, 1}];
still[scene[heat, 1]]
```

## Cameras

### Following the Graph

The camera zooms onto a dot, follows it along the sine curve, and pulls back; the stage's plot range is a function of time. The plot is inset at a known place, so a data point's place on the stage is a rescaling:

```wl
onStage[{x_, y_}] := ({x, y} - {4.5, 4.5}) {12, 6} / 11;
dotAt[t_] := With[{u = 3 Pi Tween[{1, 2}, "Linear"][t]}, {u, Sin[u]}];
camera[t_] := With[{c = Which[t < 1, Tween[{0, 1}, {{0, 0}, onStage[{0, 0}]}][t], t < 2, onStage[dotAt[t]], True, Tween[{2, 3}, {onStage[dotAt[2]], {0, 0}}][t]],
        s = Which[t < 1, Tween[{0, 1}, {1, 0.5}][t], t < 2, 0.5, True, Tween[{2, 3}, {0.5, 1}][t]]},
    {c[[1]] + s {-64/9, 64/9}, c[[2]] + s {-4, 4}}];
following = Stage[Function[t, Inset[Plot[Sin[x], {x, 0, 3 Pi}, PlotStyle -> Directive[mc["Blue"], AbsoluteThickness[4]], PlotRange -> {{-1, 10}, {-1, 10}}, Ticks -> None,
    Epilog -> {White, AbsolutePointSize[16], Point[{{0, 0}, {3 Pi, 0}}], mc["Orange"], Point[dotAt[t]]}, Evaluate[manimPlot]], {0, 0}, Center, {12, 6}]], {0, 3}, PlotRange -> camera];
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

3D axes seen from above and at an angle, with text that stays put: a Stage holds the 3D picture as an inset under 2D primitives. The camera is far away with a narrow, fixed angle, so the scale holds as it turns:

```wl
view[phi_, theta_] := Sequence[ViewPoint -> 50 {Sin[phi] Cos[theta], Sin[phi] Sin[theta], Cos[phi]}, ViewVertical -> {0, 0, 1}, ViewCenter -> {0.5, 0.5, 0.5},
    ViewAngle -> 2 ArcTan[0.62 / 50], Boxed -> False, Lighting -> "Neutral", Background -> None, PlotRange -> {{-6, 6}, {-6, 6}, {-6, 6}}];
axes3D = {White, Arrowheads[0.02], Arrow[{{-6, 0, 0}, {6, 0, 0}}], Arrow[{{0, -5, 0}, {0, 5, 0}}], Arrow[{{0, 0, -4}, {0, 0, 4}}]};
in3D[g_] := Inset[g, {0, 0}, Center, {128/9, 8}];
still[scene[Stage[{in3D[Graphics3D[axes3D, view[75 Degree, -45 Degree]]], Text["This is a 3D text", {-64/9 + 0.5, 3.4}, {-1, 0}]}, {0, 1}], 1]]
```

### A Light Source Below

A checkered sphere, lit from underneath:

```wl
sphere = ParametricPlot3D[1.5 {Cos[u] Cos[v], Cos[u] Sin[v], Sin[u]}, {u, -Pi/2, Pi/2}, {v, 0, 2 Pi}, Mesh -> {14, 31}, MeshStyle -> None,
    MeshShading -> {{mc["RedD"], mc["RedE"]}, {mc["RedE"], mc["RedD"]}}, PlotPoints -> 40, Axes -> False,
    Lighting -> {{"Directional", White, {{0, 0, -3}, {0, 0, 0}}}, {"Ambient", GrayLevel[0.35]}}];
still[scene[Stage[{in3D[Show[Graphics3D[axes3D], sphere, view[75 Degree, 30 Degree]]]}, {0, 1}], 1]]
```

### An Orbiting Camera

The camera turns about the scene, then returns:

```wl
circle3D = {mc["Red"], AbsoluteThickness[4], Line[Table[{Cos[a], Sin[a], 0}, {a, 0, 2 Pi, Pi / 60}]]};
orbit = Stage[Function[t, in3D[Graphics3D[{axes3D, circle3D}, view[75 Degree, 30 Degree + If[t < 1, 0.1 t, 0.1 (1 - Tween[{1, 2}][t])]]]]], {0, 3}];
play[scene[orbit, 3]]
```

### A Wobbling Camera

The camera circles in two angles at once, so the scene seems to sway:

```wl
illusion = Stage[Function[t, in3D[Graphics3D[{axes3D, circle3D}, view[75 Degree + 0.2 Sin[2 t], 30 Degree + 0.3 Sin[2 t + Pi / 2] - 0.3]]]], {0, Pi / 2}];
play[scene[illusion, Pi / 2]]
```

### A Surface

A Gaussian bump, checkered and translucent:

```wl
gauss = ParametricPlot3D[{2 u, 2 v, 2 Exp[-(u^2 + v^2) / (2 0.4^2)]}, {u, -2, 2}, {v, -2, 2}, Mesh -> {23, 23}, MeshStyle -> mc["Green"],
    MeshShading -> {{Opacity[0.5, mc["Orange"]], Opacity[0.5, mc["Blue"]]}, {Opacity[0.5, mc["Blue"]], Opacity[0.5, mc["Orange"]]}}, PlotPoints -> 48, Axes -> False, Lighting -> "Neutral"];
still[scene[Stage[{in3D[Show[Graphics3D[axes3D], gauss, view[75 Degree, -30 Degree]]]}, {0, 1}], 1]]
```

## Advanced

### The Opening

A title written as the formula fades in; the title moves to the corner as the formula's terms drop away one after another; a grid is drawn in, line by line, and bent by a non-linear function:

```wl
title = AnimatedObject["\\text{This is some \\LaTeX}", White]["Apply", "Scale", 0.6]["Apply", "Translate", {0, 0.9}];
basel = AnimatedObject[{"\\sum_{n=1}^\\infty", "\\frac{1}{n^2}", "=", "\\frac{\\pi^2}{6}"}]["Apply", "Translate", {0, -0.6}];
corner = AnimatedObject["\\text{That was a transform}", White]["Apply", "Scale", 0.6]["Apply", "Translate", {-4, 3.4}];
gridLines = Join[Table[Line[Table[{x, y}, {y, Subdivide[-5., 5., 60]}]], {x, -8, 8}], Table[Line[Table[{x, y}, {x, Subdivide[-8., 8., 90]}]], {y, -5, 5}]];
bend = AnimationEffect[Function[e, With[{u = Easing["Smooth"][e["t"] / 3]},
    e["Object"]["SetPrimitives", e["Object"]["Primitives"] /. Line[pts_] :> Line[Function[p, p + u {Sin[p[[2]]], Sin[p[[1]]]}] /@ pts]]]], "Duration" -> 3];
opening = {
    Stage[{title["Play", "Creation", Method -> "Write"]["Wait"]["Play", "Creation", Method -> "FadeIn", "Reverse" -> True]}, {0, 3}],
    Stage[{basel["Play", "Creation", Method -> "FadeIn"]["Wait"]["Play", "Creation", Method -> "FadeIn", "LagRatio" -> 0.3, "Reverse" -> True]}, {0, 3}],
    Stage[{corner["Play", "Creation", Method -> "FadeIn"]["Wait"]["Play", "Creation", Method -> "FadeIn", "Reverse" -> True]}, {2, 5}],
    Stage[{AnimatedObject[gridLines, Directive[mc["BlueD"], AbsoluteThickness[2]]]["Play", "Creation", Method -> "Create", "LagRatio" -> 0.1, "Duration" -> 3]["Wait"]["Play", bend]},
        {4, 12.5}],
    Stage[{AnimatedObject["\\text{This is a grid}", White]["Apply", "Scale", 0.8]["Apply", "Translate", {-4, 3.4}]["Play", "Creation", Method -> "FadeIn"]["Wait", "Duration" -> 6][
        "Play", "Creation", Method -> "FadeIn", "Reverse" -> True]}, {4, 12}],
    Stage[{AnimatedObject["\\text{That was a non-linear function applied to the grid}", White]["Apply", "Scale", 0.45]["Apply", "Translate", {-2.5, 3.4}][
        "Play", "Creation", Method -> "FadeIn"]}, {11, 12.5}]};
play[scene[opening, 12.5]]
```

### The Sine Curve from a Unit Circle

A dot goes round the circle; its height, carried across, draws the sine curve:

```wl
angleAt[t_] := 2 Pi 0.25 t;
dotPos[t_] := {-4, 0} + {Cos[angleAt[t]], Sin[angleAt[t]]};
piLabels = MapThread[AnimatedObject[#1, White]["Apply", "Scale", 0.4]["Apply", "Translate", {#2, -0.4}] &, {{"\\pi", "2\\pi", "3\\pi", "4\\pi"}, {-1, 1, 3, 5}}];
sineCircle = Stage[Function[t, With[{p = dotPos[t], x = -3 + t}, {White, Line[{{-6, 0}, {6, 0}}], Line[{{-4, -2}, {-4, 2}}], piLabels,
    {mc["Red"], Circle[{-4, 0}, 1]}, {mc["Blue"], Line[{{-4, 0}, p}]}, {mc["YellowA"], AbsoluteThickness[2], Line[{p, {x, p[[2]]}}]},
    {mc["YellowD"], Line[Table[{-3 + s, Sin[angleAt[s]]}, {s, Subdivide[0., t, Max[2, Ceiling[40 t]]]}]]}, dot[p, mc["Yellow"]]}]], {0, 8.5}];
play[scene[sineCircle, 8.5]]
```
