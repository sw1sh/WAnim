---
Template: Symbol
Name: $DrumKit
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/$DrumKit
Keywords: [drums, samples, kick, snare, hi-hat, clap, crash, drum kit]
SeeAlso: [Track, LoadSamples, $SampleBank, EventTrack]
RelatedGuides: [WAnim]
---

## Usage

<code>[$DrumKit]()</code> is WAnim's built-in drum kit, an association from names to [Audio]().

## Details & Options

- The kit is bd (kick), sd (snare), cp (clap), hh (closed hi-hat), oh (open hi-hat), cr (crash), rim and lt (low tom); every sound is synthesized, so the kit ships with the paclet as its "Drums" asset.
- Drum names in a [Track]() play from the kit; aliases such as "kick", "snare", "clap", "hat" and "crash" map to it, and a name loaded with [LoadSamples]() takes precedence.

## Basic Examples

The names in the kit:

```wl
Keys[$DrumKit]
```

<!-- => {"bd", "cp", "cr", "hh", "lt", "oh", "rim", "sd"} -->

---

The kick:

```wl
$DrumKit["bd"]
```

<!-- => an Audio object about half a second long -->

---

A beat that uses the kit:

```wl
$CyclesPerSecond = 1/2; Audio[Track["bd [~ bd] sd ~, hh*8, ~ ~ ~ cp"], 2]
```

<!-- => a 4-second drum loop -->
