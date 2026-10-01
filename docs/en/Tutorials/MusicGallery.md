---
Template: TechNote
Name: MusicGallery
Title: The Music Gallery
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/tutorial/MusicGallery
Keywords: [music, Strudel, TidalCycles, mini-notation, live coding, drums, synthesizer, mixing, trance, tutorial]
RelatedGuides: [WAnim]
RelatedTutorials: [ManimGallery]
---

[Strudel](https://strudel.cc) and [TidalCycles](https://tidalcycles.org) write music as patterns in cyclic time: a short string of mini-notation says what happens in one cycle, and functions transform whole patterns at once. WAnim's [Track]() is that idea in the Wolfram Language. A Track is a function of time, asked about any span of cycles; it plays on synthesized [Instrument]()s through a [Mixer](), and the same Track that is heard can be read by a picture.

In a notebook every Track is a live player on one shared clock: click it to play or pause, right-click to mute it, double-click to solo it. Here each is shown as <code>*track*["Video"]</code>: its live view, playing, with its sound, which plays anywhere a [Video]() does.

## Setting Up

The paclet:

```wl
Needs["WolframInstitute`WAnim`"]
```

Tracks play at `$CyclesPerSecond` cycles a second; a cycle is a bar of four beats, and 0.5 cycles a second is 120 beats a minute:

```wl
$CyclesPerSecond = 1/2;
```

## First Sounds

Drum names play the kit: a bass drum and a snare, each taking half the cycle:

```wl
Track["bd sd"]["Video", "View" -> "Punchcard"]
```

<!-- => two bars in a band -->

---

A beat, two cycles:

```wl
Track["bd [~ bd] sd ~, hh*8"]["Video", 2, "View" -> "Punchcard"]
```

## Mini-Notation

A space sequences steps within the cycle, so more steps are faster:

```wl
Track["bd hh sd hh bd bd sd hh"]["Video", "View" -> "Punchcard"]
```

---

Brackets fit a group into one step:

```wl
Track["bd [hh hh] sd [hh hh hh]"]["Video", "View" -> "Punchcard"]
```

---

A comma plays sequences together:

```wl
Track["bd sd, hh hh hh hh"]["Video", "View" -> "Punchcard"]
```

---

Angle brackets take one step per cycle, in turn:

```wl
Track["bd <sd cp> bd <sd [cp cp]>"]["Video", 4, "View" -> "Punchcard"]
```

---

`*` repeats a step faster, `/` slower:

```wl
Track["bd*2 [hh sd]/2"]["Video", 2, "View" -> "Punchcard"]
```

---

`!` replicates a step as steps of its own; `@` weights a step; `_` holds the one before:

```wl
Track["bd!3 sd, hh@3 oh, cp _ _ rim"]["Video", "View" -> "Punchcard"]
```

---

`(k,n)` spreads k hits over n steps as evenly as possible, a Euclidean rhythm, and `~` is a rest:

```wl
Track["bd(3,8), ~ sd, hh(5,8)"]["Video", "View" -> "Punchcard"]
```

## Notes

Note names and MIDI numbers are pitches:

```wl
Track["c4 e4 g4 [b4 c5]"]["Video"]
```

---

A chord is a stack inside brackets; here a progression, one chord a cycle:

```wl
Track["<[c3,eb3,g3] [ab2,c3,eb3] [eb3,g3,bb3] [bb2,d3,f3]>"]["Video", 4]
```

---

[TrackScale]() reads numbers as degrees of a scale:

```wl
TrackScale["c:minor"][Track["0 2 4 <6 7> 4 2 0 -3"]]["Video", 2]
```

## Transforming Patterns

Operations transform whole patterns. [TrackSpeed]() plays faster or slower:

```wl
TrackSpeed[2][Track["c4 e4 g4 b4"]]["Video"]
```

---

Every operation appends itself to the track's mini-notation source, so the result is still text that parses back to the same pattern:

```wl
TrackSpeed[2][Track["c4 e4 g4 b4"]]["Source"]
```

<!-- => "c4 e4 g4 b4 // fast 2" -->

---

[Reverse]() plays each cycle backwards, and [TrackEvery]() applies a function every nth cycle:

```wl
TrackEvery[2, Reverse][Track["c4 e4 g4 b4"]]["Video", 2]
```

---

[TrackShift]() moves a pattern in time; offbeat hats:

```wl
TrackShift[1/8][Track["hh*4"]]["Video", "View" -> "Punchcard"]
```

---

[TrackSuperimpose]() plays a pattern with a transformed copy of itself, here a copy at double speed, a sixteenth later:

```wl
TrackSuperimpose[TrackSpeed[2], 1/16][Track["c4 eb4 g4 c5"]]["Video"]
```

---

[TrackEuclid]() is the Euclidean rhythm as an operation, and [TrackDegrade]() drops a fraction of the events, the same ones every time:

```wl
Track[{TrackEuclid[5, 8][Track["cp"]], TrackDegrade[0.4][Track["hh*16"]]}]["Video", "View" -> "Punchcard"]
```

---

[TrackStruct]() puts a pattern's values on a rhythm:

```wl
TrackStruct["1 ~ ~ 1 ~ ~ 1 ~"][Track["<c3 eb3 ab2 bb2>"]]["Video", 4]
```

---

[TrackSequence]() plays patterns one after another within a cycle, and [TrackAlternate]() one per cycle:

```wl
TrackAlternate[TrackSequence["bd bd", "sd"], "bd*3 sd"]["Video", 2, "View" -> "Punchcard"]
```

## Instruments

A voice plays drum names on the "Kit" and notes on "Sawtooth" unless it is given an [Instrument]():

```wl
Instrument[]
```

---

The synthesized ones: a kick, a clap and a plucked line:

```wl
Track[{Instrument["Kick"][Track["bd*4"]], Instrument["Clap"][Track["~ cp ~ cp"]], Instrument["Pluck"][Track["[a4 c5 e5 g5]*2"]]}]["Video", 2, "View" -> "Punchcard"]
```

---

Options set the gain, the place in the stereo field, the sends to the shared reverb and delay, and a decay in cycles. They are part of the source too:

```wl
Instrument["Bell", "Gain" -> 0.7, "Pan" -> -0.5, "Delay" -> 0.4][Track["e5 ~ b4 ~ g5 ~ ~ e5"]]["Source"]
```

<!-- => "e5 ~ b4 ~ g5 ~ ~ e5 // sound bell // gain 0.7 // pan -0.5 // delay 0.4" -->

---

So the same voice can be written as text:

```wl
Track["e5 ~ b4 ~ g5 ~ ~ e5 // sound bell // gain 0.7 // pan -0.5 // delay 0.4"]["Video"]
```

## A Trance Piece

An original trance loop in C minor, i-VI-III-VII, after the genre's building blocks: four on the floor, a clap on two and four, driving hats, an offbeat bass following the roots, a pad on the chords, an arpeggio, and a lead with a delayed echo.

The chords and their roots:

```wl
chords = Track["<[c4,eb4,g4] [ab3,c4,eb4] [eb4,g4,bb4] [bb3,d4,f4]>"];
roots = Track["<c2 ab1 eb2 bb1>"];
```

---

The voices, each on its instrument:

```wl
kick = Instrument["Kick"][Track["bd*4"]];
trance = Track[{
    kick,
    Instrument["Clap"][Track["~ cp ~ cp"]],
    Instrument["Hat", "Gain" -> 0.8][Track["[~ hh]*4"]],
    Instrument["Bass"][TrackStruct["~ 1 ~ 1 ~ 1 ~ 1"][roots]],
    Instrument["Pad", "Gain" -> 0.8][chords],
    Instrument["Arp", "Pan" -> 0.4][Track["<[c5 eb5 g5 c6 g5 eb5 c5 g5] [c5 eb5 ab5 c6 ab5 eb5 c5 ab5] [eb5 g5 bb5 eb6 bb5 g5 eb5 bb5] [d5 f5 bb5 d6 bb5 f5 d5 bb5]>"]],
    Instrument["Lead", "Delay" -> 0.5][Track["<g5 ab5 [g5 f5] eb5>"]]}];
```

---

Mixed, the music, the bass and the reverb duck under the kick, and the pad opens through a low-pass over the four bars; seen as a punch card of its voices, and the wave:

```wl
Mixer["Sidechain" -> kick, "Cutoff" -> (600 20^(Mod[#, 4] / 4) &)][trance]["Video", 4, "View" -> {"Punchcard", "Oscilloscope"}]
```

## Notation

The same structure as a score:

```wl
Track["<[c4,eb4,g4] [ab3,c4,eb4]> [g4 f4 eb4 d4]"]["MusicPlot", 2]
```

## Pictures That Listen

A picture can read the Track that sounds. [TrackPulse]() is 1 at every onset of a track and decays until the next:

```wl
Plot[TrackPulse[Track["bd*4"], 12][t], {t, 0, 1}, PlotRange -> {0, 1}]
```

---

In an [AnimatedGraphics]() the Track is the sound, and its pulse moves the picture; a disk that swells on the kick:

```wl
g = AnimatedGraphics[{Function[t, {Orange, Disk[{0, 0}, 1 + 0.4 TrackPulse[Track["bd*4"], 12][t]]}], Track["bd*4, ~ cp"]},
    PlotRange -> {{-2, 2}, {-2, 2}}, "Duration" -> 2, "CyclesPerSecond" -> 1/2];
g["Video", FrameRate -> 30]
```

## Strudel Shortcuts

The lowercase names of Strudel live in a context of their own, loaded on request:

```wl
Needs["WolframInstitute`WAnim`Strudel`"]
```

---

Then Strudel code reads almost as it does in Strudel:

```wl
stack[s["bd*4, ~ cp"], note["<c3 eb3 g3 bb3>*2"] // instrument["Bass"], note["c5 eb5 g5 bb5"] // fast[2] // every[2, rev] // gain[0.5]]["Video", 2]
```
