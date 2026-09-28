---
Template: Symbol
Name: EventTrack
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/EventTrack
Keywords: [score, events, notes, track, linear time, transcription]
SeeAlso: [Track, TrackPulse, Synth, Gain, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[EventTrack]()[{{*onset*_1, *duration*_1, *value*_1}, …}]</code> is a [Track]() that plays exactly these events, with times in cycles.

## Details & Options

- Use it for a score written out note by note rather than as a repeating pattern: a film score, a transcription.
- A value is a MIDI number, a pitch such as `"A4"`, or a drum name such as `"bd"` (see [$DrumKit]()).
- Queries clip each event to the queried span and keep its whole extent, so onsets, [TrackPulse](), piano rolls and [Audio]() behave as for any other Track.

## Basic Examples

Three notes in the first cycle and a half:

```wl
EventTrack[{{0, 1/2, 60}, {1/2, 1/2, 64}, {1, 1, 67}}]["Query", 0, 1]
```

<!-- => two events with values 60 and 64 and their whole and part spans -->

---

A kick on every beat of two bars, as audio:

```wl
$CyclesPerSecond = 1/2; Audio[EventTrack[Table[{b/4, 1/4, "bd"}, {b, 0, 7}]], 2]
```

<!-- => a 4-second Audio of eight kicks -->

---

Voices of a written-out score mixed as one Track:

```wl
$CyclesPerSecond = 1/2; Audio[Track[{Synth["Triangle"][EventTrack[{{0, 1/2, 69}, {1/2, 1/2, 72}, {1, 1, 76}}]], Gain[0.5][EventTrack[{{0, 1/4, "bd"}, {1, 1/4, "bd"}}]]}], 2]
```

<!-- => a short phrase over two kicks -->
