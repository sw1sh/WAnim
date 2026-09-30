---
Template: Symbol
Name: Mixer
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Mixer
Keywords: [mixer, sidechain, ducking, low-pass, filter, master, limiter, reverb, delay]
SeeAlso: [Instrument, Track, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[Mixer]()[*opts*][*track*]</code> sets how a [Track]() of [Instrument]()s is mixed.

## Details & Options

- "Sidechain" -> *kick* ducks the music (by 0.55), the bass (0.8) and the reverb (0.35) under each onset of *kick*.
- "Cutoff" -> *f* runs the music bus through a low-pass at *f*[*cycle*] Hz: a filter the music opens and closes.
- The sends go through a ping-pong delay ("DelayTime" in cycles, "DelayFeedback") and a Freeverb reverb.
- "Master" -> True high-passes the rumble, saturates softly and limits; "FadeOut" fades the last seconds.

| Option | Default | Description |
| --- | --- | --- |
| "Sidechain" | None | a track to duck under |
| "Cutoff" | None | the music bus low-pass, a function of the cycle |
| "DelayTime" | 3/16 | the delay, in cycles |
| "DelayFeedback" | 0.42 | its feedback |
| "Master" | True | saturation and limiting |
| "FadeOut" | 2.5 | seconds faded at the end |

## Basic Examples

A pad pumping under a kick, its filter opening over two cycles:

```wl
With[{kick = EventTrack[Table[{b/4, 1/4, "bd"}, {b, 0, 7}]]},
    Audio[Mixer["Sidechain" -> kick, "Cutoff" -> (300 40^(#/2) &)][Track[{Instrument["Kick"][kick], Instrument["Pad"][EventTrack[{{0, 2, 57}, {0, 2, 60}, {0, 2, 64}}]]}]], 2, "CyclesPerSecond" -> 1/2]]
```

<!-- => a pad breathing with the kick, brightening -->
