---
Template: Symbol
Name: Timeline
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Timeline
Keywords: [timeline, film, layers, video, animation, soundtrack, live player, motion graphics]
SeeAlso: [TimelineLayer, Backdrop, Track, TrackPulse, CanvasBlock, Video, Animate]
RelatedGuides: [WAnim]
---

## Usage

<code>[Timeline]()[{*layer*_1, *layer*_2, …}]</code> is a film: the layers stacked over time, each drawn at every moment it covers, in order.

<code>[Timeline]()[*layers*, "Soundtrack" -> *track*]</code> gives the film a soundtrack, a [Track]() or an [Audio]() object.

## Details & Options

- A layer is a [TimelineLayer]() (what every creation tool returns), a colour (a [Backdrop]()), a rule <code>{*t0*, *t1*} -> *f*</code> with *f* a function of time giving graphics primitives, a function alone (on at all times), or a rule <code>{*t0*, *t1*} -> *obj*</code> with *obj* an [AnimatedObject]() played from *t0*. Lists of layers are flattened.
- Time is in the timeline's own unit. "SecondsPerUnit" converts it to seconds for sound and video: 2 for bars at 120 BPM, 1 for seconds.
- Each layer draws on a canvas of "Size" pixels with $y$ down (see [CanvasBlock]()), so the frame is exactly "Size" and text is placed as on a browser canvas.
- <code>*tl*["Graphics", *t*]</code> gives the frame at time *t*, <code>*tl*["Image", *t*]</code> the frame rasterized at its size.
- <code>*tl*["Dynamic"]</code> is a live player: click to play or pause, drag to scrub. With a soundtrack, the audio stream is the master clock and the picture follows its true position.
- <code>*tl*["Video", *file*]</code> renders frames in parallel on subkernels, encodes them with ffmpeg together with the soundtrack, and returns a [Video](); without *file* it renders to a temporary file.
- <code>*tl*["Audio"]</code> is the soundtrack as one [Audio]() for the whole timeline; "Duration", "Layers", "Size", "SecondsPerUnit", "FrameRate" and "Soundtrack" read the settings back.

| Option | Default | Description |
| --- | --- | --- |
| "Duration" | Automatic | length in timeline units; `Automatic` is the latest layer end |
| "Size" | {1920, 1080} | frame size in pixels |
| Background | Black | colour behind all layers |
| "SecondsPerUnit" | 1 | seconds per timeline unit |
| "FrameRate" | 60 | frames per second for video |
| "Soundtrack" | None | a Track or an Audio |

## Basic Examples

A two-second timeline with a backdrop and a typed line:

```wl
Timeline[{RGBColor["#F4F1EA"], Typewriter["Every language starts with a few words.", {0, 2}, FontColor -> Black]}]
```

<!-- => a Timeline summary box: duration 2, 2 layers, size {1920, 1080} -->

---

Its frame at one second:

```wl
Timeline[{RGBColor["#F4F1EA"], Typewriter["Every language starts with a few words.", {0, 2}, FontColor -> Black]}]["Graphics", 1, ImageSize -> 480]
```

<!-- => the sentence half typed on paper -->

---

A layer can be any function of time over a span, drawn with the canvas kit:

```wl
Timeline[{Backdrop[Black], {0, 1} -> Function[t, CanvasDisk[{960 + 600 Sin[2 Pi t], 540}, 80, Orange]]}, "Duration" -> 1]["Graphics", 0.3, ImageSize -> 480]
```

<!-- => an orange disk right of centre on black -->

## Scope

Frames along the timeline:

```wl
Table[Timeline[{Backdrop[Black], {0, 1} -> Function[t, CanvasDisk[{960 + 600 Sin[2 Pi t], 540}, 80, Orange]]}, "Duration" -> 1]["Graphics", t, ImageSize -> 120], {t, 0, 0.75, 0.25}]
```

<!-- => four small frames with the disk moving -->

---

The frame as an image of the timeline's size:

```wl
ImageDimensions[Timeline[{Backdrop[Blue]}, "Duration" -> 1, "Size" -> {640, 360}]["Image", 0.5]]
```

<!-- => {640, 360} -->

## Options

### Soundtrack

A soundtrack Track rendered for the timeline's length:

```wl
$CyclesPerSecond = 1/2; Timeline[{Backdrop[Black]}, "Duration" -> 4, "SecondsPerUnit" -> 2, "Soundtrack" -> Track["bd [~ bd] sd ~, hh*8"]]["Audio"]
```

<!-- => an 8-second Audio of a drum beat -->

### SecondsPerUnit

In bars at 120 BPM, a timeline 16 units long lasts 32 seconds:

```wl
Timeline[{Backdrop[Black]}, "Duration" -> 16, "SecondsPerUnit" -> 2]["Seconds"]
```

<!-- => 32 -->

## Properties and Relations

Every creation tool returns a TimelineLayer, and a timeline is simply a list of them:

```wl
Timeline[{Backdrop[RGBColor["#F4F1EA"]], Title["1986", {0, 2}, FontColor -> Red, FontSize -> 220], Caption["He starts again, from nothing.", {0.3, 2}, Position -> {760, 700}, FontColor -> Black]}]["Graphics", 1.2, ImageSize -> 480]
```

<!-- => "1986" in red over a caption -->
