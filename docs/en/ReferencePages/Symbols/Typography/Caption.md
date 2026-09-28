---
Template: Symbol
Name: Caption
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Caption
Keywords: [caption, subtitle, narration, words, highlight, beat, kinetic typography]
SeeAlso: [Typewriter, Title, DictionaryCard, CanvasWrap, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[Caption]()[*text*, {$t_0$, $t_1$}]</code> is a layer setting *text* into a column, each word rising in on its own beat from $t_0$, all leaving together after $t_1$.

## Details & Options

- Words arrive "WordInterval" apart; with a musical timeline in bars, 1/16 puts them on sixteenth notes.
- The text wraps to "Width" pixels; Position is the first line's baseline at its left end.
- "Highlight" words (compared without punctuation) are drawn in "HighlightColor".
- The caption leaves over "ExitTime" after $t_1$, so its span ends at $t_1$ plus "ExitTime".
- Caption takes the options common to all creation tools ([$LayerOptions]()) and these:

| Option | Default | Description |
| --- | --- | --- |
| "Width" | 590 | column width in pixels |
| "LineHeight" | 1.12 | line spacing as a multiple of the font size |
| "WordInterval" | 1/16 | time between words |
| "Highlight" | {} | words to draw in the highlight colour |
| "HighlightColor" | red | their colour |
| Position | {1250, 720} | baseline of the first line, left end |
| FontSize | 52 | size in canvas pixels |

## Basic Examples

A caption with its number highlighted:

```wl
Caption["Its first vocabulary: 554 words.", {0, 2}, "Highlight" -> "554", FontColor -> Black]["Graphics", 1, ImageSize -> 480]
```

<!-- => the sentence in the right column, 554 in red -->

---

Words still arriving:

```wl
Caption["Its first vocabulary: 554 words.", {0, 2}, FontColor -> Black]["Graphics", 0.2, ImageSize -> 480]
```

<!-- => the first few words, the last ones faint and low -->

## Options

### Width

A narrower column wraps into more lines:

```wl
Caption["Natural language for people. Computational language for both.", {0, 2}, "Width" -> 360, FontColor -> Black]["Graphics", 1.5, ImageSize -> 480]
```

<!-- => the sentence in four short lines -->
