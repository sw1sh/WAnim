# WAnim

Live audiovisual coding in the Wolfram Language -- a homage to [Manim](https://github.com/ManimCommunity/manim).
A piece is a `Timeline`: a list of layers, one creation tool per segment, drawn with a canvas kit and scored
with Strudel/TidalCycles-style patterns whose `Track`s the picture can query. Published as
`WolframInstitute/WAnim`.

```wl
PacletDirectoryLoad["path/to/this/repo"]; Needs["WolframInstitute`WAnim`"]

Timeline[{
    Backdrop[Black],
    Typewriter["Every language starts with a few words.", {0.5, 4}, "Highlight" -> "words", "Exit" -> "Collapse"],
    Terminal[{{4.1, "#I[1]::  Ex[(a + b)^3]"}, {4.6, "#O[1]:   a^3 + 3 a^2 b + 3 a b^2 + b^3", "Output"}}, {4, 8}],
    NotebookSession[{{8, "In", "Plot3D[Sin[x y], {x, 0, 3}, {y, 0, 3}]"}}, {8, 12}, "Evaluate" -> True],
    Spikey[{8, 12}, "Pulse" -> Track["bd*4"]]
  }, "SecondsPerUnit" -> 2, "Soundtrack" -> Track["bd [~ bd] sd ~, hh*8"]]["Dynamic"]
```

- **Documentation**: sources in `docs/en` (guide, symbol pages), built to `WAnim/Documentation` with
  `wolframscript -f scripts/build_docs.wls` (needs [MarkdownToNotebook](https://github.com/WolframInstitute/MarkdownToNotebook)
  next to this repo). Start at the `WAnim` guide.
- **Tests**: `TestReport["WAnim/Tests/Toolkit.wlt"]` after loading.
- **Drum kit**: synthesized by `scripts/make_drums.wls` into the paclet's `Drums` asset (`$DrumKit`); no downloads.
- **Fonts**: the creation tools default to Source Sans 3 / Serif 4 / Code Pro, VT323, Arimo and Courier Prime;
  the front end only sees installed fonts.
- Research notes on the design are in `docs/*.md`; the Manim gallery reproductions are in `Notebooks/`
  ([published](https://www.wolframcloud.com/obj/murzin.nikolay/Published/WolfAnimGallery.nb)).

## Timeline and Canvas

A `Timeline` is an ordered stack of layers, each a pure function of time over a span, composited
into one fixed-size frame. It renders live (`tl["Dynamic"]`, clocked by its soundtrack when it has
one, so the picture can never drift from the sound), as stills (`tl["Image", t]`) and as video
(`tl["Video", file]`, frames rendered on parallel subkernels and muxed with the soundtrack by ffmpeg).
Its soundtrack can be any `Track`, so the same structure that sounds can be queried by the picture.

```wl
tl = Timeline[{
    Function[t, CanvasRectangle[{0, 0, 1920, 1080}, "#F4F1EA"]],
    {0, 4} -> Function[t, CanvasText[TypedText["Every language starts with a few words.", t / 3], {200, 560}, CanvasFont["Source Code Pro", 64], Black]]
  }, "Duration" -> 4, "SecondsPerUnit" -> 2, "Soundtrack" -> Track["a4 c5 e5 d5"]]
tl["Dynamic"]
```

- **Canvas kit** (`Canvas.wl`): canvas-2D drawing that emits ordinary WL primitives. Coordinates are
  canvas pixels (x right, y down); `CanvasTransform` / `CanvasOpacity` nest like `ctx.save` +
  `translate` / `scale` / `rotate` / `globalAlpha`. `CanvasText` anchors on the alphabetic baseline
  using per-face advance tables measured once through the front end (cached in
  `$UserBaseDirectory/ApplicationData/WolfAnim`), scales with the transform, supports tracking, and
  keeps its proportions at any `ImageSize`. Plus `CanvasRectangle` (fill, stroke, rounded),
  `CanvasPolygon`, `CanvasLine`, `CanvasDisk`, `CanvasImage` (stretch or contain), `CanvasGradient`,
  `CanvasClip`, `CanvasWrap`, `CanvasTextWidth`, `TypedText`.
- **Era screens**: `RasterScreen` / `CanvasScreen` draw a scene at a low logical resolution and
  quantize it like an old display (1-bit threshold, NeXT four greys, colour), upscaled
  nearest-neighbour; `OrderedDither` gives pictures the 4x4 Bayer look of a 1-bit display.
- **Sound to picture**: `EventTrack[{{onset, dur, value}, ...}]` writes a linear score as a `Track`;
  `TrackPulse[track, decay][t]` is 1 on each onset and decays, the kick that makes a picture hop.
- **Easing**: `Easing["OutCubic" | "InOutExpo" | "OutBack" | ...]`, also accepted as an
  `AnimationEffect` `"Rate"`.

The first user is the Wolfram Language port of the film *In[1]:=*:
[WolframFilm/notebook](https://github.com/WolframInstitute/WolframFilm/tree/main/notebook), written almost entirely in creation tools.
