---
Template: Symbol
Name: TimelineLayer
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/TimelineLayer
Keywords: [layer, segment, clip, timeline, creation tool]
SeeAlso: [Timeline, Backdrop, Typewriter, Caption, NotebookSession]
RelatedGuides: [WAnim]
---

## Usage

<code>[TimelineLayer]()[<|"Name" -> *name*, "Span" -> {$t_0$, $t_1$}, "Draw" -> *f*|>]</code> is one segment of a [Timeline](): drawn by *f*[*t*] while $t_0 \le t < t_1$.

## Details & Options

- Every creation tool ([Typewriter](), [Caption](), [Terminal](), [NotebookSession](), [Spikey](), ...) returns a TimelineLayer; you rarely construct one by hand.
- <code>*layer*[*t*]</code> gives the layer's graphics primitives at time *t*, on the current canvas.
- <code>*layer*["Graphics", *t*]</code> shows the layer alone on a 1920 x 1080 canvas; `Background` and Graphics options such as `ImageSize` go through. <code>*layer*["Image", *t*]</code> rasterizes it.
- <code>*layer*["Shift", *dt*]</code> moves the layer later in time by *dt*; "Span", "Draw" and "Name" read its parts.

## Basic Examples

A caption is a TimelineLayer:

```wl
Caption["Words for pictures, too.", {0, 2}]
```

<!-- => a TimelineLayer summary box named Caption -->

---

Its span:

```wl
Caption["Words for pictures, too.", {0, 2}]["Span"]
```

<!-- => {0, 2.25}: the span includes the exit -->

---

Shown alone, one second in:

```wl
Caption["Words for pictures, too.", {0, 2}, Position -> {200, 540}, FontSize -> 90]["Graphics", 1, ImageSize -> 480]
```

<!-- => the caption on a light grey canvas -->

## Scope

Moving a layer later in time:

```wl
Caption["Words for pictures, too.", {0, 2}]["Shift", 10]["Span"]
```

<!-- => {10, 12.25} -->
