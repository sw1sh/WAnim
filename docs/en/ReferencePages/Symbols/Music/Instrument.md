---
Template: Symbol
Name: Instrument
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Instrument
Keywords: [instrument, synthesizer, drums, kick, pad, lead, bell, voice, foley, studio]
SeeAlso: [Mixer, Track, EventTrack, Synth, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[Instrument]()["*name*"][*track*]</code> is a voice playing the events of *track* on an instrument synthesized sample by sample.

<code>[Instrument]()[]</code> lists the instruments.

## Details & Options

- Drums and effects: "Kick", "SoftKick", "Clap", "Hat", "OpenHat", "Crash", "Riser" (swells over its note), "Roll" (an accelerating snare roll over its note), "Impact".
- Pitched: "Pluck", "Arp", "Pad", "Bass", "LongBass", "Stab", "Lead" (detuned sawtooths through swept filters), "Bell" (two-operator FM), "Voice" (a sawtooth through three formant filters gliding between vowels).
- Foley: "Tick" (a key press) and "Blip" (a cell evaluating); a [Timeline]() with "Foley" -> True plays them for everything it types.
- Notes are MIDI numbers or names; an [EventTrack]() event {*onset*, *duration*, *value*, *velocity*} sets its velocity (default 1).
- A [Track]() of instruments is mixed through drums, music and bass buses with a shared reverb and ping-pong delay, and mastered; [Mixer]() sets the sidechain, an automated low-pass and the master.
- Each instrument has its own routing and sends, like a patch on a mixing desk.

## Basic Examples

A kick, a clap and a plucked line, two cycles:

```wl
Audio[Track[{Instrument["Kick"][EventTrack[Table[{b/4, 1/4, "bd"}, {b, 0, 7}]]], Instrument["Clap"][EventTrack[{{1/4, 1/4, "cp"}, {3/4, 1/4, "cp"}, {5/4, 1/4, "cp"}, {7/4, 1/4, "cp"}}]],
    Instrument["Pluck"][EventTrack[Table[{s/8, 1/8, {69, 72, 76, 79}[[Mod[s, 4] + 1]], 0.5 + 0.4 Boole[EvenQ[s]]}, {s, 0, 15}]]]}], 2, "CyclesPerSecond" -> 1/2]
```

<!-- => four seconds of a beat under a pluck line -->

---

A bell, and a voice singing:

```wl
Audio[Track[{Instrument["Bell"][EventTrack[{{0, 1/2, 76}, {1/2, 1/2, 81}}]], Instrument["Voice"][EventTrack[{{1, 1, 72}}]]}], 2, "CyclesPerSecond" -> 1/2]
```

<!-- => a bell phrase then a sung vowel -->
