# WolfAnim

Inspired by [Manim](https://github.com/ManimCommunity/manim).

Reproduced [gallery](https://docs.manim.community/en/stable/examples.html) examples so far: [Link](https://www.wolframcloud.com/obj/murzin.nikolay/Published/WolfAnimGallery.nb)

## Timeline and Canvas: film-scale animation

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
[WolframFilm/notebook](https://github.com/WolframInstitute/WolframFilm/tree/main/notebook).
