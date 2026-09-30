---
Template: Symbol
Name: TrackView
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/TrackView
Keywords: [piano roll, punch card, oscilloscope, live view, visualization, playhead, solo]
SeeAlso: [Track, TrackPlay, TrackPause, TrackSeek]
RelatedGuides: [WAnim]
RelatedTutorials: [MusicGallery]
---

## Usage

<code>[TrackView]()["*view*", …, *opts*][*track*]</code> sets what *track* shows while it plays.

<code>*track*["PianoRoll", *n*]</code> and <code>*track*["Punchcard", *n*]</code> are still views of *n* cycles.

## Details & Options

- Views: "PianoRoll" (the default: a block per note, the playhead moving across), "Punchcard" (the events scrolling past a fixed line), "Oscilloscope" (the sound's waveform), "Bar" (a progress bar). Several stack in a column.
- All tracks play on one clock: [TrackPlay](), [TrackPause]() and [TrackSeek]() act on every one, and a track that appears joins at the clock's position.
- Styling options go to the views: [FontSize](), [Background](), [ImageSize](), [AspectRatio](), "BlockColor", "PlayheadColor", "GridColor".

| Option | Default | Description |
| --- | --- | --- |
| "Cycles" | Automatic | cycles shown and looped; `Automatic` is its voices' longest, else 2 |
| "Solo" | False | silence every other playing track when it appears |
| "Buttons" | False | play, pause, mute and solo buttons |

## Basic Examples

A punch card of four cycles:

```wl
TrackView["Punchcard", "Cycles" -> 4][Track["bd [~ bd] sd ~, hh*8, <c3 eb3 g3 bb3>"]]["Punchcard"]
```

<!-- => the events of four cycles as bars in three bands -->

---

A still piano roll:

```wl
Track["<[c4,e4,g4] [a3,c4,e4]>"]["PianoRoll", 2]
```

<!-- => two chords of three blocks -->
