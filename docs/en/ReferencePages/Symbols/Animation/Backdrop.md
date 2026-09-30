---
Template: Symbol
Name: Backdrop
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Backdrop
Keywords: [background, fill, backdrop, colour]
SeeAlso: [AnimatedGraphics, CanvasRectangle]
RelatedGuides: [WAnim]
---

## Usage

<code>[Backdrop]()[*colour*]</code> fills the whole canvas with *colour* at all times.

<code>[Backdrop]()[*f*]</code> fills it with the colour *f*[*t*] at time *t*.

<code>[Backdrop]()[*c*, {$t_0$, $t_1$}]</code> is on only from $t_0$ to $t_1$.

## Details & Options

- Colours can be any colour directive or a hex string such as `"#F4F1EA"`.
- Like every element it takes "Enter" and "Exit" ("Cut" by default, or "Fade" over "EnterTime" and "ExitTime") and an [Opacity](), which may be a function of time.

## Basic Examples

A paper-coloured canvas:

```wl
Backdrop[RGBColor["#F4F1EA"]][0, ImageSize -> 240]
```

<!-- => a plain warm off-white frame -->

---

A colour that changes over time, from paper to ink:

```wl
Table[Backdrop[Blend[{RGBColor["#F4F1EA"], RGBColor["#0E0F11"]}, #] &][t, ImageSize -> 100], {t, 0, 1, 0.25}]
```

<!-- => five frames fading from off-white to near black -->

---

A red wash fading in over a second, at half strength:

```wl
AnimatedGraphics[{Backdrop[Black], Backdrop[Red, {0, 2}, "Enter" -> "Fade", "EnterTime" -> 1, Opacity -> 0.5]}][0.5, ImageSize -> 160]
```

<!-- => a dark red frame -->
