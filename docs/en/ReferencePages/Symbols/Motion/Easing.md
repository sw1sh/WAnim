---
Template: Symbol
Name: Easing
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Easing
Keywords: [easing, tween, interpolation, ease in, ease out, overshoot, animation curve]
SeeAlso: [AnimationEffect, AnimatedGraphics, TitleCard]
RelatedGuides: [WAnim]
---

## Usage

<code>[Easing]()["*name*"]</code> is the named easing curve, a function from [0, 1] to [0, 1].

<code>[Easing]()["OutBack", *s*]</code> overshoots by *s* before settling.

## Details & Options

- The names are "Linear", "InCubic", "OutCubic", "InOutCubic", "InExpo", "OutExpo", "InOutExpo", "OutBack", "OutElastic" and "Smooth"; `Easing["Names"]` lists them.
- Arguments outside [0, 1] are clamped. The names also work as the "Rate" of an [AnimationEffect]().

## Basic Examples

The value of OutCubic halfway:

```wl
Easing["OutCubic"][0.5]
```

<!-- => 0.875 -->

---

All the curves:

```wl
Plot[Evaluate[Easing[#][u] & /@ Easing["Names"]], {u, 0, 1}, PlotLegends -> Easing["Names"], PlotRange -> All]
```

<!-- => ten curves from 0 to 1, OutBack and OutElastic overshooting -->

---

A stronger overshoot:

```wl
Plot[{Easing["OutBack"][u], Easing["OutBack", 3][u]}, {u, 0, 1}]
```

<!-- => two curves, the second rising higher before settling -->
