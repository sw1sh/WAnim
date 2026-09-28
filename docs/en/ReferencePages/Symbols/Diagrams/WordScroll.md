---
Template: Symbol
Name: WordScroll
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/WordScroll
Keywords: [words, scroll, credits, background, texture, names]
SeeAlso: [WordWall, TileGrid, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[WordScroll]()[{*word*_1, *word*_2, …}, {$t_0$, $t_1$}]</code> rolls the words up the frame in columns, faintly, like credits: a backdrop of a whole family of names.

## Details & Options

- Words fill the "Columns" (their x positions) row by row, starting at the canvas height "Start" and rising "Speed" pixels per unit.
- Each word's faintness is fixed by its name within the "Opacity" range {*least*, *most*}.

| Option | Default | Description |
| --- | --- | --- |
| "Columns" | {60, 400, 740, 1080, 1420, 1760} | x of each column |
| "Speed" | 260 | pixels per unit |
| "LineHeight" | 30 | between rows |
| "Start" | 1150 | where the first row starts |
| "Opacity" | {0.1, 0.16} | faintest and strongest |
| FontSize | 17 | size of the words |

## Basic Examples

Every plotting function, rolling past:

```wl
WordScroll[Names["System`*Plot"], {0, 4}, "Opacity" -> {0.4, 0.7}]["Graphics", 2.5, ImageSize -> 480]
```

<!-- => columns of ...Plot names rising -->
