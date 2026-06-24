# The Animation-as-Code Landscape, and the Design Patterns WolfAnim Should Adopt

A survey of programmatic animation systems — the Manim lineage, web/video motion engines, FRP and live-coding pattern languages — written for the WolfAnim maintainer. WolfAnim already occupies a strong point in the design space: its `AnimatedObject["Update", T]` is a *pure function of time* (a `FoldWhile` over a per-object effect list), giving it the seekability and exportability that Remotion and Reanimate sell as core advantages. The argument here is that the highest-leverage evolution is to keep that purity while lifting time out of the object: from a per-object effect **queue** toward a shared, scrubbable **transport** plus reactive **signals** and a cyclic **pattern** layer, so that one clock drives both visuals and WL 15.0 Computational Music.

---

## 1. WolfAnim today, in one paragraph

A WolfAnim scene is `AnimatedObject[<|"Primitives", "Directive", "Effects", "GraphicsOptions"|>]`: WL graphics primitives (which may recursively nest other `AnimatedObject`s) plus an ordered **list** of `AnimationEffect`s. An `AnimationEffect` is the record `<|"Function", "Duration", "Reverse", "Rate"|>` where `"Function"` maps `<|"Object", "t", "T"|>` to a new `Object`. The defaults are `"Duration" -> 1, "Reverse" -> False, "Rate" -> "Linear"`, and `animationRateFunction` ships exactly three named curves — `"Linear" -> #&`, `"Quadratic" -> #^2 &`, `"Exponential" -> Exp[#]/E &` — but also accepts any `_Function` (all confirmed in `WolfAnim/AnimationEffect.m`). Playback is a **pull/sample** model: `obj["Update", T]` does

```wolfram
(obj : AnimatedObject[data_])["Update", T_ : 0] := First @ FoldWhile[{
    #1[[1]][#2, T - #1[[2]], T],
    #1[[2]] + #2["Duration"]} &,
  {obj["MapPrimitives", ReplaceAll[o_AnimatedObject :> o["Update", T]]], 0},
  data["Effects"], #[[2]] < T &]
```

walking the effect list, accumulating a local clock offset (`offset += effect.Duration`) and feeding each effect its local `t = T - offset`. The per-effect application clamps forward time via `Min[t, eff["Duration"]]` and, when `"Reverse"` is set, flips it to `Max[eff["Duration"] - t, 0]` (`AnimatedObject.m`). Sequential composition is this accumulation; **parallel** composition is `AnimationEffect[{eff1, eff2, ...}]`, which folds several effects at the *same* `t` and takes `Max` of their durations. Live preview is `dynamicGraphics`, a `DynamicModule[..., Dynamic[Refresh[..., TrackedSymbols :> {t}, UpdateInterval -> Infinity]]]` driven by `t = AbsoluteTime[] - begin` (wall-clock), with a `MouseDown` handler that resets to the start; export is `Video[VideoGenerator[obj["Update", #]["Render", PlotRange -> bounds] &, obj["Duration"], opts], Appearance -> "Minimal"]`. Crucially, `VideoGenerator`'s native `"Audio"` channel is **not** wired up — `["Video"]` passes only the image function.

This is, almost exactly, **Manim's `Animation.interpolate(alpha)` model expressed declaratively and purely** — but without Manim's `Scene`-level transport, and without any reactive layer.

---

## 2. The Manim lineage in depth

### 2.1 manimlib / ManimGL (3b1b) vs Manim Community Edition

Manim is an imperative, retained-mode 2D/3D engine whose data model is the **Mobject** tree: every visual is a node holding a `points` numpy array plus a `submobjects` list (the recursive "family"), so groups (`Group`/`VGroup`) are just nodes whose children are their members and transforms recurse for free ([Manim CE deep dive](https://docs.manim.community/en/stable/guides/deep_dive.html)). The dominant subclass is the vectorized **VMobject**, whose geometry is a flat array of 3D points styled per-vertex so two shapes can be linearly interpolated after padding to equal length (`align_points`/`align_data`).

The two forks differ at the geometry level in a way that matters for any morph/alignment design:

| | ManimCE (default, cairo) | ManimGL (3b1b, OpenGL) |
|---|---|---|
| Bézier degree | **cubic**, 4 points per curve (anchor, handle, handle, anchor) | **quadratic**, 3 points per curve (anchor, handle, anchor) |
| Storage | flat point array sliced in groups of 4 | flat point array sliced as `points[2i : 2i+3]`; consecutive curves **share an endpoint**, so N points encode (N−1)/2 curves |
| Renderer | cairo raster (default); also ships an OpenGL `OpenGLVMobject` (quadratic) | OpenGL-first, custom GLSL, winding-number fill |
| Liveness | offline render; optional preview window | real-time window + `Scene.embed()` IPython REPL |

[[VMobject docs]](https://docs.manim.community/en/stable/reference/manim.mobject.types.vectorized_mobject.VMobject.html), [[ManimGL VMobject (DeepWiki)]](https://deepwiki.com/3b1b/manim/2.2-vmobject-and-vectorized-graphics). The cubic-vs-quadratic split is **confirmed**, with the precision that both forks store a *flat* array sliced in fixed-size groups rather than fully separate tuples, and ManimGL's quadratic curves share endpoints. `Scene.embed()` ([3b1b/manim](https://github.com/3b1b/manim)) is the closest existing thing to live coding in the Manim family and is the spiritual precedent for WolfAnim's `Dynamic`-hosted live editing.

### 2.2 The `Scene` and the frame-loop (the push/mutate model)

Manim's central abstraction is the **`Scene`**: the user subclasses it and writes an imperative `construct(self)`, calling `self.add/remove`, `self.play(*animations, run_time=, rate_func=, lag_ratio=)`, and `self.wait(t)`. The time model is **frame-index based, not wall-clock**: each `play()` computes a frame count from `run_time * fps`, and per frame computes a normalized `alpha`, then calls `Animation.interpolate(alpha)`, which **mutates** mobject points in place, then runs attached updaters, then the camera rasterizes ([Animation reference](https://docs.manim.community/en/stable/reference/manim.animation.animation.Animation.html)). Precisely, `interpolate(alpha)` delegates to `interpolate_mobject(alpha)`, whose `get_sub_alpha()` applies `rate_func` to a lag-adjusted alpha (so the reshaping happens in `get_sub_alpha`, not literally inside `interpolate`). This is a **push/mutate** loop — the architectural opposite of WolfAnim's **pull/pure-T** sampling, and the one thing *not* to copy.

### 2.3 Mapping Manim concepts onto WolfAnim: HAS vs MISSING

| Manim concept | What it is | WolfAnim status |
|---|---|---|
| Mobject family tree | recursive geometry + submobjects | **HAS** — `AnimatedObject` nests `AnimatedObject`s in `Primitives`, recurses via `MapPrimitives`/`o_AnimatedObject :> o["Update", T]` |
| `interpolate(alpha)`, `alpha ∈ [0,1]` | normalized progress reshaped by `rate_func` | **HAS** — `rate[#t/duration]` in every effect |
| `rate_func` catalog | `smooth`, `there_and_back`, full `ease_*` family | **PARTIAL** — only Linear/Quadratic/Exponential shipped; arbitrary `_Function` already accepted, so porting the catalog is trivial |
| `Create`/`pointwise_become_partial` | grow stroke 0→α along the path | **HAS** — `creationEffect` `Method -> "Partial"` calls `#Object["Partial", 0, Ramp[rate[#t/duration]]]`, slicing a discretized `MeshRegion` (`AnimationEffect.m`); `Method -> "Gradient"` mirrors `Write` via a `LinearGradientFilling` sweep |
| **`Scene`** + transport | retained scene + global play loop | **MISSING** — no scene object, no shared clock; each `dynamicGraphics` re-derives `t` from its own `AbsoluteTime[]` |
| **`ValueTracker`** | invisible mobject holding a scalar that updaters read | **MISSING** — no reactive scalar; `Update[T]` is a closed fold over baked effects |
| **updaters / `always_redraw`** | per-frame stateful rebuild `mob.become(func())` | **MISSING** — every effect is a closed-form function of its own `t`; no "react to other objects / audio" hook |
| **`.animate`** sugar | records method calls, builds a `Transform` to the resulting copy | **MISSING** — and worth skipping its sharp edge: it interpolates *endpoints only* (a 180° rotation degenerates) |
| **`Transform`** + identity matching | morph A→B by interpolating padded point arrays | **MISSING** — the single biggest *animation-type* gap; needs an `align_points`-style region/mesh resampling step. Note Manim's own pain: with no semantic correspondence, dissimilar shapes morph as "point soup," hence `TransformMatchingShapes`/`TransformMatchingTex` heuristics |
| `lag_ratio` / `LaggedStart` | stagger sub-animations by a scalar | **MISSING** — high value for music sync (stagger N objects to hits) |

`always_redraw` is implemented by attaching an updater that calls `mob.become(func())` every frame, and `ValueTracker` stores its real number *in its points array* so it animates like any mobject ([updaters](https://docs.manim.community/en/stable/reference/manim.animation.updaters.mobject_update_utils.html), [ValueTracker](https://docs.manim.community/en/stable/reference/manim.mobject.value_tracker.ValueTracker.html)). These two — a tracker bound to an external clock/beat, and an `always_redraw`-style effect — are the bridge to audio-reactive visuals.

### 2.4 `lag_ratio`: the staggering design decision worth copying

`lag_ratio` is the fraction of one sub-animation that elapses before the next begins (0 = simultaneous, 1 = fully sequential). The **confirmed** design decision: staggering does **not** extend the group's total `run_time` — the Manim CE docs state "This does not influence the total runtime of the animation. Instead the runtime of individual animations is adjusted so that the complete animation has the defined run time" ([AnimationGroup](https://docs.manim.community/en/stable/reference/manim.animation.composition.AnimationGroup.html)).

The mechanism is **not** `squish_rate_func` (a common misconception; `squish_rate_func` is a real Manim utility but is used elsewhere, e.g. composing rate functions, not in `AnimationGroup`). CE builds a timing table via `build_animations_with_timings()` producing `(anim, start, end)` triplets: `lags = run_times[:-1] * lag_ratio`, `start[1:] = accumulate(lags)`, `end = start + run_times`, recording `max_end_time = max(end)`. If `run_time` is unspecified it becomes `max_end_time`; otherwise `interpolate()` maps the alpha that sweeps `0→1` over the actual `run_time` onto the internal timeline via `anim_group_time = rate_func(alpha) * max_end_time`, then each active sub-animation gets `sub_alpha = (anim_group_time - start) / run_time`. The "compression" is emergent from traversing an internal timeline of length `max_end_time` over the wall-clock `run_time`. The same no-squish approach holds in ManimGL (default `run_time = max_end_time`).

Important caveat for copying it: because lag shifts start times, the duration is `max` over staggered **end** times, which can exceed any single child's duration — not a naive `Max` of child durations (which is exactly what WolfAnim's parallel fold currently takes). When `run_time` *is* specified, that exact value is used and the staggered timeline is rescaled to fit it.

---

## 3. Cross-system comparison

The decisive axis everywhere is **how time is represented and advanced**. Five clusters emerge: frame-as-pure-function, timeline/transport, generator-flow, stateful frame loop, and pattern-as-query-of-time.

| System | Language | Time model | Media model | Composition model | Declarative-ness |
|---|---|---|---|---|---|
| **Manim CE/GL** | Python (+GLSL) | frame-index; per-anim `alpha∈[0,1]` reshaped by `rate_func`; push/mutate loop | retained Mobject tree (Bézier point arrays), visual only | `AnimationGroup`/`Succession`/`LaggedStart(lag_ratio)` | mid — animations are values but `construct()` is imperative side-effects |
| **Motion Canvas** | TypeScript | generator-flow; `yield` = "frame ready, advance & resume"; **no random-access seek** (replays from scene start) | retained node graph; props are signals | `all`/`any`/`chain`/`sequence`/`loop` | low-mid — imperative script, reactive signals |
| **Remotion** | TS/React | **frame-as-pure-function** of integer frame via `useCurrentFrame()`; O(1) seek; renders frames independently/out of order | React/DOM/SVG → headless Chromium; `<Audio>` on same frame clock | `<Sequence from=>` offsets child frames; `<Series>` | high — frame N depends only on N |
| **Theatre.js** | TS (+Studio editor) | transport: one `sequence.position` playhead, scrubbable, decoupled from wall clock | media-agnostic typed props pushed via `onValuesChange` | one sequence/sheet; keyframes interpolated at position | high (data) but keyframes often GUI-authored |
| **Reanimate** | Haskell (SVG) | `Animation = Duration + (Time∈[0,1] → SVG)`; `Signal = Double→Double` via `signalA` | SVG trees; `mapA :: (SVG→SVG)→Animation→Animation` | `seqA`/`parA`/`andThen` with `Sync = Stretch∣Loop∣Drop∣Freeze`; `Scene` monad | **high** — pure value algebra + reified imperative layer |
| **Fran / FRP** | Haskell | `Behavior a` denotes `Time → a` (continuous) via `at`; `Event` switching | `ImageB = Behavior Image`; `over`, lifted ops, `integral` | applicative lifting + `untilB`/`switcher` | **highest (denotational)** |
| **p5 / Processing** | Java/JS | stateful frame loop; ambient `frameCount`/`millis()`/`deltaTime` | immediate-mode 2D (nothing retained) + WEBGL retained path | procedural draw-call order | **low** — animation = mutation over the loop |
| **Three.js** | JS (WebGL) | render loop (`Clock` delta) + declarative `AnimationClip` in **seconds**; `Mixer.update(δ)` interpolates | retained scene graph; `KeyframeTrack` bound to property paths | `AnimationAction` loop/weight/`crossFadeTo` | mid — clips are data, but mixer carries mutable playback state |
| **GSAP Timeline** | JS | **transport**: retained playhead, `seek()`/`timeScale()`/`reverse()`, labels, nested timelines | property-value engine (any object) | position params (`+=`,`<`,`>`,labels), `stagger` | low-mid — imperative but scrubbable |
| **WL `Animate`/`Manipulate`** | WL | bound parameter sweep (`Animate`) / interaction-driven (`Manipulate`); no timeline | re-evaluates `expr[u]` per value | none (single parameter) | high (declarative) but not a director |
| **WL `Dynamic`/`Clock`** | WL | pull-based reactive graph; `Clock[{min,max},t]` = native cyclic sawtooth 0→1/period | any expression, re-rendered on dep change | dependency graph (`TrackedSymbols`) | high — true reactive substrate |
| **WL `VideoGenerator`** | WL | frame-pull `time → image`; **native dual `Image`+`Audio` channel** on one timeline (experimental) | pure frame fn + audio fn, muxed | none (export contract) | high (but offline) |
| **Desmos / GeoGebra** | JS API / GGBScript | reactive expression graph; animated **sliders** + global **ticker** (Desmos) ≈ cyclic clock | declarative expression list / constraint geometry | dependency recompute | high (no director/easing/audio) |

Notes on the load-bearing cells. Motion Canvas scenes are JS generators (`GeneratorScene.reset()` builds a fresh generator); `PlaybackManager.seek(frame)` resets the containing scene to its `firstFrame` and steps `while (this.frame < frame && !this.finished) this.finished = await this.next()`, i.e. O(distance-from-scene-start), with durations discovered by simulating playback (`recalculate()`). A forward seek can jump across already-cached scenes (`findBestScene()`), but within the target scene it must step the generator frame-by-frame — there is genuinely no O(1) seek ([GeneratorScene](https://motioncanvas.io/api/core/scenes/GeneratorScene/), [flow](https://motioncanvas.io/docs/flow/)). Remotion has **no animation engine** and discourages CSS transitions — "Always animate using `useCurrentFrame()`" — because it "renders each frame independently… Frame 30 might be rendered before frame 10, or frame 50 might be rendered twice" ([useCurrentFrame](https://www.remotion.dev/docs/use-current-frame), [animating-properties](https://www.remotion.dev/docs/animating-properties)); this is *frame-deterministic and seekable* (true cross-machine pixel-identity is not a guarantee Remotion makes, given GPU/font/antialiasing variance). Three.js `AnimationClip`/`KeyframeTrack` times are in **seconds** and the clip is reusable/immutable while playback state lives in `AnimationAction` ([Clock](https://threejs.org/docs/pages/Clock.html)). `Clock[{vmin,vmax},t]` is a repeating **sawtooth** ramp (jumps back at period end), and `Clock[vals,t,n]` runs `n` cycles then holds `vmax` — a free bounded cyclic clock, but it only advances inside `Dynamic`/`Manipulate` ([Clock](https://reference.wolfram.com/language/ref/Clock.html)). `VideoGenerator[<|"Image"->…,"Audio"->…|>, dur]` is **experimental** and syncs by absolute time on a shared timeline; the image and audio specs are independent, with `dur` (commonly `Duration[audio]`) setting total length ([VideoGenerator](https://reference.wolfram.com/language/ref/VideoGenerator.html)).

### 3.1 The pattern-as-query bridge (Tidal / Strudel)

TidalCycles and Strudel sit slightly outside the table because they animate *events*, but they share WolfAnim's deepest property. A **Pattern is a pure function** — in Strudel literally `query: State -> [Hap]`, where the `State` wraps the query `TimeSpan` (rational `Fraction` begin/end) plus a `controls` dict. A **`Hap`** carries a `value`, a `part` TimeSpan, and an **optional `whole`** TimeSpan — continuous *signals* (sine, saw) are exactly the Haps with `whole === undefined`, so one type unifies easing curves and discrete drum hits ([Strudel internals](https://strudel.cc/technical-manual/internals/), [Tidal: what is a pattern](https://tidalcycles.org/docs/innards/what_is_a_pattern/)). Time is **rational** and measured in **cycles**, decoupled from wall clock; tempo is **CPS** (cycles-per-second), default 0.5625 in classic Tidal (= ~135 BPM at 4 beats/cycle), ~0.5 in Strudel ([cycles](https://tidalcycles.org/docs/reference/cycles/)). (Note: as of current Tidal source the hardcoded default has shifted to 0.575; the docs still say 0.5625.) Combinators are query rewriters: `withQuerySpan` transforms the input span, `withHapSpan`/`fmap` (a.k.a. `withValue`) the outputs, `splitQueries` cuts at cycle boundaries; `stack` = parallel, `cat`/`slowcat` = concat over cycles, `fast`/`slow` = scale the span, plus `every`, `degradeBy`, Euclidean `e(3,8)`. The control operator `#` is exactly an alias of `|>` (keep left structure/onsets, take right values), part of a `|+|`/`|+`/`+|` family that routes which side supplies structure vs. values. This is **structurally identical to Fran's `Behavior` denotation `Time → a` and to WolfAnim's `Update[T]`** — the conceptual hinge of the whole survey: *media as a pure, samplable function of time*.

---

## 4. Core design patterns and trade-offs

### 4.1 `render(t)` (pure-function-of-time) vs per-frame updaters

The denotational ideal makes animation a **total function of time**, so scrubbing, reversal, and time-warping (`later`, `timeTransform`) fall out for free ([Fran tutorial](http://conal.net/fran/tutorial.htm), [the morning paper on Fran](https://blog.acolyer.org/2015/12/07/fran/)). Precision: Fran's paper (Elliott & Hudak, ICFP 1997) does *not* define `Behavior a = Time -> a` as a type synonym. `Behavior` and `Event` are mutually recursive abstract polymorphic types; `Time → a` is the **denotation**, formalized by `at :: Behavior α → Time → α`, where `Time` is a CPO including partial elements (not plain reals), and an `Event`'s denotation is a single non-strict `(Time, value)` first occurrence, `occ :: Event α → (Time, α)` — the "stream of occurrences" reading is later FRP. The paper won SIGPLAN's Most Influential ICFP Paper award (2007, for ICFP 1997). The practical incarnation is Remotion/Reanimate; the opposite pole is the Processing `draw()` loop (frame-rate-dependent mutation) and Manim's `always_redraw` (per-frame stateful rebuild). Trade-off: pure-`render(t)` gives O(1) seek and trivial parallel/offline export but cannot natively express "react to other objects' current state" — for that you need an updater/signal escape hatch.

> **WolfAnim is firmly in the pure-`render(t)` camp** (`Update[T]` is a fold sampled at `T`). Preserve this; treat Manim's mutate-loop and Motion Canvas's generators as anti-patterns for the core. Add updaters/signals only as a *reactive layer over* pure sampling, not a replacement.

### 4.2 Declarative state-interpolation / auto-tween vs explicit keyframes

D3 transitions are the minimal industrial form: "a transition is keyframe animation with exactly two keyframes" (current state → target), and `d3.interpolate(a,b)` returns `t → value` auto-dispatching on the target's *type* (number/color/transform/string) ([d3-transition](https://d3js.org/d3-transition), [Mike Bostock on joins](https://bost.ocks.org/mike/join/)). Framer Motion adds **FLIP** layout animation (measure First/Last, Invert, Play the delta via cheap transforms) and shared-element `layoutId` ([Framer layout animations](https://motion.dev/docs/react-layout-animations)). The contrast is GSAP/anime.js explicit keyframe timelines. Trade-off: auto-tween is ergonomic ("declare the end state") but needs a type-aware interpolator registry and a correspondence rule for structural change (enter/update/exit, or Manim's point alignment); explicit keyframes are predictable but verbose.

### 4.3 Global transport / shared timeline vs per-object queue

GSAP's `Timeline` is the canonical **transport**: a retained container with one playhead, `progress()`/`time()`/`seek()` as getter+setters, `timeScale`, labels, nested timelines, and `smoothChildTiming` re-aligning children on reverse/rescale — scrubbing for free ([GSAP Timeline](https://gsap.com/docs/v3/GSAP/Timeline/)). The position-parameter vocabulary (`+=`, `-=`, `<`, `>`, `"label+=2"`) is the most ergonomic sequencing surface in the field. The opposite is WolfAnim's current **per-object queue**: each `dynamicGraphics` reads its *own* `AbsoluteTime[]`, and sequencing is the *accidental* `FoldWhile` accumulation. Trade-off: a shared transport unlocks whole-scene scrub/loop/reverse and phase-locking visuals to a music clock; the per-object queue is simpler but cannot express overlap, anchoring, or one global playhead.

### 4.4 Retained scene graph vs immediate mode

Retained graphs (Three.js, DOM, Manim) keep persistent objects and redraw deltas; immediate mode (Processing/p5 2D, nannou `Draw`) reissues every draw call per frame, with predictable per-frame cost but path-dependent (un-seekable) state. WolfAnim is **retained-declarative**: `AnimatedObject` holds inert primitives and `["Graphics"]` materializes a `Graphics` expression *recomputed* from `T` — combining retained composability with pure recompute (the strongest cell). matplotlib's `blit=True` (redraw only changed artists) is the dirty-region optimization to keep in reserve if scenes grow ([FuncAnimation](https://matplotlib.org/stable/api/_as_gen/matplotlib.animation.FuncAnimation.html)).

### 4.5 FRP signals as a reactive layer

Signals/motion-values let one property *be* a function of another, replacing per-frame updater boilerplate. Motion Canvas `createSignal` is **lazy, pull-based, auto-dependency-tracked, cached**; Framer's `MotionValue`/`useTransform` is push-based off the React render loop ([Motion Canvas signals](https://motioncanvas.io/docs/signals/), [useTransform](https://motion.dev/docs/react-use-transform)). Manim's `ValueTracker` is the same idea encoded as an invisible mobject. WL is an ideal host: a signal is a memoized pure function of `T`, and `Dynamic`/`TrackedSymbols` already provides push-based dependency tracking. Trade-off: signals add a dependency graph (and the leak/recompute concerns Conal Elliott's push-pull FRP was designed to solve), but they are the one capability WolfAnim most lacks for cross-modal (audio↔visual) coupling.

### 4.6 Easing as first-class, composable rate functions

Separating *what moves* from *how progress is paced* — a unit-interval `rate: [0,1]→[0,1]` applied before interpolation — is universal. Manim's default `smooth` is **not** the polynomial smoothstep `3t²−2t³`; it is a clamped sigmoid: `error = sigmoid(-k/2); smooth(t) = clamp((sigmoid(k(t−0.5)) − error)/(1 − 2·error), 0, 1)` with `k = 10` and `sigmoid(x) = 1/(1+exp(-x))` ([rate_functions source](https://docs.manim.community/en/stable/_modules/manim/utils/rate_functions.html)). Reanimate goes furthest, making the curve a first-class composable value `type Signal = Double -> Double` applied by `signalA`, with a named library (`fromToS`, `curveS`, `bellS`, `oscillateS`, `cubicBezierS`, `reverseS`) that composes by ordinary function composition ([Reanimate.Ease](https://hackage.haskell.org/package/reanimate-1.1.6.0/docs/Reanimate-Ease.html)). WolfAnim already has the hook (`"Rate"`); it should be promoted from a 3-entry string table to a composable, reusable `Signal` library — including a **pure** spring (Remotion/Reanimated-style, deterministic from the frame number). Note the correct justification: Framer Motion's spring formula is itself a closed-form analytic function of elapsed time, but it is clocked by a wall-clock rAF driver and inherits live velocity on interruption — those, not the math, are what break frame-deterministic reproducibility. Remotion's `spring(frame, fps, config)`, ported from Reanimated 2, is a pure function of the frame and so stays seekable.

### 4.7 Beyond duration: parallel-composition policy

Reanimate's `parA` carries an explicit `data Sync = SyncStretch | SyncLoop | SyncDrop | SyncFreeze` for what a shorter sibling does once it ends ([Reanimate.Animation](https://hackage.haskell.org/package/reanimate-1.1.6.0/docs/Reanimate-Animation.html)). WolfAnim's parallel fold currently has *no* such policy — it just folds at the same `t` and takes `Max` duration, implicitly freezing the shorter sibling (via its `Min[t, eff["Duration"]]` clamp). Adding a `Sync` parameter (and `reverseA`/`repeatA`/`takeA`/`dropA`/`pauseAtEnd` slicing combinators) reaches Reanimate parity cheaply.

---

## 5. Recommendations: evolving WolfAnim's time model

The thesis: **keep the pure `Update[T]` substrate; lift time out of the object into a shared transport; add signals; add a cyclic pattern layer; wire audio through `VideoGenerator`.** Ordered by leverage.

### 5.1 Introduce a global Transport, distinct from the object graph

WolfAnim fuses time into the object (`obj["Duration"]`, effects baked in, per-`DynamicModule` `AbsoluteTime[]`). Separate it. A **proposed/unverified** `Transport[]` object owns one playhead `T`, plus `rate` (`timeScale`), `loop`, `seek`, and named labels; all `AnimatedObject`s sample it, so the whole scene becomes seekable/loopable like GSAP and Tidal. Concretely, replace the wall-clock loop in `dynamicGraphics` (which reads `t = AbsoluteTime[] - begin` and refreshes on `TrackedSymbols :> {t}`) with one that advances a shared transport symbol; for export, the same transport is stepped by `VideoGenerator`. This is the prerequisite for phase-locking visuals to a music clock. Move `seek`/`timeScale`/`loop` *off* the object onto the transport.

### 5.2 Make sequencing explicit: `seq` / `par` / `stack` / `cat` / `lag`

Promote the accidental `FoldWhile` accumulation and the `AnimationEffect[{...}]` parallel fold into named, nestable combinators with clear duration semantics — and add `lag`/`stagger` (a `MapIndexed` over delayed copies with a per-index offset function). Adopt Manim's confirmed decision that staggering **preserves** total duration by rescaling an internal staggered timeline (§2.4), *not* a naive `Max`. Stagger is the single highest-impact "banger-demo" primitive: stagger N objects to one musical subdivision so each hit triggers the next shape.

### 5.3 Adopt the Pattern `query: TimeSpan -> [Hap]` bridge layer

This is the keystone for the music+animation merge. Generalize the pull model from "sample one `T`" to "query a window":

```wolfram
(* proposed/unverified surface *)
pat[<|"Begin" -> b_, "End" -> e_|>]  (* b, e exact Rationals *)
  (* -> { <|"Whole" -> {wb, we}, "Part" -> {pb, pe}, "Value" -> v|>, ... } *)
```

Keep time as exact `Rational` (a native WL advantage Haskell had to bolt on) and measure it in **cycles** with one global `$cps`. Implement `fast`/`slow`/`rev`/`stack`/`cat`/`every`/`euclid` as query rewriters (input-span and output-hap transforms). Because both `Update[T]` (visuals) and a pattern (events) are now functions of the same cyclic clock, **`every 4 (flash) # e(3,8)`** can fire graphics and notes together. Route each `Hap` to *both* an `AnimationEffect` (visual `scale`/`rotate`/`color`) and an audio backend — and the audio backend already exists. (Strudel itself demonstrates this dual routing: one pattern string drives both audio and Hydra visuals via `H()`.)

### 5.4 Wire audio through `VideoGenerator`'s dual channel and WL 15 music

`VideoGenerator` natively muxes `<|"Image" -> imgfn, "Audio" -> audiofn|>` on one timeline ([VideoGenerator](https://reference.wolfram.com/language/ref/VideoGenerator.html)); WolfAnim's `["Video"]` currently passes only the image function plus `obj["Duration"]`. Wiring an audio function — rendering the pattern's Haps via WL 15.0 Computational Music — is the most direct path to recorded synced demos. The audio backend is verified: `Audio[MusicScore[{MusicNote["C4"], MusicNote["E4"]}]]` returns a valid `Audio` object ([MusicScore](https://reference.wolfram.com/language/ref/MusicScore.html)). Caveats: the entire `Music*` layer (17 symbols incl. `MusicScore`, `MusicVoice`, `MusicNote`, `MusicTransform`, `MusicTempo`) is **experimental** in 15.0; `MusicScore[events, ts, ks]` takes time/key signatures **positionally** and `MusicTempo` is its only option (`Keys[Options[MusicScore]] === {MusicTempo}`; passing `MusicTimeSignature -> val` as an option triggers `MusicScore::optx`); and `MusicTransform`'s score transforms are a fixed set `{Combine, Drop, Join, NormalizeAccidentals, ScaleTranspose, Separate, Take, Transpose, Trim}` — there is **no** `Retrograde`/`Reverse`/`Invert` (those return unevaluated) — so it is *not* a Tidal-style pattern algebra out of the box. Build the cyclic combinators in WolfAnim; use `MusicScore`/`Sound`/`AudioGenerator` only as the render sink. For a live (non-offline) clock, prefer the `SessionSubmit[ScheduledTask[...]]` task system; `RunScheduledTask` still works but is officially deprecated.

### 5.5 Add Signals / a ValueTracker analog + an `always_redraw` effect

Introduce a **proposed/unverified** `Signal[f]` — a memoized pure function of `T` (or of the transport phase / an audio amplitude) — that effects, object props, and patterns can all read, plus an `always_redraw`-style effect that rebuilds an object from the current frame's derived state each `Update[T]`. Because WolfAnim recomputes (rather than accumulates) per tick, this avoids Manim's drift/slowdown from stateful updaters while still enabling audio-reactive visuals (e.g. a `Disk` whose radius reads `amplitude[T]`) and inter-object constraints (object B follows object A's `Center`/`Bounds`, which `AnimatedObject` already exposes).

### 5.6 Add `Transform` with point/region alignment

The biggest *animation-type* gap (§2.3). WolfAnim sidesteps explicit point arrays via WL regions, which loses cheap linear morphing. Add a `Transform[objA -> objB]` that resamples both to a common discretization (the `align_points` analog — WolfAnim already discretizes via `["MeshRegion"]`/`["Partial"]`) and interpolates points/colors/directives under a `Signal`. Learn from Manim's pain: without semantic correspondence, dissimilar shapes morph as point soup, so offer matching heuristics for the common cases.

### 5.7 Promote the rate-function library and keep one mutable state

Expand `animationRateFunction` from `{Linear, Quadratic, Exponential}` to the standard family (ease-in/out/inout, `smooth` as Manim's clamped sigmoid, smoothstep, a **pure** deterministic spring, elastic, bounce, `there_and_back`), allow per-segment easing, and allow a rate to itself be a pattern (easing that varies per cycle). Finally, follow Tidal's discipline: keep exactly **one** piece of mutable state — the transport (`$cps`, playhead) — and keep everything else a pure function queried against it. That single rule is what makes whole-scene scrubbing, `Video` export, and glitch-free hot-swap (reassign the live pattern symbol; the scheduler re-reads it next cycle) all consistent at once.

---

## 6. Summary

WolfAnim already implements the hardest-won idea in the field — *media as a pure function of time* — and does so more cleanly than Manim (mutate-loop), Motion Canvas (un-seekable generators), or GSAP (stateful transport). Its gaps are not in the core but in the *layers above it*: there is no shared transport, no reactive signals, no cyclic/pattern time, no morph/`Transform`, and a three-entry easing table. The evolution that unlocks the music+animation vision is therefore additive, not a rewrite: a global scrubbable **transport**; explicit `seq`/`par`/`stack`/`cat`/`lag` combinators with a Reanimate-style `Sync` policy; a Tidal-style `query: TimeSpan → [Hap]` **pattern** layer over exact-rational cyclic time; **signals**/updaters for audio-reactivity; and the `VideoGenerator` dual `Image`+`Audio` channel rendering WL 15.0 Computational Music. The unifying substrate is the purity WolfAnim already has — `Update[T]` and a Strudel `query` are the same abstraction, and that equivalence is the whole design.
