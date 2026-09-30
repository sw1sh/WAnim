---
Template: Symbol
Name: TerminalSession
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/TerminalSession
Keywords: [terminal, phosphor, CRT, retro, green screen, SMP, session, scanlines]
SeeAlso: [NotebookSession, Typewriter, CanvasScreen]
RelatedGuides: [WAnim]
---

## Usage

<code>[TerminalSession]()[{*line*_1, *line*_2, …}, {$t_0$, $t_1$}]</code> is a green-phosphor terminal that powers on at $t_0$, shows the lines at their times, and powers off by $t_1$.

## Details & Options

- A line is <code>{*t*, *text*}</code> or <code>{*t*, *content*, *kind*}</code>, with *kind*:
- "Input" (default): typed from *t* over "TypeTime".
- "Output": appears whole at *t*, slightly paler.
- "Print": *content* is a list of rows printed one per "PrintInterval" in the smaller "PrintSize", like a character plot.
- "Caption": typed at the bottom of the glass in large type; captions stack upward, the first in the first of "CaptionSizes".
- The screen opens from a line to the full glass ("Enter" -> "PowerOn") and collapses to a line and then a dot ("Exit" -> "PowerOff"); either can be "Cut".
- "Glow" and "Scanlines" can be turned off; "Screen" -> {*x*, *y*, *w*, *h*} places the glass.

| Option | Default | Description |
| --- | --- | --- |
| FontFamily | "VT323" | the terminal face |
| FontColor | phosphor green | the text colour |
| "TypeTime" | 0.4 | time to type an input line |
| "PrintInterval" | 0.05 | time between printed rows |
| "PrintSize" | 27 | size of printed rows |
| "CaptionSizes" | {44, 58, 58} | sizes of successive captions |
| "Glow" | True | phosphor glow |
| "Scanlines" | True | scanlines over the glass |
| "Screen" | Automatic | the glass rectangle |

## Basic Examples

An SMP session from 1979 with its output:

```wl
TerminalSession[{{0.1, "#I[1]::  Ex[(a + b)^3]"}, {0.6, "#O[1]:   a^3 + 3 a^2 b + 3 a b^2 + b^3", "Output"}}, {0, 4}][2, ImageSize -> 480]
```

<!-- => a green terminal with the input and its expansion -->

---

A character plot printed row by row and a caption at the bottom:

```wl
TerminalSession[{{0.1, "#I[2]::  Graph[Sin[1/x],x,0.02,0.2]"}, {0.5, {"  **     **", "0.5 ****_______", "  ** **    **"}, "Print"}, {1, "NOVEMBER 1979. CALTECH.", "Caption"}}, {0, 4}][2, ImageSize -> 480]
```

<!-- => the input, three small plot rows and a caption near the bottom -->

---

Powering off at the end of the span:

```wl
TerminalSession[{{0.1, "#I[1]::  Ex[(a + b)^3]"}}, {0, 2}][1.85, ImageSize -> 480]
```

<!-- => the glass collapsed to a thin bright line -->

## Options

### Glow and Scanlines

A plain screen without glow or scanlines:

```wl
TerminalSession[{{0.1, "READY."}}, {0, 2}, "Glow" -> False, "Scanlines" -> False, FontColor -> RGBColor["#FFB000"]][1, ImageSize -> 480]
```

<!-- => an amber terminal with a clean READY. -->
