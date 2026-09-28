---
Template: Symbol
Name: $LayerOptions
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/$LayerOptions
Keywords: [options, creation tools, layer, enter, exit, position, font]
SeeAlso: [TimelineLayer, Typewriter, Caption, Title]
RelatedGuides: [WAnim]
---

## Usage

<code>[$LayerOptions]()</code> is the list of options every creation tool accepts, with their defaults.

## Details & Options

- Position is a canvas point {*x*, *y*} in pixels with $y$ down, `Center`, or `Scaled[{u, v}]` of the canvas; Alignment places text about it.
- FontFamily, FontSize (pixels), FontWeight (a CSS number such as 600, or a name such as "SemiBold"), FontSlant and FontColor set the type.
- "Enter" ("Fade", "Rise", "Pop", "Cut") and "Exit" ("Fade", "Drop", "Cut") animate arrival and departure over "EnterTime" and "ExitTime"; tools add their own, such as "Letters", "Burst", "PowerOn" and "Collapse".
- Each tool overrides some defaults: a [Typewriter]() is monospaced and centred, a [Caption]() sits in the right-hand column.

## Basic Examples

The shared options:

```wl
$LayerOptions
```

<!-- => {Position -> Center, Alignment -> Left, FontFamily -> Automatic, FontSize -> 48, ...} -->

---

The same caption with different entrances, just after it starts:

```wl
Table[Caption["Enter", {0, 2}, "Enter" -> e, Position -> {100, 200}, FontSize -> 90, FontColor -> Black]["Graphics", 0.1, ImageSize -> 160], {e, {"Fade", "Rise"}}]
```

<!-- => two frames of the word arriving -->
