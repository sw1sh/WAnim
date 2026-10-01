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

- "Version" draws the Spikey of that version of Mathematica, as Mathematica drew it: the stellated icosahedron of 1.0 under the colored lights of its time; the hyperbolic dodecahedra of 2 to 6, from the constructions in Michael Trott's Mathematica GuideBook; and from 8 on, those of Trott's SpikeyMaker, from the parameters it kept. The versions whose parameters were not kept are fitted to their pictures.
- The models ship with the paclet; each view Spikey dances through is drawn once and kept on disk, so the first appearance of a version takes a moment.
- "Display" -> "1Bit" or "Gray" draws it as a one-bit or greyscale display would.
- "Version" and "Display" may be functions of time, so one Spikey lives through the eras without restarting its dance.
- "Face" -> True gives it the face of the personified Spikey of "The Story of Spikey": glasses, eyebrows and an open smile; "Raise" (0 to 1) lifts its right hand and "Blink" -> True shuts its eyes happily.
- Position, "Radius", "Dance", "Raise" and "Blink" may be functions of time too, so Spikey can walk, grow and wave.
- "Pulse" -> *track* pulses it on each onset of *track* (see [TrackPulse]()); its centre never moves.

| Option | Default | Description |
| --- | --- | --- |
| "Version" | 15 | the version whose Spikey it is |
| "Display" | Automatic | "1Bit" or "Gray" for old displays |
| "Radius" | 46 | size in pixels |
| "Pulse" | None | a Track to dance to |
| "Dance" | 1 | how strongly it pulses |
| "Face" | False | glasses, eyebrows and a smile |
| "Raise" | 0 | how high the right hand is |
| "Blink" | False | eyes shut |
| Position | {1790, 930} | centre |

## Basic Examples

Spikey version by version, 1988 to 2026:

```wl
Table[Spikey[{0, 2}, "Version" -> v, Position -> {960, 540}, "Radius" -> 300][1, ImageSize -> 120], {v, Range[15]}]
```

<!-- => fifteen Spikeys: the stellated icosahedron, the hyperbolic dodecahedra of lilac, violet, rainbow, gold, orange and reds, then the rhombic Spikeys of 14 and 15 -->

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
Spikey[{0, 4}, "Pulse" -> Track["bd*4"], Position -> {960, 540}, "Radius" -> 300][0.26, ImageSize -> 200]
```

<!-- => Spikey squashed -->

### Face

A face, and a hand going up:

```wl
AnimatedGraphics[{Backdrop[Black, {0, 2}], Spikey[{0, 2}, Position -> {960, 560}, "Radius" -> 260, "Face" -> True, "Raise" -> (Clip[#] &)]},
    "Duration" -> 2][1.2, ImageSize -> 480]
```

<!-- => a red Spikey with eyes and a smile, waving -->
