---
Template: Symbol
Name: Spikey
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Spikey
Keywords: [Spikey, mascot, polyhedron, stellated icosahedron, rhombic hexecontahedron, dance]
SeeAlso: [PolyhedronData, TrackPulse, AutomatonTape]
RelatedGuides: [WAnim]
---

## Usage

<code>[Spikey]()[{$t_0$, $t_1$}]</code> is the Wolfram mascot, dancing: spinning, swaying each beat and hopping.

## Details & Options

- "Form" follows the versions: "Stellated" (the stellated icosahedron of 1.0), "Spiked" (a spiked dodecahedron, versions 2 to 9) or "Hexecontahedron" (the rhombic hexecontahedron, 10 onward). Geometry comes from [PolyhedronData]().
- "Style" follows the displays: "1Bit", "Gray", "Classic" (lilac) or "Red".
- "Form" and "Style" may be functions of time, so one Spikey lives through the eras without restarting its dance.
- "Face" -> True gives it eyes, a smile, arms and legs; "Raise" (0 to 1) lifts its right hand and "Blink" -> True shuts its eyes.
- Position, "Radius", "Dance", "Raise" and "Blink" may be functions of time too, so Spikey can walk, grow and wave.
- "Pulse" -> *track* squashes and pumps the spikes on each onset of *track* (see [TrackPulse]()); "BeatsPerUnit" sets the sway.

| Option | Default | Description |
| --- | --- | --- |
| "Form" | "Stellated" | "Stellated", "Spiked" or "Hexecontahedron" |
| "Style" | "Red" | "1Bit", "Gray", "Classic" or "Red" |
| "Radius" | 46 | size in pixels |
| "Pulse" | None | a Track to dance to |
| "BeatsPerUnit" | 4 | sway beats per timeline unit |
| "Dance" | 1 | how much it moves |
| "Face" | False | eyes, a smile, arms and legs |
| "Raise" | 0 | how high the right hand is |
| "Blink" | False | eyes shut |
| Position | {1790, 930} | centre |

## Basic Examples

Spikey in each of its forms:

```wl
Table[Spikey[{0, 2}, "Form" -> f, Position -> {960, 540}, "Radius" -> 300]["Graphics", 1, ImageSize -> 160], {f, {"Stellated", "Spiked", "Hexecontahedron"}}]
```

<!-- => three Spikeys: a stellated icosahedron, a spiked dodecahedron, a hexecontahedron -->

---

And in each style:

```wl
Table[Spikey[{0, 2}, "Style" -> s, Position -> {960, 540}, "Radius" -> 300]["Graphics", 1, ImageSize -> 120], {s, {"1Bit", "Gray", "Classic", "Red"}}]
```

<!-- => four stellated icosahedra: one-bit, grey, lilac and red -->

## Options

### Pulse

Dancing to a kick drum Track, just after a kick:

```wl
Spikey[{0, 4}, "Pulse" -> EventTrack[Table[{b / 4, 1 / 4, "bd"}, {b, 0, 15}]], Position -> {960, 540}, "Radius" -> 300]["Graphics", 0.26, ImageSize -> 200]
```

<!-- => Spikey squashed, its spikes extended -->

### Face

A face, and a hand going up:

```wl
Timeline[{Backdrop[Black, {0, 2}], Spikey[{0, 2}, Position -> {960, 560}, "Radius" -> 260, "Form" -> "Hexecontahedron", "Face" -> True, "Raise" -> (Clip[#] &)]},
    "Duration" -> 2]["Graphics", 1.2, ImageSize -> 480]
```

<!-- => a red Spikey with eyes and a smile, waving -->
