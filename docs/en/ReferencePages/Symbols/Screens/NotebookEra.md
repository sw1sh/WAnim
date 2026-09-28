---
Template: Symbol
Name: NotebookEra
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/NotebookEra
Keywords: [notebook, era, retro, chrome, style, Macintosh, NeXT, Windows, dark mode]
SeeAlso: [NotebookSession, CanvasScreen]
RelatedGuides: [WAnim]
---

## Usage

<code>[NotebookEra]()["*name*"]</code> is the look of the notebook in one era, as an association that [NotebookSession]() draws through its "Era" option.

<code>[NotebookEra]()["*name*", *key* -> *value*, …]</code> is that era with some of its keys changed.

<code>[NotebookEra]()[]</code> lists the era names.

## Details & Options

- The eras run from Mathematica 1.0 on a Macintosh to 14.3 in dark mode: "Mac1988", "NeXT1988", "Win1991", "Win1996", "Mac1999", "WinXP2004", "MacOSX2007", "Yosemite2014", "BigSur2020" and "Dark2024".
- The window: "Chrome" (a function of the logical screen size and the title), "Content" (the rectangle the cells go in), "Extras" (drawn over the notebook, such as the 3.0 BasicInput palette).
- The display, as for [CanvasScreen](): "Pixel" (the logical pixel size) and "Depth" ("Bit", "Gray4", "Color" or "Full").
- The cell style: "Input", "Output", "Text", "Title" and "Label" ([CanvasFont]()s), "LabelColor", "LabelsAbove", "Left", "Gap", "Bracket", "BracketKind", "BracketWidth", "Page", "Ink", "OutputInk", "TitleColor", "Syntax" (colours for strings and user symbols, or None) and "LightDark" (how expressions are displayed).
- "Era" in [NotebookSession]() takes a name or any such association, so a new look is a value passed in, not a registration.

## Basic Examples

The eras:

```wl
NotebookEra[]
```

<!-- => {"Mac1988", "NeXT1988", "Win1991", …, "Dark2024"} -->

---

The display of the NeXT era, four greys at half resolution:

```wl
NotebookEra["NeXT1988"][[{"Pixel", "Depth"}]]
```

<!-- => <|"Pixel" -> 2, "Depth" -> "Gray4"|> -->

---

Every era, the same session:

```wl
Grid[Partition[Table[NotebookSession[{{0, "In", "words = StringSplit[\"Every language starts\"]"}, {0.3, "Out", "{Every, language, starts}"}}, {0, 1}, "Era" -> e, "Enter" -> "Cut", "PushIn" -> 0]["Graphics", 0.9, ImageSize -> 240], {e, NotebookEra[]}], 2]]
```

<!-- => ten windows from 1988 to 2024 -->

## Scope

A changed era: Big Sur with a dark page:

```wl
NotebookSession[{{0, "In", "Range[10]"}}, {0, 1}, "Era" -> NotebookEra["BigSur2020", "Page" -> GrayLevel[0.1], "Ink" -> White, "LightDark" -> "Dark"], "Evaluate" -> True, "Enter" -> "Cut"]["Graphics", 0.9, ImageSize -> 480]
```

<!-- => a Big Sur window with light text on a dark page -->
