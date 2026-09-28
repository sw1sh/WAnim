---
Template: Symbol
Name: YearRuler
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/YearRuler
Keywords: [year, ruler, timeline, history, marker, release]
SeeAlso: [Counter, TrackPulse, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[YearRuler]()[{{$t_1$, $y_1$}, {$t_2$, $y_2$}, …}, {$t_0$, $t_1$}]</code> is a ruler of years along the bottom of the frame whose marker jumps to year $y_i$ at time $t_i$.

## Details & Options

- The marker glides to each year with an exponential ease; a red line runs from the first year to the marker.
- "Marks" -> {{*year*, "*label*"}, …} places ticks that appear once the marker has passed them.
- "Pulse" -> *track* makes the marker beat on the track's onsets (see [TrackPulse]()).

| Option | Default | Description |
| --- | --- | --- |
| "Range" | {1978, 2027} | the years the ruler spans |
| "Every" | 5 | spacing of the labelled years |
| "Marks" | {} | release ticks {year, label} |
| "Pulse" | None | a Track to beat to |
| Position | Automatic | left end of the ruler; `Automatic` is along the bottom |

## Basic Examples

The marker travelling from 1979 to 1988:

```wl
YearRuler[{{0, 1979.85}, {1, 1988.47}}, {0, 3}, "Marks" -> {{1988.47, "1.0"}}]["Graphics", 2, ImageSize -> 480]
```

<!-- => a ruler with the red line to 1988 and a "1.0" tick -->

---

Halfway through the jump:

```wl
YearRuler[{{0, 1979.85}, {1, 2007.33}}, {0, 3}]["Graphics", 1.05, ImageSize -> 480]
```

<!-- => the marker moving through the 2000s -->
