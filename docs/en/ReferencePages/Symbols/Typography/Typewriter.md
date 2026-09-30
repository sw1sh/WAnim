---
Template: Symbol
Name: Typewriter
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Typewriter
Keywords: [typewriter, typing, kinetic typography, cursor, highlight, text animation]
SeeAlso: [TitleCard, CaptionText, TypedText, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[Typewriter]()[*text*, {$t_0$, $t_1$}]</code> is a timeline layer that types *text* from time $t_0$ behind a blinking cursor and leaves by $t_1$.

## Details & Options

- [Typewriter]() returns an [AnimatedGraphics](); put it in a film, or look at it alone with <code>*g*[*t*]</code>.
- Times are in the timeline's own unit (seconds, bars, ...). Typing starts at $t_0$ and lasts "TypeTime"; the line then holds until $t_1$ and leaves by its "Exit".
- The text is set in a monospaced face by default with its baseline at Position (centred on it by default), a canvas point {*x*, *y*} in pixels with $y$ down, `Center`, or `Scaled[{u, v}]` of the canvas.
- "Highlight" words change to "HighlightColor" once typing is done (at "HighlightTime").
- "Exit" -> "Collapse" folds the line into its cursor over "ExitTime", as if the text were being swallowed by the prompt.
- Typewriter takes the options common to all creation tools ([Backdrop]()) and these:

| Option | Default | Description |
| --- | --- | --- |
| "TypeTime" | Automatic | time taken to type the whole text; `Automatic` types briskly, at most half the span |
| "Cursor" | "Block" | "Block", "Bar" or `None` |
| "CursorColor" | red | colour of the cursor |
| "Highlight" | {} | words to light up after typing |
| "HighlightColor" | red | the colour they change to |
| "HighlightTime" | Automatic | when they change; `Automatic` is just after typing ends |
| "Exit" | "Fade" | "Fade", "Drop", "Cut" or "Collapse" |
| FontFamily | Automatic | `Automatic` uses a monospaced face |
| FontSize | 64 | size in canvas pixels |

## Basic Examples

A line to be typed over the first two seconds of a four-second span:

```wl
Typewriter["Every language starts with a few words.", {0, 4}]
```

<!-- => a AnimatedGraphics summary box named Typewriter, span {0, 4} -->

---

Halfway through the typing, on a dark canvas:

```wl
Typewriter["Every language starts with a few words.", {0, 4}][1, Background -> Black, ImageSize -> 480]
```

<!-- => the first half of the sentence and a red block cursor, centred -->

---

The finished line with its last word lit up:

```wl
Typewriter["Every language starts with a few words.", {0, 4}, "Highlight" -> "words"][3, Background -> Black, ImageSize -> 480]
```

<!-- => the whole sentence, "words" in red -->

## Options

### Cursor

A thin bar cursor instead of a block:

```wl
Typewriter["Names[\"*\"]", {0, 2}, "Cursor" -> "Bar"][0.3, Background -> Black, ImageSize -> 480]
```

<!-- => a partial input with a thin red bar after it -->

### Exit

Collapsing into the cursor at the end of the span:

```wl
Typewriter["Every language starts with a few words.", {0, 4}, "Exit" -> "Collapse", "ExitTime" -> 0.5][3.8, Background -> Black, ImageSize -> 480]
```

<!-- => the sentence squeezed toward its right end -->

### Fonts and position

A serif line at the top left of the canvas:

```wl
Typewriter["1986.", {0, 2}, FontFamily -> "Source Serif 4", FontSize -> 120, Position -> {160, 300}, Alignment -> Left, FontColor -> Black][1.5, ImageSize -> 480]
```

<!-- => "1986." in large serif type at the upper left -->

## Applications

A cold open: the thesis typed, its last word lit, then everything folding into the cursor:

```wl
AnimatedGraphics[{Backdrop[Black], Typewriter["Every language starts with a few words.", {0.5, 4}, "TypeTime" -> 2.1, "Highlight" -> "words", "Exit" -> "Collapse", "ExitTime" -> 0.45]}, "Duration" -> 4][3.2, ImageSize -> 480]
```

<!-- => the finished line with "words" in red on black -->
