---
Template: Symbol
Name: NumberCounter
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/NumberCounter
Keywords: [counter, number, HUD, statistic, count up]
SeeAlso: [YearRuler, TitleCard, AnimatedGraphics]
RelatedGuides: [WAnim]
---

## Usage

<code>[NumberCounter]()[*f*, {$t_0$, $t_1$}]</code> shows the number *f*[*t*] at time *t*, flushed right in the top-right corner, flashing "ChangeColor" while it changes.

## Details & Options

- Numbers are shown with digit blocks of three by default; "Format" is any function from the number to a string.
- "Label" adds a small tracked line under the number.

| Option | Default | Description |
| --- | --- | --- |
| "Label" | None | a line under the number |
| "Format" | Automatic | a function formatting the number |
| "ChangeColor" | red | colour while the value is changing |
| Position | Automatic | `Automatic` is the top-right corner |
| FontSize | 88 | size in canvas pixels |

## Basic Examples

A count of words, climbing to 554 over a second:

```wl
NumberCounter[Round[554 Min[1, #]] &, {0, 2}, "Label" -> "Words in the language"][1.5, ImageSize -> 480]
```

<!-- => 554 in the top-right corner with the label under it -->

---

While it climbs it turns red:

```wl
NumberCounter[Round[6801 Min[1, #]] &, {0, 2}][0.5, ImageSize -> 480]
```

<!-- => 3,401 in red -->

## Options

### Format

A percentage:

```wl
NumberCounter[Round[100 Min[1, #]] &, {0, 2}, "Format" -> (ToString[#] <> "%" &)][1.5, ImageSize -> 480]
```

<!-- => 100% -->
