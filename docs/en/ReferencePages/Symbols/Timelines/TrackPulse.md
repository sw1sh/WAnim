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

<code>[TrackPulse]()[*track*, *decay*]</code> is a function of time *t* (in cycles) that is 1 at each onset of *track* and decays exponentially, by *decay* per second, until the next.

## Details & Options

- It locks motion to sound: the picture reads the same Track that is heard. [Spikey](), [NotebookSession]() and [YearRuler]() take it through their "Pulse" option.
- The default *decay* is 9 per second.

## Basic Examples

A pulse on each beat, sampled across one:

```wl
$CyclesPerSecond = 1/2; TrackPulse[EventTrack[Table[{b/4, 1/4, "bd"}, {b, 0, 7}]], 9] /@ {0, 0.05, 0.1, 0.2, 0.25}
```

<!-- => {1., 0.41, 0.17, 0.03, 1.} -->

---

Its shape over a bar:

```wl
$CyclesPerSecond = 1/2; Plot[TrackPulse[Track["bd*4"], 9][t], {t, 0, 1}, PlotRange -> {0, 1}]
```

<!-- => four sharp spikes decaying -->
