---
Template: Symbol
Name: TreeDiagram
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/TreeDiagram
Keywords: [tree, expression tree, FullForm, grammar, heads, diagram, grow]
SeeAlso: [ExpressionTree, TreeForm, FullForm, Title, Timeline]
RelatedGuides: [WAnim]
---

## Usage

<code>[TreeDiagram]()[*expr*, {$t_0$, $t_1$}]</code> is a layer growing the tree of *expr* from the top: heads above their arguments, a level at a time.

## Details & Options

- Hold the expression to keep it unevaluated: <code>[TreeDiagram]()[[Hold]()[{x -> 1, f[y]}], {$t_0$, $t_1$}]</code>.
- Heads are set in "HeadColor", leaves in FontColor, in a monospaced face. Each node pops in as the edge from its parent is drawn down to it.
- Levels arrive "LevelInterval" apart; nodes within a level, "NodeInterval" apart.
- Position is the root; the leaves spread evenly over "Width", and each head sits over the middle of its arguments.

| Option | Default | Description |
| --- | --- | --- |
| Position | {1330, 250} | the root |
| "Width" | 500 | the spread of the leaves |
| "LevelHeight" | 130 | from one level to the next |
| "LevelInterval" | 1/4 | time between levels |
| "NodeInterval" | 1/20 | time between nodes of a level |
| "HeadColor" | red | colour of heads |
| FontSize | 38 | size of leaves; heads are a little larger |

## Basic Examples

The grammar under a list:

```wl
TreeDiagram[Hold[{x -> 1, f[y]}], {0, 2}, Position -> {960, 300}]["Graphics", 1.5, ImageSize -> 480]
```

<!-- => List over Rule and f, over x, 1 and y -->

---

Half grown:

```wl
TreeDiagram[Hold[a + b c], {0, 2}, Position -> {960, 300}]["Graphics", 0.3, ImageSize -> 480]
```

<!-- => Plus and its first arguments arriving -->

## Scope

A deeper expression, with its own spacing:

```wl
TreeDiagram[Hold[Integrate[Sin[x]^2, {x, 0, Pi}]], {0, 2}, Position -> {960, 200}, "Width" -> 900, "LevelHeight" -> 110, FontSize -> 30]["Graphics", 1.9, ImageSize -> 480]
```

<!-- => Integrate over Power and List, down to x, 0 and Pi -->
