---
Template: Paclet
ResourceType: Paclet
Name: WolframInstitute/WAnim
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
Description: Live audiovisual coding: Manim-style scenes, films and Strudel-style music as graphics and patterns in time
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [animation, Manim, motion graphics, film, video, live coding, music, Strudel, TidalCycles, patterns, audio]
MainGuide: Documentation/English/Guides/WAnim.nb
License: MIT
WolframVersion: 15.0+
Categories: [Graphics & Visualization, Sound & Music]
SourceControlURL: https://github.com/sw1sh/WAnim
Links: ["[Manim](https://www.manim.community)", "[Strudel](https://strudel.cc)", "[TidalCycles](https://tidalcycles.org)"]
---

## Details & Options

- A film, a Manim scene and a single animated object are all an [AnimatedGraphics](): graphics with a time axis. It holds graphics primitives, spans <code>{$t_0$, $t_1$} -> *x*</code>, functions of time, nested AnimatedGraphics and a [Track]() for its sound, and a queue of [AnimationEffect]()s.
- <code>*g*[*t*]</code> is the frame at time *t*, a [Graphics](). [Export]() to ".mp4" renders every frame in parallel and encodes them with ffmpeg together with the sound; [Video](), [AnimatedImage]() and [Audio]() render it too.
- Creation tools write a film one segment per line: [Typewriter](), [TitleCard](), [CaptionText](), [TerminalSession](), [NotebookSession]() (a notebook window of its era, 1988 to today), [DictionaryCard](), [Spikey](), and more. They draw with a canvas kit that places text exactly where a browser canvas would.
- A [Track]() is a cyclic-time music pattern after Strudel and TidalCycles, written in mini-notation such as `"bd [~ bd] sd, hh*8"`. It plays live as an editable, highlighting piano roll, renders to [Audio]() through synthesized instruments, and can be queried by the picture ([TrackPulse]()), so motion locks to sound.
- LaTeX is typeset with MaTeX when it is installed, in objects and on the canvas ([CanvasTeX]()), where captions can carry mathematics inline.
- Documentaries: [ArchiveClip]() plays archival film in a film -- picture, voice with the music ducked under it, emphasised subtitles, the speaker's name -- and a 3D canvas ([CanvasCamera]()) draws point clouds, curves, lit surfaces and spheres as plain primitives.
- Frames are drawn on the GPU ([GPUGraphics](), Metal on Apple silicon) where they can be, tens of times faster than the front end, which draws the rest.

## Usage

The paclet provides [AnimatedGraphics]() and [AnimationEffect]() for animation, the creation tools for films, the canvas kit ([CanvasText](), [CanvasRectangle](), ...), and [Track]() with its combinators, [Instrument]() and [Mixer]() for music.

## Basic Examples

A square turning into a circle, half way:

```wl
AnimatedGraphics[Function[t, {EdgeForm[White], FaceForm[Orange], Morph[Rectangle[{-1, -1}, {1, 1}], Disk[{0, 0}, 1]][Tween[{0, 1}][t]]}],
    PlotRange -> {{-3, 3}, {-2, 2}}, "Duration" -> 1][0.5, ImageSize -> 320]
```

<!-- => an orange shape half way between a square and a disk -->

---

A formula written in, Manim style:

```wl
AnimatedGraphics[{"e^{i\\pi}", "+ 1 = 0"}]["Play", "Creation", Method -> "Write"][0.6, ImageSize -> 320]
```

<!-- => the formula partly written -->

---

A title card on paper:

```wl
AnimatedGraphics[{Backdrop[RGBColor["#F4F1EA"]], TitleCard["Mathematica", {0, 2}, FontColor -> Black]}][1, ImageSize -> 320]
```

<!-- => "Mathematica" in black on off-white -->

---

A drum pattern, rendered for one cycle:

```wl
Track["bd [~ bd] sd ~, hh*8"]["Audio", 1]
```

<!-- => an Audio object of a drum beat -->

---

The same pattern's events in its first half cycle:

```wl
Track["bd [~ bd] sd ~, hh*8"]["Query", 0, 1/2][[All, "Value"]]
```

<!-- => {"bd", "bd", "hh", "hh", "hh", "hh"} -->

## Hero Image

Frames of a film about the Wolfram Language, scenes from Manim's gallery, and a trance loop as a punch card and a piano roll, all made with WAnim:

```wl
Import[PacletObject["WolframInstitute/WAnim"]["AssetLocation", "Hero"]]
```
