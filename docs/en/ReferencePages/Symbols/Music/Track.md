---
Template: Symbol
Name: Track
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Track
Keywords: [pattern, mini-notation, Strudel, TidalCycles, live coding, rhythm, sequencer, cycle]
SeeAlso: [Instrument, Mixer, TrackView, TrackSpeed, TrackShift, TrackEuclid, TrackPulse, AnimatedGraphics]
RelatedGuides: [WAnim]
RelatedTutorials: [MusicGallery]
---

## Usage

<code>[Track]()["*mini-notation*"]</code> is a cyclic pattern of events, such as <code>[Track]()["bd [~ bd] sd, hh*8"]</code>.

<code>[Track]()[{{*onset*, *duration*, *value*}, …}]</code> plays exactly those events, in cycles; a fourth element is the velocity.

<code>[Track]()[{*track*_1, *track*_2, …}]</code> stacks voices, each on its own instrument.

<code>[Track]()[]</code> is silence.

## Details & Options

- Time is in cycles, exact rationals. A Track is a function of time: asked about any span, it answers with the events in it.
- Mini-notation, after Strudel: a space sequences steps within a cycle; `[ ]` groups a step; `,` plays sequences together; `< >` takes one per cycle; `*n` repeats faster, `/n` slower; `!n` replicates a step; `@n` weights it; `_` holds the previous step; `(k,n)` is a Euclidean rhythm; `~` is a rest.
- Values are drum names ("bd", "sd", "hh", "cp", "oh", "cr", "rim", "lt"), note names ("c4", "eb2", "f#3") or MIDI numbers, [MusicPitch]() and [MusicChord]() too.
- Operations: [TrackSpeed](), [TrackShift](), [Reverse](), [TrackSequence](), [TrackAlternate](), [TrackEvery](), [TrackEuclid](), [TrackDegrade](), [TrackSuperimpose](), [TrackStruct](), [TrackScale](). On a stack they apply to every voice.
- A track remembers its mini-notation source, and every operation appends to it: <code>[TrackSpeed]()[2][[Track]()["bd sd"]]</code> is <code>[Track]()["bd sd // fast 2"]</code>. Its TraditionalForm is that source, editable, each atom lighting up as it sounds.
- It plays on [Instrument]()s and is mixed by the [Mixer](): drum names on the "Kit", notes on "Sawtooth", unless an instrument is given.
- In a notebook a Track shows itself as a live player on a shared clock: left-click plays and pauses every track, right-click mutes this one, a double-click solos it. [TrackView]() sets what it shows.
- <code>[Audio]()[*track*, *n*]</code> renders *n* cycles, by default its "Cycles", at `"CyclesPerSecond" -> $CyclesPerSecond`. [MusicPlot]() and [Sound]() give it as notation.
- <code>*track*["Video", *n*]</code> and <code>[Video]()[*track*, *n*]</code> render its live view playing with its sound, a player that works anywhere a [Video]() does; "View" picks the views ([TrackView]()), "Theme" is "Dark" or "Light", with [FrameRate]() and [ImageSize]().
- <code>*track*["Query", *a*, *b*]</code> gives the events between cycles *a* and *b*, <code>*track*["Onsets", *a*, *b*]</code> those that start there; "Voices", "Source" and "Cycles" read its parts.

## Basic Examples

A drum pattern:

```wl
Track["bd [~ bd] sd ~, hh*8"]["Query", 0, 1/2][[All, "Value"]]
```

<!-- => {"bd", "~", "hh", "hh", "hh", "hh"} -->

---

Rendered for a cycle at 120 BPM:

```wl
Audio[Track["bd [~ bd] sd ~, hh*8"], 1, "CyclesPerSecond" -> 1/2]
```

<!-- => two seconds of a drum beat -->

---

Its live view, playing, as a video:

```wl
Track["bd [~ bd] sd ~, hh*8"]["Video", 2, "View" -> "Punchcard", "CyclesPerSecond" -> 1/2]
```

<!-- => a video of a scrolling punch card with the beat -->

---

A melody written out note by note, with velocities:

```wl
Track[{{0, 1/2, "c4", 1}, {1/2, 1/4, "e4", 0.6}, {3/4, 1/4, "g4", 0.8}}]["PianoRoll"]
```

<!-- => three blocks climbing -->

## Scope

Operations append to the source, so the result is still editable text:

```wl
TrackEvery[2, Reverse][TrackSpeed[2][Track["c4 e4 g4 b4"]]]["Source"]
```

<!-- => "c4 e4 g4 b4 // fast 2 // every 2 rev" -->

---

The source parses back to the same pattern:

```wl
Track["bd sd // fast 2"]["Query", 0, 1] === TrackSpeed[2][Track["bd sd"]]["Query", 0, 1]
```

<!-- => True -->

---

A stack of voices, each on its instrument:

```wl
Track[{Instrument["Kick"][Track["bd*4"]], Instrument["Pluck"][Track["<c4 e4> g4 [a4 c5]"]]}]["Voices"] // Length
```

<!-- => 2 -->

---

Notation:

```wl
MusicPlot[Track["c4 e4 g4 [a4 b4]"]]
```

<!-- => a bar of notes on a staff -->
