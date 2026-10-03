---
Template: Guide
Name: WAnim
Title: WAnim
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/guide/WAnim
Description: Live audiovisual coding: films as animated graphics built from creation tools, drawn with a canvas kit, scored with cyclic-time music patterns
Keywords: [animation, motion graphics, timeline, live coding, music, patterns, Strudel, TidalCycles, video, kinetic typography, retro computing, Manim]
RelatedTutorials: [ManimGallery, MusicGallery]
---

## Abstract

WAnim (a homage to Manim) makes films and live audiovisual pieces in the Wolfram Language. A piece is
an AnimatedGraphics: Graphics with a time axis, holding primitives, functions of time over spans and
other AnimatedGraphics, written one creation tool per segment -- a typewriter line, a caption, a terminal of 1979, a notebook of 1988 typing and evaluating
on the clock, a dictionary card for a symbol, a dancing Spikey. The same structure is shown live,
rendered to stills, or rendered to a Video in parallel. Its soundtrack is a Track, a Strudel-style
pattern of cyclic time, and the picture can query the very Track that sounds: a kick that makes
Spikey hop, the melody an automaton tape reads out. Underneath is a canvas-style drawing kit that
places text exactly where a browser canvas would, so designs port from web tools line by line.

## Functions

### Animated graphics: a film, a scene and an object are one thing

- `AnimatedGraphics` Graphics with a time axis: primitives, <code>{t0, t1} -> x</code> spans, functions of time, nested AnimatedGraphics and a Track for sound; a queue of effects; a frame at any time, a live player, an AnimatedImage, a Video, an Audio, or an mp4 rendered in parallel
- `AnimationEffect` an effect as a function of time: creation, transforms, fades
- `BraceLabel` a curly brace spanning an object, with a label
- `Backdrop` a solid fill of the canvas, a colour or a function of time
- `TrackPulse` a decaying pulse on every onset of a Track, to lock motion to sound
- `Easing` the standard easing curves (OutCubic, InOutExpo, OutBack, ...)

### Words on screen

- `Typewriter` text typed on the clock behind a blinking cursor, words lighting up afterwards
- `TitleCard` display type that rises, pops, fades or arrives letter by letter
- `CaptionText` a sentence arriving word by word on a beat grid, wrapped to a column
- `DictionaryCard` a Wolfram Language symbol as a dictionary entry, its usage and version looked up live

### Screens of an era

- `TerminalSession` a green-phosphor terminal that powers on, types a session, prints and powers off
- `NotebookSession` a notebook window of its era, typing and evaluating cells on the clock
- `NotebookEra` a notebook era as a value: chrome, cell style and display, from 1988 to 2024
- `CanvasScreen` a scene drawn at an old display's resolution and depth, placed by a canvas rectangle
- `OrderedDither` a picture reduced to one bit with 4x4 Bayer dithering

### Cards and instruments

- `PhotoPrint` a photo or scan pinned like a print, tilted, with a kicker and a caption
- `NumberCounter` a number that counts and flashes while it changes, with a label
- `YearRuler` a ruler of years whose marker jumps from date to date, with release ticks
- `WordWall` a whole vocabulary laid out like a dictionary page, each word arriving at its time

### Motion: Manim-style scenes

- `Tween` a value over time: eased from one value to another, or through keyframes (Manim's ValueTracker)
- `Morph` one shape turning into another (Manim's Transform)
- `PartialPath` a shape's outline drawn part way (Manim's Create)

### Diagrams

- `TreeDiagram` an expression's tree growing from its head down, level by level
- `TileGrid` cards dealt out on the beat, each a plot or picture, the animated ones looping
- `WordScroll` a family of names rolling up the frame like credits

### Characters

- `Spikey` the Wolfram mascot in each of its forms, dancing to a Track
- `AutomatonTape` a cellular automaton fed sideways into a read head, naming the notes a Track plays from it

### Drawing: the canvas kit

- `CanvasTransform`, `CanvasTranslate`, `CanvasScale`, `CanvasRotate` nested transforms, as a canvas context
- `CanvasOpacity` nested opacity, like globalAlpha
- `CanvasRectangle`, `CanvasPolygon`, `CanvasLine`, `CanvasDisk` shapes: filled, stroked, rounded
- `CanvasImage` an image into a rectangle, stretched or contained
- `CanvasGradient` a colour fading across a rectangle
- `CanvasClip` drawing confined to a rectangle
- `CanvasFont`, `CanvasText`, `CanvasTextWidth`, `CanvasWrap` text on its baseline, measured and wrapped the way a canvas does
- `TypedText` the part of a text typed by a given fraction of the way through
- `CanvasTeX`, `CanvasTeXWidth` TeX on the canvas: formulas, or text with mathematics inline, as glyph outlines

### Drawing in depth

- `CanvasCamera` a perspective camera; `CanvasCloud`, `CanvasCurve3D`, `CanvasSurface3D`, `CanvasSphere3D` points, paths, lit surfaces and spheres seen through it, drawn as canvas primitives

### Documentary film

- `ArchiveClip` archival film in a film: its picture, its voice with the music ducked beneath, subtitles, the speaker's name
- `GPUGraphics` a frame drawn on the GPU, without the front end

### Music: tracks in cyclic time

- `Track` a pattern of events: mini-notation ("bd [~ bd] sd, hh*8"), events written out note by note, a query function, or a stack of voices; a live player in the notebook
- `TrackSpeed`, `TrackShift`, `TrackSequence`, `TrackAlternate` time: speed, shift, one after another within a cycle, one per cycle
- `TrackEvery`, `TrackEuclid`, `TrackDegrade`, `TrackSuperimpose`, `TrackStruct`, `TrackScale` structure: every nth cycle, Euclidean rhythms, random drops, echoes, rhythm masks, scale degrees
- `TrackPulse` a decaying pulse on every onset of a Track, to lock motion to sound
- `$CyclesPerSecond` the tempo of live tracks

### The studio

- `Instrument` how a voice sounds: the drum kit or your samples, synthesized drums, pads, leads, a bell, a singing voice, plain waves, key clicks; its gain, pan, sends and decay
- `Mixer` how a track is mixed: sidechain, an automated low-pass, the delay and reverb, the master

### Playing live

- `TrackView` what a playing track shows: a piano roll, a scrolling punch card, an oscilloscope; how many cycles it loops, solo
- `TrackPlay`, `TrackPause`, `TrackSeek` one clock for every playing track
- `$AudioLatency` the delay between the clock and the sound, to keep pictures on the beat
