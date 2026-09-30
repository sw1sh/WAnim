---
Template: Symbol
Name: WordWall
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/WordWall
Keywords: [word wall, vocabulary, lexicon, dictionary, word cloud, frequency]
SeeAlso: [WolframLanguageData, NumberCounter, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[WordWall]()[{{"*word*", *weight*, *t*}, …}, {$t_0$, $t_1$}]</code> lays every word out alphabetically in justified lines like a dictionary page, each sized by its weight and appearing at its time *t*.

## Details & Options

- Weights are usage frequencies or any positive numbers; sizes grow with their logarithm, and the whole wall is scaled to fill the canvas.
- A word pops in at its time, flashes "FlashColor" and settles into "Color"; "Presence" (a number from 0 to 1, or a function of time) raises the settled words from a faint texture to full strength ("StrongColor").
- Settled words are rasterized once per half unit, so a wall of thousands of words stays fast. Give Background -> the colour beneath the wall (or a function of time) so that picture is opaque, which is much cheaper to draw frame after frame.
- "Camera" -> *f* moves the page: *f*[*t*] is a canvas transform (built from CanvasTranslate, CanvasScale, …) or None. Close up, the words in view are drawn as type, so they stay sharp.
- "Emphasis" -> *f* picks words out: *f*[*t*] is {*test*, *strength*} or None; the page dims by *strength* and the words for which *test*[*word*] is True stand out.
- *wall*["Places"] gives the canvas point at the middle of each word, for pointing a camera at it.
- With "Origin" -> {*x*, *y*}, arriving words fly in an arc from that point to their places over "FlightTime", the biggest "FlightCount" of them at a time, as if coming out of an output.

| Option | Default | Description |
| --- | --- | --- |
| "Presence" | 0 | how strong settled words are |
| "Color" | warm grey | settled words |
| "StrongColor" | near black | settled words at full presence |
| "FlashColor" | red | arriving words |
| "Margin" | {36, 30} | margins in pixels |
| Background | None | the colour the wall sits on, or a function of time |
| "Camera" | None | a function of time giving a canvas transform |
| "Emphasis" | None | a function of time giving {test, strength} |
| "From" | None | a point arriving words fly from |
| "FlightTime" | 0.35 | how long a flight takes |
| "FlightCount" | 90 | most words in flight at once |

## Basic Examples

The first 300 symbols of the Wolfram Language by usage, all present:

```wl
WordWall[Take[SortBy[Cases[WolframLanguageData[All, {"Name", "Frequencies"}], {n_, {"All" -> w_ ? NumericQ, ___}} :> {n, w, 0}], -#[[2]] &], 300], {0, 2}, "Presence" -> 1][1, ImageSize -> 480]
```

<!-- => a dense alphabetical wall, List and Set large -->

---

Words arriving over time:

```wl
WordWall[{#, 1., RandomReal[{0, 2}, WorkingPrecision -> 3]} & /@ {"alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta"}, {0, 3}][1, ImageSize -> 480]
```

<!-- => some Greek letters, the newest red -->

## Options

### From

Words flying out of a point to their places:

```wl
WordWall[{#, 1., 1} & /@ {"alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta"}, {0, 3}, "Origin" -> {300, 900}][0.8, ImageSize -> 480]
```

<!-- => words mid-flight in red arcs from the lower left -->

### Camera

Zooming in on one word; its place comes from the wall itself:

```wl
With[{words = Take[SortBy[Cases[WolframLanguageData[All, {"Name", "Frequencies"}], {n_, {"All" -> w_ ? NumericQ, ___}} :> {n, w, 0}], -#[[2]] &], 300]},
    With[{focus = WordWall[words, {0, 2}]["Places"]["List"]},
        WordWall[words, {0, 2}, "Presence" -> 1, "Camera" -> (CanvasScale[1 + #, focus] &)][1.5, ImageSize -> 480]]]
```

<!-- => the page magnified about 2.5 times around List -->

### Emphasis

The words ending in Q, standing out of a dimmed page:

```wl
WordWall[Take[SortBy[Cases[WolframLanguageData[All, {"Name", "Frequencies"}], {n_, {"All" -> w_ ? NumericQ, ___}} :> {n, w, 0}], -#[[2]] &], 300], {0, 2},
    "Presence" -> 1, Background -> White, "Emphasis" -> ({StringEndsQ[#, "Q"] &, 1} &)][1, ImageSize -> 480]
```

<!-- => a dim page with MatchQ, FreeQ, StringQ... bright -->
