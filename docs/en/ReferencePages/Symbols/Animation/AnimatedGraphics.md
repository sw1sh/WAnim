---
Template: Symbol
Name: AnimatedGraphics
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/AnimatedGraphics
Keywords: [animation, film, scene, Manim, mobject, timeline, layers, video, soundtrack, motion graphics]
SeeAlso: [AnimationEffect, Backdrop, Tween, Track, TrackPulse, Video, AnimatedImage, Graphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[AnimatedGraphics]()[{*content*_1, *content*_2, …}]</code> is graphics with a time axis: the content drawn at every moment, in order.

<code>[AnimatedGraphics]()[*content*, *directive*]</code> draws the content in a directive, as a Manim mobject.

<code>[AnimatedGraphics]()["*tex*"]</code> typesets TeX with MaTeX; <code>[AnimatedGraphics]()[{"*tex*_1", "*tex*_2", …}]</code> typesets the parts together, each one <code>*g*["Part", *i*]</code>.

<code>*g*[*t*]</code> is the frame at time *t*, a [Graphics]().

## Details & Options

- Content can be:
  - graphics primitives and directives, drawn at all times;
  - <code>{$t_0$, $t_1$} -> *x*</code>, drawn from $t_0$ until $t_1$; a nested AnimatedGraphics under a span runs on a clock of its own that starts at $t_0$;
  - a [Function]() of time giving any of these;
  - the elements that creation tools return ([Typewriter](), [TitleCard](), [NotebookSession](), [Spikey](), …), themselves AnimatedGraphics;
  - canvas primitives ([CanvasText](), [CanvasRectangle](), …), drawn in pixels with $y$ down on a canvas of "CanvasSize";
  - a [Graphics3D](), which fills the frame;
  - a [Track]() or an [Audio](), the sound.
- Time is in cycles. "CyclesPerSecond" converts it to seconds for sound and video: 1/2 for bars at 120 BPM.
- The frame shows [PlotRange](). `Automatic` is the canvas when there are canvas primitives, otherwise the bounds of the content. It may be a function of time, a camera that pans and zooms.
- A nested AnimatedGraphics with a [PlotRange]() or a "Screen" of its own is drawn into its screen: a canvas rectangle {x, y, w, h} of the enclosing frame, the whole frame by default. The screen may also be a function of time.
- Sizes are pixels of the canvas and scale with it: `FontSize -> n`, <code>[Style]()[*s*, *n*]</code>, <code>[AbsoluteThickness]()[*n*]</code>, <code>[AbsolutePointSize]()[*n*]</code>. An [Inset]() of a [Graphics]() takes them relative to its own width.
- String-named options in [BaseStyle](), such as `"Pulse" -> track`, pass to every element inside that does not set them itself.
- [PlotTheme]() sets the look a scene takes when it says nothing: "Manim" (black, white ink, Manim's colours), "Paper" (warm paper, dark ink) or "Night". A plot inset in the scene is drawn in it: its default colours become the theme's, its axes, ticks and labels take the theme's ink unless it sets them, and it fills its inset. Each is a [PlotTheme]() for any plot too.
- Effects:
  - <code>*g*["Play", *effect*]</code> plays an [AnimationEffect]() after the effects before it; <code>*g*["Play", "*name*", *args*]</code> names one.
  - <code>*g*["Wait", "Duration" -> *d*]</code> holds.
  - <code>*g*["Apply", "*name*", *args*]</code> applies the finished effect at once.
- Geometry: "Bounds", "Center", "Corners", "Width" and "Height" measure the content at time 0. "Centralize", "SurroundingRectangle", "SetPrimitives", "MapPrimitives", "SetDirective" and "TransformPrimitives" give changed copies.
- Rendering:
  - <code>[Export]()["*file*.mp4", *g*]</code> renders frames in parallel and encodes them with ffmpeg, the sound included; a ".gif" is an [AnimatedImage]().
  - <code>[Video]()[*g*]</code> renders to a temporary file.
  - <code>[AnimatedImage]()[*g*]</code> gives a small looping preview.
  - <code>[Audio]()[*g*]</code> gives the sound alone.
  - <code>*g*["Dynamic"]</code> is a live player, clocked by its sound.
- "Duration" is the latest span end, or the total length of the effects; the option sets it.

| Option | Default | Description |
| --- | --- | --- |
| PlotRange | Automatic | the coordinates the frame shows |
| "CanvasSize" | {1920, 1080} | canvas size in pixels |
| "Screen" | Automatic | where a nested one is drawn, {x, y, w, h} in the parent's canvas |
| PlotTheme | Automatic | "Manim", "Paper" or "Night": background, ink and plot styles; `Automatic` is the enclosing one's, else "Manim" |
| Background | Automatic | the colour behind everything; `Automatic` is the theme's |
| BaseStyle | white Source Sans 3 at 72 | text style, and options passed to the elements |
| "CyclesPerSecond" | 1 | tempo: cycles per second of sound and video |
| FrameRate | 60 | frames per second for video |
| "Foley" | False | whether typing and evaluation make their sounds |
| "Duration" | Automatic | length in cycles |

## Basic Examples

A formula written in:

```wl
AnimatedGraphics[{"e^{i\\pi}", "+ 1 = 0"}]["Play", "Creation", Method -> "Write"]
```

<!-- => an AnimatedGraphics summary box, duration 1 -->

---

Its frame half way:

```wl
AnimatedGraphics[{"e^{i\\pi}", "+ 1 = 0"}]["Play", "Creation", Method -> "Write"][0.5, ImageSize -> 480]
```

<!-- => the formula half written -->

---

A square turning into a circle while a line sweeps round, as a function of time in Manim's frame:

```wl
AnimatedGraphics[Function[t, {{EdgeForm[White], FaceForm[Orange], Morph[Rectangle[{-1, -1}, {1, 1}], Disk[{0, 0}, 1]][Tween[{0, 1}][t]]},
    {White, Line[{{3, 0}, {3, 0} + 2 {Cos[Pi t], Sin[Pi t]}}]}}], PlotRange -> {{-64/9, 64/9}, {-4, 4}}, "Duration" -> 2][0.6, ImageSize -> 480]
```

<!-- => a half-rounded orange square, a line at an angle -->

---

A film: a backdrop and a typed line on the canvas:

```wl
AnimatedGraphics[{Backdrop[RGBColor["#F4F1EA"]], Typewriter["Every language starts with a few words.", {0, 2}, FontColor -> Black]}][1, ImageSize -> 480]
```

<!-- => the sentence typed on paper -->

## Scope

A camera that zooms in:

```wl
AnimatedGraphics[{White, Table[Disk[{x, 0}, 0.2], {x, -6, 6, 2}]}, "Duration" -> 2,
    PlotRange -> Function[t, With[{s = 1 - 0.6 Tween[{0, 2}][t]}, s {{-64/9, 64/9}, {-4, 4}}]]][1.9, ImageSize -> 480]
```

<!-- => three large dots filling the frame -->

---

Later animations are objects placed at later times, each playing from there:

```wl
AnimatedGraphics[{AnimatedGraphics[Circle[], Orange]["Play", "Creation", Method -> "Create"],
    {1, 2} -> AnimatedGraphics[Disk[{0, 0}, 0.5], Blue]["Play", "Creation", Method -> "GrowFromCenter"]}, PlotRange -> {{-2, 2}, {-2, 2}}][1.5, ImageSize -> 240]
```

<!-- => an orange circle, a blue disk growing inside -->

---

A 3D picture, with text over it:

```wl
AnimatedGraphics[Function[t, {Graphics3D[Sphere[], Boxed -> False, ViewPoint -> {2 Cos[t], 2 Sin[t], 1}], Text["a sphere", {-5, 3}]}],
    PlotRange -> {{-64/9, 64/9}, {-4, 4}}, "Duration" -> 2][1, ImageSize -> 480]
```

<!-- => a sphere and a caption -->

---

A plot inset in a scene, a dot riding it:

```wl
AnimatedGraphics[Function[t, Inset[Plot[2 (x - 5)^2, {x, 0, 10}, PlotStyle -> Directive[Pink, AbsoluteThickness[4]], AxesStyle -> White, TicksStyle -> White,
    Epilog -> {White, AbsolutePointSize[16], Point[{5 t, 2 (5 t - 5)^2}]}], {0, 0}, Center, {12, 6}]], PlotRange -> {{-64/9, 64/9}, {-4, 4}}, "Duration" -> 1][0.6, ImageSize -> 480]
```

<!-- => a parabola on white axes, a dot on it -->

---

A nested scene shown in a screen of the frame, with coordinates of its own:

```wl
AnimatedGraphics[{Backdrop[GrayLevel[0.2]], AnimatedGraphics[Function[t, {White, Disk[{Cos[2 Pi t], Sin[2 Pi t]}, 0.2]}], PlotRange -> {{-2, 2}, {-2, 2}},
    "Screen" -> {1200, 100, 600, 600}, Background -> Black]}, "Duration" -> 1][0.3, ImageSize -> 480]
```

<!-- => a black square screen on the right, a dot circling in it -->

---

Frames along the time axis:

```wl
Table[AnimatedGraphics[{Backdrop[Black], {0, 1} -> Function[t, CanvasDisk[{960 + 600 Sin[2 Pi t], 540}, 80, Orange]]}][t, ImageSize -> 120], {t, 0, 0.75, 0.25}]
```

<!-- => four small frames with the disk moving -->

## Options

### CyclesPerSecond

A drum track as the sound, eight bars at 120 BPM, sixteen seconds:

```wl
Duration[Audio[AnimatedGraphics[{Backdrop[Black], Track["bd [~ bd] sd ~, hh*8"]}, "Duration" -> 8, "CyclesPerSecond" -> 1/2]]]
```

<!-- => 16 s -->

### PlotTheme

A plot inset in a scene takes the scene's theme; here Manim's, and the film's paper:

```wl
Table[AnimatedGraphics[{Inset[Plot[{Sin[x], Cos[x]}, {x, 0, 2 Pi}], {0, 0}, Center, {6, 3}]}, PlotRange -> {{-4, 4}, {-2.25, 2.25}},
    PlotTheme -> th, "Duration" -> 1][0, ImageSize -> 320], {th, {"Manim", "Paper"}}]
```

<!-- => two plots: blue and red curves on black with white axes, and red and blue on warm paper with dark axes -->

### BaseStyle

An option set once for every element in the film:

```wl
AnimatedGraphics[{Backdrop[White], TitleCard["WAnim", {0, 2}], CaptionText["graphics in time", {0.2, 2}, Position -> {760, 700}]},
    BaseStyle -> {FontColor -> Black, "Enter" -> "Fade"}][0.3, ImageSize -> 480]
```

<!-- => both fading in, in black -->

## Properties and Relations

Every creation tool returns an AnimatedGraphics, so an element can be looked at alone:

```wl
TitleCard["1986", {0, 2}, FontColor -> Red, FontSize -> 220][1, ImageSize -> 240]
```

<!-- => "1986" in red on grey -->

---

The effects queue sets the duration:

```wl
AnimatedGraphics[Circle[]]["Play", "Creation"]["Wait", "Duration" -> 2]["Duration"]
```

<!-- => 3 -->
