---
Template: Symbol
Name: CaptionText
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/CaptionText
Keywords: [caption, subtitle, narration, words, highlight, beat, kinetic typography]
SeeAlso: [Typewriter, TitleCard, DictionaryCard, CanvasWrap, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[CaptionText]()[*text*, {$t_0$, $t_1$}]</code> is a layer setting *text* into a column, each word rising in on its own beat from $t_0$, all leaving together after $t_1$.

## Details & Options

- Words arrive "Interval" apart; with a musical timeline in bars, 1/16 puts them on sixteenth notes.
- The text wraps to "Width" pixels; Position is the first line's baseline at its left end.
- "Highlight" words (compared without punctuation) are drawn in "HighlightColor".
- The caption leaves over "ExitTime" after $t_1$, so its span ends at $t_1$ plus "ExitTime".
- CaptionText takes the options common to all creation tools ([Backdrop]()) and these:

| Option | Default | Description |
| --- | --- | --- |
| "Width" | 590 | column width in pixels |
| "LineHeight" | 1.12 | line spacing as a multiple of the font size |
| "Interval" | 1/16 | time between words |
| "Highlight" | {} | words to draw in the highlight colour |
| "HighlightColor" | red | their colour |
| Position | {1250, 720} | baseline of the first line, left end |
| FontSize | 52 | size in canvas pixels |

## Basic Examples

A caption with its number highlighted:

```wl
CaptionText["Its first vocabulary: 554 words.", {0, 2}, "Highlight" -> "554", FontColor -> Black][1, ImageSize -> 480]
```

<!-- => the sentence in the right column, 554 in red -->

---

Words still arriving:

```wl
CaptionText["Its first vocabulary: 554 words.", {0, 2}, FontColor -> Black][0.2, ImageSize -> 480]
```

<!-- => the first few words, the last ones faint and low -->

## Options

### Width

A narrower column wraps into more lines:

```wl
CaptionText["Natural language for people. Computational language for both.", {0, 2}, "Width" -> 360, FontColor -> Black][1.5, ImageSize -> 480]
```

<!-- => the sentence in four short lines -->
