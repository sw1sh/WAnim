---
Template: Symbol
Name: Title
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Title
Keywords: [title, display type, letters, pop, rise, collapse, kinetic typography]
SeeAlso: [Typewriter, Caption, Timeline, Easing]
RelatedGuides: [WAnim]
---

## Usage

<code>[Title]()[*text*, {$t_0$, $t_1$}]</code> is a layer setting *text* as display type at Position, arriving at $t_0$ and leaving by $t_1$.

## Details & Options

- "Enter" -> "Rise" (default) fades in from slightly below; "Fade", "Pop" (scales up with an overshoot) and "Cut" are the other entrances.
- "Enter" -> "Letters" brings the text in one letter per "LetterInterval", each popping up from its baseline; the newest letter is drawn in "CursorColor", and with "Cursor" -> True a bar follows the last letter.
- "Exit" -> "Fade", "Drop", "Cut" or "Collapse": the text shrinks into "CollapsePoint" (default its centre) over "ExitTime".
- Title takes the options common to all creation tools ([$LayerOptions]()) and these:

| Option | Default | Description |
| --- | --- | --- |
| "Enter" | "Rise" | "Rise", "Fade", "Pop", "Cut" or "Letters" |
| "LetterInterval" | 1/8 | time between letters for "Letters" |
| "Cursor" | None | True draws a bar after the letters |
| "CursorColor" | red | the cursor and the newest letter |
| "CollapsePoint" | Automatic | the point the text shrinks into on "Collapse" |
| FontSize | 120 | size in canvas pixels |
| Alignment | Center | Left, Center or Right about Position |

## Basic Examples

A title rising in:

```wl
Title["1986", {0, 2}, FontColor -> RGBColor["#DD1100"], FontSize -> 220]["Graphics", 0.5, ImageSize -> 480]
```

<!-- => "1986" in large red type -->

---

A name arriving letter by letter, one per eighth of a unit, with a cursor:

```wl
Title["Mathematica", {0, 3}, "Enter" -> "Letters", "Cursor" -> True, FontSize -> 170, FontColor -> Black]["Graphics", 0.6, ImageSize -> 480]
```

<!-- => "Mathem" with the last letter red and a red bar after it -->

## Options

### Enter

The same title with each entrance, a quarter of the way in:

```wl
Table[Title["Pop", {0, 1}, "Enter" -> e, FontColor -> Black]["Graphics", 0.1, ImageSize -> 160], {e, {"Fade", "Rise", "Pop"}}]
```

<!-- => three frames: faint, faint and lower, small and growing -->

### Exit

Collapsing into its centre at the end of the span:

```wl
Title["Mathematica", {0, 2}, "Exit" -> "Collapse", "ExitTime" -> 0.4, FontSize -> 170, FontColor -> Black]["Graphics", 1.9, ImageSize -> 480]
```

<!-- => the word small, shrinking toward the centre -->
