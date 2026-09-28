---
Template: Symbol
Name: StageBrace
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/StageBrace
Keywords: [brace, curly brace, annotation, label, Manim Brace]
SeeAlso: [Stage, StageAxes]
RelatedGuides: [WAnim]
---

## Usage

<code>[StageBrace]()[{*a*, *b*}]</code> is a curly brace spanning *a* to *b* on their right-hand side, as a [Line]().

<code>[StageBrace]()[{*a*, *b*}, "Tip"]</code> is where a label for it goes.

## Details & Options

- For a span from left to right, the right-hand side is below; reverse the points to brace the other side.
- "Depth" (default 0.3) is how far the brace reaches; "Buffer" (default 0.15) its gap from the span.

## Basic Examples

A brace under a segment, labelled:

```wl
Graphics[{Line[{{-2, 0}, {2, 0}}], StageBrace[{{-2, 0}, {2, 0}}], Text["4 units", StageBrace[{{-2, 0}, {2, 0}}, "Tip"]]}]
```

<!-- => a segment, a brace below it and its label -->
