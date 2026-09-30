---
Template: Symbol
Name: TrackPulse
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/TrackPulse
Keywords: [pulse, beat, sync, kick, audio-reactive, envelope]
SeeAlso: [Track, EventTrack, Spikey, NotebookSession, YearRuler]
RelatedGuides: [WAnim]
---

## Usage

<code>[TrackPulse]()[*track*, *decay*]</code> is a function of time *t* (in cycles) that is 1 at each onset of *track* and decays exponentially, by *decay* per cycle, until the next.

## Details & Options

- It locks motion to sound: the picture reads the same Track that is heard. [Spikey](), [NotebookSession]() and [YearRuler]() take it through their "Pulse" option.
- The default *decay* is 18 per cycle.
- An [AnimatedGraphics]()'s unit is one cycle, so the pulse is read at the same times as the layers; the tempo is the timeline's "SecondsPerUnit".

## Basic Examples

A pulse on each beat, sampled across one:

```wl
TrackPulse[EventTrack[Table[{b/4, 1/4, "bd"}, {b, 0, 7}]], 18] /@ {0, 0.05, 0.1, 0.2, 0.25}
```

<!-- => {1., 0.41, 0.17, 0.03, 1.} -->

---

Its shape over a bar:

```wl
Plot[TrackPulse[Track["bd*4"], 18][t], {t, 0, 1}, PlotRange -> {0, 1}]
```

<!-- => four sharp spikes decaying -->
