---
Template: Symbol
Name: NotebookSession
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/NotebookSession
Keywords: [notebook, session, retro, Macintosh, 1-bit, input, output, evaluate, typing, Mathematica 1.0]
SeeAlso: [Terminal, CanvasScreen, OrderedDither, $NotebookEras, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[NotebookSession]()[{*cell*_1, *cell*_2, …}, {$t_0$, $t_1$}]</code> is a notebook window of its era that types and evaluates the cells on the clock.

## Details & Options

- A cell is <code>{*t*, "In", "*code*"}</code>, typed from *t* over "TypeTime", or <code>{*t*, "Out", *output*}</code>, where *output* is text, an [Image]() or [Graphics]().
- In and Out numbers count up automatically. Pictures are rasterized and, on a one-bit display, reduced with [OrderedDither]().
- With "Evaluate" -> True every input also gets its computed output, "OutputDelay" after it has been typed.
- The notebook scrolls so the newest cell stays in view, gliding when one arrives.
- "Era" chooses the look from [$NotebookEras](): "Mac1988" is Mathematica 1.0 on a Macintosh (System 6 chrome, half resolution, one bit).
- "Enter" -> "Burst" grows the window out of its middle; "Pulse" -> *track* punches it on the track's onsets; "PushIn" is a slow zoom across the span.

| Option | Default | Description |
| --- | --- | --- |
| "Era" | "Mac1988" | the notebook's era |
| "Evaluate" | False | compute outputs for inputs |
| "TypeTime" | 0.25 | time to type an input |
| "OutputDelay" | 0.3 | time from typed to evaluated |
| "Title" | "Untitled-1" | window title |
| "Screen" | {88, 176, 1100, 780} | the window rectangle |
| "Enter" | "Burst" | "Burst", "Fade" or "Cut" |
| "Pulse" | None | a Track to punch to |
| "PushIn" | 0.03 | zoom across the span |

## Basic Examples

Mathematica 1.0 listing its vocabulary:

```wl
NotebookSession[{{0, "In", "Names[\"*\"]"}, {0.5, "Out", "{Above, Abs, Accuracy, AccuracyGoal, AddTo, AiryAi, All, And, Apart, Append, AppendTo, Apply, ...}"}}, {0, 2}]["Graphics", 1.5, ImageSize -> 480]
```

<!-- => a 1-bit Mac window with In[1] and Out[1] -->

---

Inputs evaluated as they are typed, graphics dithered to one bit:

```wl
NotebookSession[{{0, "In", "Plot3D[Sin[x y], {x, 0, 3}, {y, 0, 3}]"}}, {0, 2}, "Evaluate" -> True]["Graphics", 1.5, ImageSize -> 480]
```

<!-- => the input and a dithered surface plot under Out[1] -->

---

An input still being typed, with its caret:

```wl
NotebookSession[{{0, "In", "Integrate[1/(x^3 - 1), x]"}}, {0, 2}, "TypeTime" -> 1]["Graphics", 0.5, ImageSize -> 480]
```

<!-- => half the input and a caret -->

## Options

### Enter

The window bursting out of its middle:

```wl
NotebookSession[{{0, "In", "1 + 1"}}, {0, 2}]["Graphics", 0.06, ImageSize -> 480]
```

<!-- => a small window, growing -->
