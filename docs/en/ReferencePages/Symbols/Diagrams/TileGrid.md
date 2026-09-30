---
Template: Symbol
Name: TileGrid
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/TileGrid
Keywords: [grid, tiles, contact sheet, montage, cards, plots, rotating]
SeeAlso: [WordScroll, PhotoPrint, TrackPulse, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[TileGrid]()[{{*label*, *content*, *note*}, …}, {$t_0$, $t_1$}]</code> deals out white cards, one per "Interval", each showing *content* with *label* under it and *note* at its right.

## Details & Options

- *content* is anything the front end can show (a plot, an image, a table) or a function <code>*u* |-> *expr*</code>, played as a loop over "Period": a surface turning as *u* goes from 0 to 1.
- Contents are rasterized once, animated ones as "Frames" pictures.
- Cards fill rows of "Columns" from Position, the top-left corner. A *note* is optional.
- "Enter" -> "Pop" (default) pops each card up; "Pulse" -> *track* punches the newest card on the track's onsets.

| Option | Default | Description |
| --- | --- | --- |
| Position | {96, 250} | top-left corner of the grid |
| "Columns" | 4 | cards per row |
| "TileSize" | {400, 330} | size of a card |
| "Gap" | {36, 60} | space between cards, across and down |
| "Interval" | 1/4 | time between cards |
| "Frames" | Automatic | pictures in an animated content (40 a unit of "Period") |
| "Period" | 2 | time for one loop of an animated content |
| "Pulse" | None | a Track to punch to |
| "NoteColor" | red | colour of the notes |

## Basic Examples

Four plots dealt out on the beat:

```wl
TileGrid[{{"Plot", Plot[Sin[x], {x, 0, 6}], "1.0"}, {"ContourPlot", ContourPlot[Sin[x y], {x, 0, 3}, {y, 0, 3}], "1.0"},
    {"DensityPlot", DensityPlot[Sin[x] Cos[y], {x, -3, 3}, {y, -3, 3}], "1.0"}, {"StreamPlot", StreamPlot[{-y, x}, {x, -1, 1}, {y, -1, 1}], "7"}}, {0, 3}][2, ImageSize -> 480]
```

<!-- => four white cards with plots, names under them -->

---

A surface that turns:

```wl
TileGrid[{{"SphericalPlot3D", u |-> SphericalPlot3D[1 + Sin[5 t] Sin[4 p]/3, {t, 0, Pi}, {p, 0, 2 Pi}, Mesh -> None, ViewPoint -> {3 Cos[2 Pi u], 3 Sin[2 Pi u], 1.5}]}}, {0, 3}, "Frames" -> 8][1.2, ImageSize -> 480]
```

<!-- => one card with a turning spherical plot -->
