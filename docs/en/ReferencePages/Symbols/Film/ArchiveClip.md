---
Template: Symbol
Name: ArchiveClip
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/ArchiveClip
Keywords: [archival film, documentary, clip, video, interview, subtitles, lower third, voice, ducking]
SeeAlso: [AnimatedGraphics, Video, Track]
RelatedGuides: [WAnim]
---

## Usage

<code>[ArchiveClip]()[*video*, {*t0*, *t1*}]</code> plays an archival film over its span: its picture as a print or the full frame, its sound in the film's soundtrack with the music ducked beneath it.

## Details & Options

- *video* is a [Video](), a file or a URL. URLs are downloaded once, kept only when whole, and shared by every kernel that renders the film; the frames of the moment are decoded once, by ffmpeg, into a cache.
- "From" and "To" pick the moment, in seconds of the source. "Show" -> {{*ta*, *tb*}, ...} shows the picture only then: cut away while the voice goes on.
- "Credit" names the speaker, {"*name*", "*where and when*"}: a lower third the first time the picture shows, and a small tag above the subtitles whenever they speak. "Subtitle" is a string or {{*s0*, *s1*, "*line*"}, ...}; words between asterisks are emphasised, in the accent colour.
- "Volume" -> Automatic brings every clip to one loudness. A voice fades in and out at its edges, and the film's music ducks to "Duck" under it, staying down through pauses shorter than 3 seconds.
- "Crop" -> {*left*, *right*, *top*, *bottom*} trims fractions of the picture; "Zoom" pushes in slowly; "Fade" dissolves it in and out; "Caption" says what it shows.

| Option | Default | Description |
| --- | --- | --- |
| "From" | 0 | start of the moment, seconds of the source |
| "To" | Automatic | end of the moment |
| "Style" | "Frame" | "Frame" (a print on the page) or "Full" |
| "Show" | All | spans when the picture shows |
| "Credit" | None | the speaker: a name, or {name, occasion} |
| "Subtitle" | None | the words, timed |
| "Caption" | None | what the picture shows, top right |
| "Volume" | Automatic | the voice's level |
| "Duck" | 0.2 | the music's gain under the voice |
| "Sound" | True | False for a silent clip |
| "Crop" | None | fractions trimmed from each side |
| "Zoom" | 0 | slow push-in over the clip |
| "Fade" | 0 | dissolve time in and out |

## Basic Examples

A clip of a rendered film, full frame, captioned:

```wl
With[{v = AnimatedGraphics[{Backdrop[Function[t, Hue[t / 2]]]}, "Duration" -> 2, "CanvasSize" -> {320, 180}]["Video", "Parallel" -> False]},
    AnimatedGraphics[{ArchiveClip[v, {0, 2}, "Style" -> "Full", "Sound" -> False, "Caption" -> "A colour wash"]}, "Duration" -> 2, "CanvasSize" -> {320, 180}][1, ImageSize -> 320]]
```

<!-- => a coloured frame with a caption top right -->
