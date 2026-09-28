---
Template: Symbol
Name: Backdrop
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/Backdrop
Keywords: [background, fill, backdrop, colour]
SeeAlso: [Timeline, TimelineLayer, CanvasRectangle]
RelatedGuides: [WAnim]
---

## Usage

<code>[Backdrop]()[*colour*]</code> is a layer filling the whole canvas with *colour* at all times.

<code>[Backdrop]()[*f*]</code> fills it with the colour *f*[*t*] at time *t*.

<code>[Backdrop]()[*c*, {$t_0$, $t_1$}]</code> is on only from $t_0$ to $t_1$.

## Details & Options

- A colour given directly in a [Timeline]() layer list is a Backdrop.
- Colours can be any colour directive or a hex string such as `"#F4F1EA"`.

## Basic Examples

A paper-coloured canvas:

```wl
Backdrop[RGBColor["#F4F1EA"]]["Graphics", 0, ImageSize -> 240]
```

<!-- => a plain warm off-white frame -->

---

A colour that changes over time, from paper to ink:

```wl
Table[Backdrop[Blend[{RGBColor["#F4F1EA"], RGBColor["#0E0F11"]}, #] &]["Graphics", t, ImageSize -> 100], {t, 0, 1, 0.25}]
```

<!-- => five frames fading from off-white to near black -->

---

In a timeline a colour is a backdrop:

```wl
Timeline[{Red}, "Duration" -> 1]["Graphics", 0.5, ImageSize -> 160]
```

<!-- => a red frame -->
