---
Template: Symbol
Name: Instrument
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Instrument
Keywords: [instrument, synthesizer, drums, samples, kit, kick, pad, lead, bell, voice, gain, pan, reverb, delay, foley, studio]
SeeAlso: [Track, Mixer, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[Instrument]()["*name*"][*track*]</code> plays *track* on an instrument synthesized sample by sample.

<code>[Instrument]()[*opts*][*track*]</code> sets how *track* sounds, keeping its instrument.

<code>[Instrument]()[<|"*name*" -> *audio*, …|>][*track*]</code> and <code>[Instrument]()[[File]()["*dir*"]][*track*]</code> play your own samples, by the events' values.

<code>[Instrument]()[]</code> lists the instruments.

## Details & Options

- "Kit" plays each event's value as a sample of WAnim's own drum kit: "bd", "sd", "cp", "hh", "oh", "cr", "rim", "lt", with the usual aliases ("kick", "snare", "hat", ...). An event whose value is an [Audio]() plays that.
- Synthesized drums and effects: "Kick", "SoftKick", "Clap", "Hat", "OpenHat", "Crash", "Riser" (swells over its note), "Roll" (an accelerating snare roll over its note), "Impact".
- Pitched: "Pluck", "Arp", "Pad", "Bass", "LongBass", "Stab", "Lead" (detuned sawtooths through swept filters), "Bell" (two-operator FM), "Voice" (a sawtooth through three formant filters gliding between vowels), and the plain waves "Sine", "Triangle", "Square", "Sawtooth", "Supersaw".
- Foley: "Tick" (a key press) and "Blip" (a cell evaluating); an [AnimatedGraphics]() with "Foley" -> True plays them for everything it types.
- A voice with no instrument plays drum names on the "Kit" and notes on "Sawtooth".
- The instrument is part of the [Track](): every operation keeps it, and on a stack it applies to every voice. Its mini-notation forms are appended to the source: `// sound pluck`, `// gain 0.5`, `// pan -1`, `// room 0.3`, `// delay 0.4`, `// dec 0.1`.
- Each instrument routes to the drums, music or bass bus and sends to a shared reverb and ping-pong delay; the [Mixer]() sums, ducks, filters and masters them.

| Option | Default | Description |
| --- | --- | --- |
| "Gain" | 1 | level, multiplying any gain already set |
| "Pan" | 0 | stereo place, from -1 (left) to 1 (right) |
| "Reverb" | Automatic | send to the reverb, relative to the dry sound; `Automatic` is the instrument's own |
| "Delay" | Automatic | send to the delay, likewise |
| "Decay" | None | cut every sound to this many cycles |

## Basic Examples

A kick, a clap and a plucked line:

```wl
Audio[Track[{Instrument["Kick"][Track["bd*4"]], Instrument["Clap"][Track["~ cp ~ cp"]], Instrument["Pluck"][Track["[a4 c5 e5 g5]*2"]]}], 2, "CyclesPerSecond" -> 1/2]
```

<!-- => four seconds of a beat under a pluck line -->

---

A bell, and a voice singing:

```wl
Audio[Track[{Instrument["Bell"][Track[{{0, 1/2, 76}, {1/2, 1/2, 81}}]], Instrument["Voice"][Track[{{1, 1, 72}}]]}], 2, "CyclesPerSecond" -> 1/2]
```

<!-- => a bell phrase then a sung vowel -->

## Options

### Gain and Pan

Hats quieter and to the right:

```wl
Instrument["Gain" -> 0.4, "Pan" -> 0.6][Track["hh*8"]]["Source"]
```

<!-- => "hh*8 // gain 0.4 // pan 0.6" -->

### Decay

Short, dry notes:

```wl
Audio[Instrument["Pad", "Decay" -> 1/16, "Reverb" -> 0][Track["c3 e3 g3 c4"]], 1, "CyclesPerSecond" -> 1/2]
```

<!-- => four clipped pad notes -->
