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

- "Version" draws Spikey as that version of Mathematica drew it: the stellated icosahedron of 1.0 in four colours; from 2 to 12 the concave "hyperbolic dodecahedron", lilac in 2, glassy violet in 3, rainbow in 4, gold in 5, the reds and oranges of 6 to 11 and the grey of 12; from 13 the red Wolfram Spikey of <code>[PolyhedronData]()["WolframSpikey"]</code>.
- "Form" -> "Stellated", "Hyperbolic" or "Wolfram" overrides the shape; "Display" -> "1Bit" or "Gray" draws it as a one-bit or greyscale display would.
- "Version" and "Style" may be functions of time, so one Spikey lives through the eras without restarting its dance.
- "Face" -> True gives it eyes, a smile, arms and legs; "Raise" (0 to 1) lifts its right hand and "Blink" -> True shuts its eyes.
- Position, "Radius", "Dance", "Raise" and "Blink" may be functions of time too, so Spikey can walk, grow and wave.
- "Pulse" -> *track* squashes it and pushes its spikes out on each onset of *track* (see [TrackPulse]()); "BeatsPerCycle" sets the sway.

| Option | Default | Description |
| --- | --- | --- |
| "Version" | 15 | the version whose Spikey it is |
| "Form" | Automatic | "Stellated", "Hyperbolic" or "Wolfram" |
| "Style" | Automatic | "1Bit" or "Gray" for old displays |
| "Radius" | 46 | size in pixels |
| "Pulse" | None | a Track to dance to |
| "BeatsPerCycle" | 4 | sway beats per timeline unit |
| "Dance" | 1 | how much it moves |
| "Face" | False | eyes, a smile, arms and legs |
| "Raise" | 0 | how high the right hand is |
| "Blink" | False | eyes shut |
| Position | {1790, 930} | centre |

## Basic Examples

Spikey version by version, 1988 to 2026:

```wl
Table[Spikey[{0, 2}, "Version" -> v, Position -> {960, 540}, "Radius" -> 300][1, ImageSize -> 120], {v, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15}}]
```

<!-- => thirteen Spikeys: the four-colour stellated icosahedron, then concave spiky balls in lilac, violet, rainbow, gold, reds and oranges and grey, then the flat red Wolfram Spikey -->

---

The first Spikey as the displays of 1988 showed it:

```wl
Table[Spikey[{0, 2}, "Version" -> 1, "Display" -> s, Position -> {960, 540}, "Radius" -> 300][1, ImageSize -> 120], {s, {"1Bit", "Gray", Automatic}}]
```

<!-- => three stellated icosahedra: one-bit, grey and in colour -->

## Options

### Pulse

Dancing to a kick drum Track, just after a kick:

```wl
Spikey[{0, 4}, "Pulse" -> EventTrack[Table[{b / 4, 1 / 4, "bd"}, {b, 0, 15}]], Position -> {960, 540}, "Radius" -> 300][0.26, ImageSize -> 200]
```

<!-- => Spikey squashed, its spikes extended -->

### Face

A face, and a hand going up:

```wl
AnimatedGraphics[{Backdrop[Black, {0, 2}], Spikey[{0, 2}, Position -> {960, 560}, "Radius" -> 260, "Face" -> True, "Raise" -> (Clip[#] &)]},
    "Duration" -> 2][1.2, ImageSize -> 480]
```

<!-- => a red Spikey with eyes and a smile, waving -->
