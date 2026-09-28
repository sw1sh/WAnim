---
Template: Symbol
Name: $NotebookEras
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/$NotebookEras
Keywords: [notebook, era, retro, chrome, style, Macintosh]
SeeAlso: [NotebookSession, CanvasScreen]
RelatedGuides: [WAnim]
---

## Usage

<code>[$NotebookEras]()</code> is the registry of notebook looks that [NotebookSession]() draws, keyed by era name.

## Details & Options

- An era is an association: "Chrome" (a function of the logical screen size and the title drawing the window), "Content" (the rectangle the cells go in), "Code" and "Label" (the [CanvasFont]()s of cells and their labels), "LabelsAbove", "Left", "Gap", "Bracket", "Page" and "Ink" (the cell style), and "Pixel" and "Depth" (the display, as for [CanvasScreen]()).
- Adding an entry makes a new era available as <code>"Era" -> "*name*"</code>.

## Basic Examples

The eras defined:

```wl
Keys[$NotebookEras]
```

<!-- => {"Mac1988"} -->

---

The display of the 1988 Macintosh era:

```wl
$NotebookEras["Mac1988"][[{"Pixel", "Depth"}]]
```

<!-- => <|"Pixel" -> 2, "Depth" -> "Bit"|> -->
