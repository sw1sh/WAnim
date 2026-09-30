---
Template: Symbol
Name: AutomatonTape
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/AutomatonTape
Keywords: [cellular automaton, Rule 30, tape, melody, sonification, read head]
SeeAlso: [CellularAutomaton, Track, Spikey, TrackPulse]
RelatedGuides: [WAnim]
---

## Usage

<code>[AutomatonTape]()[*rule*, *track*, {$t_0$, $t_1$}]</code> draws [CellularAutomaton]()[*rule*] turned on its side and fed into a read head, naming the note *track* plays under the head.

## Details & Options

- Each vertical slice is one row of the automaton grown from a single cell, "Rows" cells tall around the centre; "StepsPerUnit" rows pass the head per timeline unit.
- The centre column is drawn in "BitColor" (1) or outlined (0), in groups of "Group"; the last cell of each group is a dot.
- *track* is the [Track]() read from the automaton, the one that sounds: its note under the head is named above the head. Use `None` for a tape without notes.

| Option | Default | Description |
| --- | --- | --- |
| "Rows" | 13 | slice height in cells |
| "CellSize" | 8 | cell size in pixels |
| "StepsPerUnit" | 32 | rows per timeline unit |
| "Group" | 4 | cells per group |
| "Length" | 400 | visible length in pixels |
| "Label" | Automatic | the caption over the tape |
| Position | {1712, 930} | the read head |

## Basic Examples

Rule 30 flowing into a head in the middle of the frame:

```wl
AutomatonTape[30, None, {0, 4}, Position -> {1200, 540}, "CellSize" -> 16, "Length" -> 800][2, ImageSize -> 480]
```

<!-- => a sideways Rule 30 band ending at a red line -->

---

With a Track, the note under the head is named:

```wl
AutomatonTape[30, Track["a4 c5 e5 g5"], {0, 4}, Position -> {1200, 540}, "CellSize" -> 16, "Length" -> 800][2.1, ImageSize -> 480]
```

<!-- => the tape with a note name above the head -->

## Scope

Other rules:

```wl
Table[AutomatonTape[r, None, {0, 4}, Position -> {1600, 540}, "CellSize" -> 12, "Rows" -> 41, "Length" -> 1400, "Label" -> "RULE " <> ToString[r]][3, ImageSize -> 240], {r, {90, 110}}]
```

<!-- => two tapes: the Sierpinski pattern of Rule 90 and the structures of Rule 110 -->
