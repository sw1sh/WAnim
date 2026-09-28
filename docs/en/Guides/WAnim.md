---
Template: Guide
Name: WAnim
Title: WAnim
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/guide/WAnim
Description: Live audiovisual coding: films as timelines of creation tools, drawn with a canvas kit, scored with cyclic-time music patterns
Keywords: [animation, motion graphics, timeline, live coding, music, patterns, Strudel, TidalCycles, video, kinetic typography, retro computing, Manim]
---

## Abstract

WAnim (a homage to Manim) makes films and live audiovisual pieces in the Wolfram Language. A piece is a
Timeline: a list of layers, each a pure function of time over a span, written one creation tool per
segment -- a typewriter line, a caption, a terminal of 1979, a notebook of 1988 typing and evaluating
on the clock, a dictionary card for a symbol, a dancing Spikey. The same structure is shown live,
rendered to stills, or rendered to a Video in parallel. Its soundtrack is a Track, a Strudel-style
pattern of cyclic time, and the picture can query the very Track that sounds: a kick that makes
Spikey hop, the melody an automaton tape reads out. Underneath is a canvas-style drawing kit that
places text exactly where a browser canvas would, so designs port from web tools line by line.

## Functions

### Timelines: a film as a list of layers

- `Timeline` a stack of layers over time, shown live (clocked by its soundtrack), as a frame, or rendered to a Video
- `TimelineLayer` one segment: a span and a function drawing it at time t; every creation tool returns one
- `Backdrop` a solid fill of the canvas, a colour or a function of time
- `$LayerOptions` the options every creation tool shares: Position, fonts, "Enter" and "Exit"
- `EventTrack` a written-out score (onset, duration, value) as a Track
- `TrackPulse` a decaying pulse on every onset of a Track, to lock motion to sound
- `Easing` the standard easing curves (OutCubic, InOutExpo, OutBack, ...)

### Words on screen

- `Typewriter` text typed on the clock behind a blinking cursor, words lighting up afterwards
- `Title` display type that rises, pops, fades or arrives letter by letter
- `Caption` a sentence arriving word by word on a beat grid, wrapped to a column
- `DictionaryCard` a Wolfram Language symbol as a dictionary entry, its usage and version looked up live

### Screens of an era

- `Terminal` a green-phosphor terminal that powers on, types a session, prints and powers off
- `NotebookSession` a notebook window of its era, typing and evaluating cells on the clock
- `$NotebookEras` the registry of notebook eras: chrome, cell style and display
- `CanvasScreen` a scene drawn at an old display's resolution and depth, placed by a canvas rectangle
- `RasterScreen` the same, placed by a rectangle in graphics coordinates
- `OrderedDither` a picture reduced to one bit with 4x4 Bayer dithering

### Cards and instruments

- `PhotoPrint` a photo or scan pinned like a print, tilted, with a kicker and a caption
- `Counter` a number that counts and flashes while it changes, with a label
- `YearRuler` a ruler of years whose marker jumps from date to date, with release ticks
- `WordWall` a whole vocabulary laid out like a dictionary page, each word arriving at its time

### Characters

- `Spikey` the Wolfram mascot in each of its forms, dancing to a Track
- `AutomatonTape` a cellular automaton fed sideways into a read head, naming the notes a Track plays from it

### Drawing: the canvas kit

- `CanvasBlock` a fresh canvas of a given size: its own coordinates, transform and opacity
- `CanvasTransform`, `CanvasTranslate`, `CanvasScale`, `CanvasRotate` nested transforms, as a canvas context
- `CanvasOpacity` nested opacity, like globalAlpha
- `CanvasRectangle`, `CanvasPolygon`, `CanvasLine`, `CanvasDisk` shapes: filled, stroked, rounded
- `CanvasImage` an image into a rectangle, stretched or contained
- `CanvasGradient` a colour fading across a rectangle
- `CanvasClip` drawing confined to a rectangle
- `CanvasFont`, `CanvasText`, `CanvasTextWidth`, `CanvasWrap` text on its baseline, measured and wrapped the way a canvas does
- `TypedText` the part of a text typed by a given fraction of the way through
- `$CanvasSize`, `$CanvasFixedAdvance` the canvas being drawn and the monospace faces pinned to canvas advances

### Music: cyclic-time patterns

- `Track` a pattern: mini-notation ("bd [~ bd] sd, hh*8"), a query function, or a stack of voices
- `Silence`, `Steady` the empty pattern and a constant one
- `Fast`, `Slow`, `Late`, `Early`, `Fastcat` time: speed, shift, concatenation
- `Layer`, `Alternate`, `Every`, `Euclidean`, `Degrade`, `Stagger`, `Superimpose` structure: stack, alternate, every n cycles, Euclidean rhythms, random drops, echoes
- `Beat`, `Struct`, `InScale`, `$Scales` rhythm and pitch helpers after Strudel
- `Synth`, `Gain`, `Pan`, `Delay`, `Room`, `Dec`, `Duck` sound: oscillators, level, stereo, effects, sidechain
- `$DrumKit`, `LoadSamples`, `$SampleBank` the built-in synthesized drum kit, and your own samples
- `$CyclesPerSecond`, `$DefaultWave`, `Bars`, `Solo` tempo, default timbre, display length, soloing

### Live playback

- `TrackPlay`, `TrackPause`, `TrackSeek`, `TrackReset` one transport for every playing Track
- `PianoRoll`, `Punchcard`, `Oscilloscope` live views of a Track
- `LiveCode`, `$DefaultVisual`, `$AudioLatency`, `$LiveAtomHeads` live-coding display and synchronization

### Animated objects

- `AnimatedObject` Manim-style objects: primitives plus a queue of effects, rendered live, as images or as video
- `AnimationEffect` an effect as a function of time: creation, transforms, fades
- `Brace` a curly brace spanning an object
