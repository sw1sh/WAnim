---
Template: Symbol
Name: PhotoPrint
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/PhotoPrint
Keywords: [photo, print, archive, polaroid, caption, scan]
SeeAlso: [CanvasImage, CaptionText, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[PhotoPrint]()[*image*, "*caption*", {$t_0$, $t_1$}]</code> pins *image* like a print, with a white border, a soft shadow and an italic caption, popping in at $t_0$ and leaving after $t_1$.

## Details & Options

- The image is fitted inside "Size" with its top-left corner at Position, and tilted by "Tilt" degrees.
- "Kicker" puts a small tracked line over the caption, for example `"FROM THE ARCHIVE · 1981"`.
- PhotoPrint takes the options common to all creation tools ([Backdrop]()) and these:

| Option | Default | Description |
| --- | --- | --- |
| "Size" | {590, 420} | the largest the image may be |
| "Tilt" | -1.5 | rotation in degrees |
| "Kicker" | None | a small line above the caption |
| "Paper" | off-white | the border colour |
| Position | {1250, 150} | the image's top-left corner |

## Basic Examples

A test image as a print:

```wl
PhotoPrint[ExampleData[{"TestImage", "Mandrill"}], "A test image", {0, 2}, Position -> {760, 240}, "CanvasSize" -> {400, 400}][1, ImageSize -> 480]
```

<!-- => the mandrill in a white border, slightly tilted, with a caption -->

## Options

### Kicker and Tilt

With a kicker line and a stronger tilt:

```wl
PhotoPrint[ExampleData[{"TestImage", "House"}], "The house, photographed", {0, 2}, "Kicker" -> "From the archive \[CenterDot] 1973", "Tilt" -> 4, Position -> {760, 240}, "CanvasSize" -> {420, 380}][1, ImageSize -> 480]
```

<!-- => the print tilted clockwise with a red kicker line -->
