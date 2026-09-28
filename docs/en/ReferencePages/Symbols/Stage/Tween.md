---
Template: Symbol
Name: Tween
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Tween
Keywords: [tween, keyframes, interpolation, value tracker, easing, animation]
SeeAlso: [Easing, Stage, Morph, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[Tween]()[{*a*, *b*}]</code> is a function of time going from 0 to 1 between *a* and *b*, held before and after.

<code>[Tween]()[{*a*, *b*}, {*x*, *y*}]</code> goes from *x* to *y*: numbers, points or colours.

<code>[Tween]()[{{$t_1$, $v_1$}, {$t_2$, $v_2$}, …}]</code> moves through keyframes, each move eased, holding between them.

## Details & Options

- The easing is [Easing]()["Smooth"] by default, Manim's rate; give another as the last argument, such as "Linear", "OutBack" or {"OutBack", 2}.
- Keyframes are Manim's ValueTracker and its animations as one value: <code>[Tween]()[{{1, 110}, {2, 40}, {3, 180}}]</code> holds 110 until 1, moves to 40 by 2 and to 180 by 3.
- Colours are blended with [Blend]().

## Basic Examples

A value rising over a second:

```wl
Tween[{0, 1}] /@ {-1, 0, 0.25, 0.5, 1, 2}
```

<!-- => {0, 0, 0.104, 0.5, 1, 1} -->

---

Keyframes:

```wl
Plot[Tween[{{1, 110}, {2, 40}, {3, 180}}][t], {t, 0, 4}]
```

<!-- => a step curve through 110, 40 and 180 -->

---

A colour, bouncing in:

```wl
Tween[{0, 1}, {Blue, Orange}, "OutBack"] /@ {0.2, 0.5, 1}
```

<!-- => three swatches from blue to orange -->
