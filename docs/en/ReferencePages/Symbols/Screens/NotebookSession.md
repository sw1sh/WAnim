---
Template: Symbol
Name: NotebookSession
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/NotebookSession
Keywords: [notebook, session, retro, Macintosh, NeXT, Windows, dark mode, 1-bit, input, output, evaluate, typing, Mathematica 1.0]
SeeAlso: [Terminal, CanvasScreen, OrderedDither, NotebookEra, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[NotebookSession]()[{*cell*_1, *cell*_2, …}, {$t_0$, $t_1$}]</code> is a notebook window of its era that types and evaluates the cells on the clock.

## Details & Options

- Cells:
  - <code>{*t*, "In", "*code*"}</code> is typed from *t* over "TypeTime"; <code>{*t*, "In", "*code*", *typeTime*}</code> sets its own.
  - <code>{*t*, "Out", *output*}</code>: text is set in the era's output font, an [Image]() as is, and any other expression as the front end displays it (graphics in every era; other expressions as [OutputForm]() text before 2007).
  - <code>{*t*, "Out", *u* |-> *expr*, *dur*}</code> is an animated output: *expr* at *u* going from 0 to 1 over *dur*, rendered once as "Frames" pictures (a moving slider, a rotating surface).
  - <code>{*t*, "Title", "*text*"}</code> and <code>{*t*, "Text", "*text*"}</code> are the notebook's own prose.
- In and Out numbers count up automatically. On a one-bit display pictures are reduced with [OrderedDither](); in dark eras expressions are displayed in dark mode.
- With "Evaluate" -> True every input also gets its computed output, "OutputDelay" after it has been typed.
- The notebook scrolls so the newest cell stays in view, gliding when one arrives.
- "Era" is the look: a name from <code>[NotebookEra]()[]</code> or a [NotebookEra]() association. Since 6.0 inputs are syntax-coloured.
- "Enter" -> "Burst" grows the window out of its middle; "Enter" -> "Wipe" with "From" -> *previous* wipes the new era down over the last frame of the *previous* session, as one window living through its eras.
- "Pulse" -> *track* punches the window on the track's onsets; "PushIn" is a slow zoom across the span; "Dim" -> {$t_a$, $t_b$} shrinks and darkens it between the two times; "Exit" -> "FlyAway" flies it at the viewer over "ExitTime".

| Option | Default | Description |
| --- | --- | --- |
| "Era" | "Mac1988" | the notebook's era |
| "Evaluate" | False | compute outputs for inputs |
| "TypeTime" | 0.25 | time to type an input |
| "OutputDelay" | 0.3 | time from typed to evaluated |
| "Title" | "Untitled-1" | window title |
| "Screen" | {88, 176, 1100, 780} | the window rectangle |
| "Enter" | "Burst" | "Burst", "Wipe", "Fade" or "Cut" |
| "From" | None | the session a "Wipe" starts from |
| "Dim" | None | a span over which the window recedes |
| "Frames" | 24 | pictures in an animated output |
| "Extras" | Automatic | the era's extras (None hides them) |
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

---

An output animated over one unit, the way a Manipulate slider moves:

```wl
NotebookSession[{{0, "In", "Plot[Sin[a x], {x, 0, 6}]"}, {0.3, "Out", a |-> Plot[Sin[(1 + 2 a) x], {x, 0, 6}, ImageSize -> 260], 1}}, {0, 2}, "Era" -> "BigSur2020", "Enter" -> "Cut"]["Graphics", 0.8, ImageSize -> 480]
```

<!-- => a sine plot part-way through its sweep -->

## Options

### Enter

The window bursting out of its middle:

```wl
NotebookSession[{{0, "In", "1 + 1"}}, {0, 2}]["Graphics", 0.06, ImageSize -> 480]
```

<!-- => a small window, growing -->

---

One window from 1991 into 1996, wiped down:

```wl
With[{a = NotebookSession[{{0, "In", "1 + 1"}}, {0, 1}, "Era" -> "Win1991", "Evaluate" -> True, "Enter" -> "Cut"]},
    NotebookSession[{{1, "In", "2 + 2"}}, {1, 2}, "Era" -> "Win1996", "Enter" -> "Wipe", "EnterTime" -> 0.1, "From" -> a]["Graphics", 1.05, ImageSize -> 480]]
```

<!-- => Windows 95 chrome over the top half, Windows 3.1 below -->
