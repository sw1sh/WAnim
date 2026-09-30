# WAnim

Live audiovisual coding in the Wolfram Language -- a homage to [Manim](https://github.com/ManimCommunity/manim).
A piece is an `AnimatedGraphics`, graphics with a time axis: a list of content, one creation tool per segment,
drawn with a canvas kit and scored with Strudel/TidalCycles-style patterns whose `Track`s the picture can query. Published as
`WolframInstitute/WAnim`.

```wl
PacletDirectoryLoad["path/to/this/repo"]; Needs["WolframInstitute`WAnim`"]

film = AnimatedGraphics[{
    Backdrop[Black],
    Typewriter["Every language starts with a few words.", {0.5, 4}, "Highlight" -> "words", "Exit" -> "Collapse"],
    TerminalSession[{{4.1, "#I[1]::  Ex[(a + b)^3]"}, {4.6, "#O[1]:   a^3 + 3 a^2 b + 3 a b^2 + b^3", "Output"}}, {4, 8}],
    NotebookSession[{{8, "In", "Plot3D[Sin[x y], {x, 0, 3}, {y, 0, 3}]"}}, {8, 12}, "Evaluate" -> True],
    Spikey[{8, 12}, "Pulse" -> Track["bd*4"]],
    Track["bd [~ bd] sd ~, hh*8"]
  }, "CyclesPerSecond" -> 1/2];
film[6]                      (* the frame at 6 cycles *)
Export["film.mp4", film]     (* rendered in parallel, with its sound *)
```

- **Documentation**: sources in `docs/en` (guide, symbol pages), built to `WAnim/Documentation` with
  `wolframscript -f scripts/build_docs.wls` (uses the deployed [MarkdownToNotebook](https://github.com/WolframInstitute/MarkdownToNotebook)
  resource function from the cloud). Start at the `WAnim` guide.
- **Tests**: `TestReport["WAnim/Tests/Toolkit.wlt"]` after loading.
- **Drum kit**: synthesized by `scripts/make_drums.wls` into the paclet's `Drums` asset (`$DrumKit`); no downloads.
- **Fonts**: the creation tools default to Source Sans 3 / Serif 4 / Code Pro, VT323, Arimo and Courier Prime;
  the front end only sees installed fonts.
- Research notes on the design are in `docs/*.md`; the Manim gallery reproductions are in `Notebooks/`
  ([published](https://www.wolframcloud.com/obj/murzin.nikolay/Published/WolfAnimGallery.nb)).

## AnimatedGraphics and Canvas

One head does it all. A film, a Manim scene and a Manim mobject are each an `AnimatedGraphics`:
primitives, `{t0, t1} -> x` spans, functions of time, nested `AnimatedGraphics` (under a span they run
on a clock of their own; with a `PlotRange` or `"Screen"` of their own they are drawn into a screen)
and a `Track` for sound, plus a queue of `AnimationEffect`s (`g["Play", "Creation", Method -> "Write"]`).
`g[t]` is the frame, a `Graphics`. It renders live (`g["Dynamic"]`, clocked by its sound, so the picture
can never drift from it), as `AnimatedImage[g]`, `Video[g]`, `Audio[g]`, and as video with
`Export["x.mp4", g]` (frames rendered on parallel subkernels and muxed with the sound by ffmpeg).

```wl
g = AnimatedGraphics[{
    Backdrop["#F4F1EA"],
    {0, 4} -> Function[t, CanvasText[TypedText["Every language starts with a few words.", t / 3], {200, 560}, CanvasFont["Source Code Pro", 64], Black]],
    Track["a4 c5 e5 d5"]
  }, "Duration" -> 4, "CyclesPerSecond" -> 1/2]
g["Dynamic"]
```

- **Canvas kit** (`Canvas.wl`): canvas-2D drawing that emits ordinary WL primitives. Coordinates are
  canvas pixels (x right, y down); `CanvasTransform` / `CanvasOpacity` nest like `ctx.save` +
  `translate` / `scale` / `rotate` / `globalAlpha`. `CanvasText` anchors on the alphabetic baseline
  using per-face advance tables measured once through the front end (cached in
  `$UserBaseDirectory/ApplicationData/WolfAnim`), scales with the transform, supports tracking, and
  keeps its proportions at any `ImageSize`. Plus `CanvasRectangle` (fill, stroke, rounded),
  `CanvasPolygon`, `CanvasLine`, `CanvasDisk`, `CanvasImage` (stretch or contain), `CanvasGradient`,
  `CanvasClip`, `CanvasWrap`, `CanvasTextWidth`, `TypedText`.
- **Era screens**: `CanvasScreen` draws a scene at a low logical resolution and
  quantize it like an old display (1-bit threshold, NeXT four greys, colour), upscaled
  nearest-neighbour; `OrderedDither` gives pictures the 4x4 Bayer look of a 1-bit display.
- **Sound to picture**: `EventTrack[{{onset, dur, value}, ...}]` writes a linear score as a `Track`;
  `TrackPulse[track, decay][t]` is 1 on each onset and decays, the kick that makes a picture hop.
- **Easing**: `Easing["OutCubic" | "InOutExpo" | "OutBack" | ...]`, also accepted as an
  `AnimationEffect` `"Easing"`.

The first user is the Wolfram Language port of the film *In[1]:=*:
[WolframFilm/notebook](https://github.com/WolframInstitute/WolframFilm/tree/main/notebook), written almost entirely in creation tools.
