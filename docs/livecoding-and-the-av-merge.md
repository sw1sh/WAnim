# Live-Coding Pattern Languages and the Audiovisual Merge

> **Abstract.** This document argues that the live-coding pattern languages of the TidalCycles/Strudel lineage and the functional-reactive animation lineage of Fran/Reanimate are *the same abstraction wearing two costumes*: a value-varying-over-time, queried on a timespan. It builds that algebra from first principles, surveys the clock/scheduling and hot-swap models of seven music systems and the audiovisual-merge systems (Hydra, Punctual, Estuary, flok, Gibber, ORCA, Strudel visuals), and renders an explicit verdict: a *unified structure* that natively drives both sound and image already exists at the signal, object, and pattern layers, but never as a **term-rewriting symbolic representation**. That gap is precisely WolfAnim's opening.

---

## 1. The Pattern Algebra of TidalCycles / Strudel, From First Principles

### 1.1 A Pattern is a function from a query to events

The central abstraction of [TidalCycles](https://tidalcycles.org/docs/innards/what_is_a_pattern/) is not a list of notes but a *pure function*. In Haskell:

```haskell
data Pattern a = Pattern { query :: State -> [Event a] }
  where State = State { arc :: Arc, controls :: ControlMap }
        Arc   = (Time, Time)
        Time  = Rational
```

You never store a buffer; you *ask* a pattern "what events occur in the arc `3 → 4`?" and it computes them on demand. [Strudel](https://strudel.cc/technical-manual/patterns/) carries the same idea into JS, with one precision worth keeping: the query function does not take a bare `TimeSpan` — it takes a `State` that wraps the query span plus a controls dict. `queryArc` builds `new State(new TimeSpan(begin, end), controls)` and calls `query`. Precisely:

> **A Pattern is a function `State → [Hap]`, where `State` carries a query `TimeSpan` (rational `Fraction` begin/end) plus controls.**

The `Time = Rational` decision is load-bearing: a triplet is *exactly* `1/3`, never a float, so nested polyrhythm stays correct and the scheduler can predictively query any future window.

### 1.2 The Event / Hap: `whole` vs `part`, and the analog/digital unification

Each event (`Event` in Tidal, `Hap` in Strudel) carries three things:

| Field | Meaning |
|---|---|
| `value` | the payload (a note, a control map, a number, a graphics directive) |
| `part` | the slice of the event intersecting the *current query* |
| `whole` | the event's *full original extent* — a `Maybe Arc` |

An event **has an onset** only when `start(part) == start(whole)`. Querying a sub-range of a cycle yields *fragments* (`part ⊂ whole`); downstream code filters on `hasOnset` so a sound triggers exactly once.

The deepest and least-obvious idea: **a continuous "analog" signal is exactly a Hap with `whole = Nothing/undefined`.** `sine`, `saw`, `perlin`, and `rand` have no discrete onset; they yield a value at *any* queried instant. Discrete drum hits carry `whole = Just arc`. **The same `Pattern` type unifies oscillators and drum hits under one Applicative/Monad algebra.** (Historical precision: modern Tidal and Strudel encode analog purely by `whole = Nothing`, keeping only the derived predicates `isAnalog`/`isDigital`. A transitional pre-1.0 Tidal used an explicit `data Nature = Analog | Digital` tag; the oldest 0.9.8 used a bare `(Arc, Arc, a)` 3-tuple with no `Maybe`.)

This is the conceptual seed of the whole merge: an easing curve and a note onset are *the same kind of thing*.

### 1.3 Cycles, not beats: CPS as the time unit

Tidal measures time in **cycles**, decoupled from wall-clock, with tempo as **CPS (cycles-per-second)**, not BPM, [deliberately because time is cyclic, not linear](https://tidalcycles.org/docs/reference/cycles/). The documented default is **`0.5625` cps** (≈ 135 BPM at 4 beats/cycle), set or changed via `setcps`; it is the default whether or not you ever call `setcps`. Strudel's default is **~0.5 cps**. (Precision: as of current Tidal source — v1.10.0, June 2025, and `main` — the hardcoded default in `tidal-link`'s `Clock.hs` has moved to `defaultCps = 0.575` (= 138 BPM at 4 beats/cycle), so the long-documented `0.5625` is now slightly out of date in the code, though the docs still state it.) Because a Pattern is a function of rational time, you can query past or future cycles freely — enabling reversal, fast-forward, and deterministic scrubbing.

### 1.4 Functor / Applicative / Monad: the instances *are* the algebra

`Pattern` is a lawful Functor, Applicative, and Monad, and those instances are not incidental — **they are the composition algebra.**

- **Functor** (`fmap`/`<$>`): map a function over every event value.
- **Applicative** (`<*>`): query a pattern-of-functions and a pattern-of-values, combining them where their timespans overlap (intersecting `whole`/`part` via `subArc`/`sect`). Tidal exposes three *structural* variants:
  - `<*>` / `appBoth` — structure = intersection of **both**;
  - `<*` / `appLeft` — structure/onsets from the **left**, sample the right;
  - `*>` / `appRight` — structure from the **right**.
- **Monad** (`>>=`, via `innerJoin`/`outerJoin`/`squeezeJoin`): a value in one pattern selects an entire *sub-pattern*. `outerJoin`/`squeezeJoin` keep the outer pattern's structure (used by `<a b>` alternation and *patterned arguments* like `fast "2 3"`); `innerJoin` keeps the inner's. **"Every parameter can itself be a pattern" falls straight out of the monad.**

The control operators are exactly these applicative variants surfaced. Per [the Tidal applicative writeup](https://uzu.lurk.org/t/functor-applicative-and-monad-pattern/1233), `#` is **exactly an alias of `|>`**: keep the **left** pattern's structure/onsets, take the **right** pattern's values. The bar `|` marks the structure-providing side; the arrow `<`/`>` marks the value-providing side:

| Operator | Structure | Values |
|---|---|---|
| `\|>` (= `#`) | left | right |
| `>\|` | right | right |
| `\|<` | left | left |
| `<\|` | right | left |
| `\|>\|` | both | right |
| `\|<\|` | both | left |

For an arithmetic op like `+`: `|+|` (= `+`, structure from **both**), `|+` (structure **left**), `+|` (structure **right**), analogously for `-` `*` `/` `%`. **Caveat for any port:** the arithmetic family combines *both* sides' values (it adds/multiplies them) while only routing the *structure* direction — unlike `|>`, which selects one side's values outright. In Strudel these become method suffixes: `.in()` = left structure, `.out()` = right structure, `.mix()` = both.

A canonical demonstration of "structure from both": `"2 3" + "4 5 6"` splits the `5` because it straddles the `2|3` boundary, yielding **four** events. This is the algebra that makes compact notation of complex structured patterns possible — and the single feature most worth porting.

### 1.5 Combinators as query rewriters

Every time transform rewrites the query *before* delegating and the results *after*:

```haskell
_fast r p = withResultTime (/r) $ withQueryTime (*r) p   -- query faster, place results back
rotL t    = withResultTime (subtract t) . withQueryTime (+t)
```

`splitQueries` cuts a multi-cycle query at integer boundaries so per-cycle logic (`every`, `slowcat`) works. In Strudel the same three primitives appear as `withQuerySpan` (transform the input span), `withHapSpan`/`fmap`/`withValue` (transform outputs), and `splitQueries`.

### 1.6 Mini-notation reference

The mini-notation is a terse string DSL compiled (Strudel uses a Peggy/PEG grammar, `krill.pegjs`) into the same `Pattern` algebra. `"a [b c]"` ≡ `seq(a, seq(b, c))`.

| Token | Meaning | Example |
|---|---|---|
| ` ` (space) | sequence packed into one cycle | `bd sn hh` → 3 events of 1/3 cycle |
| `[ ]` | sub-grouping; the group is one step of its parent | `bd [sn sn]` |
| `< >` | slowcat / alternation, one element per cycle | `<a b c>` |
| `,` (in `[]`/`{}`) | stack / polyphony (chord, parallel layers) | `[c,e,g]` |
| `~` (or `-`) | rest | `bd ~ sn` |
| `*n` | speed up a step | `bd*2` |
| `/n` | slow down a step | `bd/2` |
| `!n` | replicate as separate events | `bd!3` |
| `@n` | elongate / weight (duration multiplier) | `bd@3 sn` |
| `_` | continue/extend previous step | `bd _ sn` |
| `?p` | randomly drop with prob p (default .5) | `bd?0.3` |
| `:n` | sample index | `bd:3` |
| `(k,n,r)` | Euclidean (Bjorklund): k onsets over n steps, rotate r | `bd(3,8)` |
| `{a b, c d e}%n` | polymeter: align by step, loop at LCM | `{bd sn, hh hh hh}%4` |
| `0 .. 7` | numeric range | `n "0 .. 7"` |

### 1.7 Categorized combinator reference

All of these are `Pattern → Pattern` (or higher-order). Drawn from [Tidal's function index](https://userbase.tidalcycles.org/All_the_functions.html) and [Strudel's docs](https://strudel.cc/learn/factories/).

| Category | Combinators |
|---|---|
| **Time** | `rev` (reflect within each cycle); `fast n`/`slow n`/`hurry n` (scale the query span; `hurry` also pitches up); `every n f` (apply `f` on cycles where `cycle mod n == 0`); `off t f` (superimpose a time-shifted, `f`-transformed copy — echoes); `iter n` (rotate start by 1/n each cycle); `whenmod a b f`; `rot n` (rotate values, keep structure); `palindrome` (= `every 2 rev`) |
| **Layering** | `stack`/`overlay` (parallel union); `jux f` / `juxBy amt f` (pan original hard-left, `f`-transformed hard-right — the classic stereo trick); `superimpose f` (= `stack p (f p)`); `layer [f,g,…]` |
| **Sequence** | `cat`/`slowcat` (one sub-pattern per cycle); `fastcat`/`seq` (cram all into one cycle); `randcat` (pick one sub-pattern per cycle); `timecat`/`stepcat` (`[weight,pat]` proportional concat); `arrange [n,pat]…` (n cycles each); `run n` → `0..n-1` |
| **Stochastic** | `sometimesBy p f` (+ presets `sometimes`/`often`/`rarely`/`almostAlways`/`almostNever`); `degradeBy p`/`degrade`/`undegradeBy`; `euclid k n` / `euclidInv` / `euclidFull`; `someCyclesBy`. **All driven by a deterministic per-cycle PRNG keyed on (cycle, position)** so a performance is reproducible and consistent under scrubbing/export. |
| **Control** | `n`, `note`, `s`/`sound`, `gain`, `pan`, `speed`, `room`, `cutoff`, `shape`, `delay` — name an output channel; combine with structural operators (`#`, `|+|`, …) |
| **Structure imposition** | `struct boolpat`, `mask`, `segment n` (impose n discrete onsets/cycle on a signal), `range lo hi` (rescale a signal) |

Continuous **signals** (`sine cosine saw isaw tri square` in 0..1, `*2` variants in −1..1, plus `rand perlin`) are analog patterns sampled by `.segment(n)` and reshaped by `.range(lo,hi)`: e.g. `n(sine.range(0,7).segment(8))`.

---

## 2. Clock / Scheduling and Hot-Swap Across Live-Coding Systems

Live-coding time models cluster into three families, and hot-swap converges on one idea: **a stable named cell whose contents are replaced while the clock keeps running.**

### 2.1 Three time models

**(A) Self-scheduling code — the function *is* the clock.**
[ChucK](https://ccrma.stanford.edu/~ge/publish/files/2015-cmj-chuck.pdf) is *strongly-timed*: `now` (type `time`) is logical present time; advancing it (`1::second => now`) **blocks** the shred and yields to the "shreduler," which interleaves all shreds sample-synchronously, deterministically, non-preemptively, with no locks. Concurrency is free because each shred already supplies its timing — the same code sounds identical on every machine.
[Extempore](https://extemporelang.github.io/docs/overview/time/) is the asynchronous twin: **temporal recursion** — a function whose final act is `(callback (+ (now) dur) 'self)`, scheduling itself by name for a future time; `(now)` is in samples; re-evaluating the function swaps its body for the next callback (the signature must stay fixed). The [ChucK CMJ paper](https://ccrma.stanford.edu/~ge/publish/files/2015-cmj-chuck.pdf) states the canonical distinction in its related-work section: **"Extempore schedules events; ChucK code schedules itself"** — ChucK being "completely synchronous (the code waits precisely until the desired timing is fulfilled)," with SuperCollider grouped alongside Extempore as favoring the asynchronous approach.

**(B) Virtual time + schedule-ahead.**
[Sonic Pi](https://www.cs.kent.ac.uk/people/staff/dao7/publ/farm14-sonicpi.pdf) (Aaron, Orchard, Blackwell, FARM'14) is formalized as a **Temporal monad**. Each thread has a thread-local **virtual time**. `sleep t` advances virtual time but is a *soft deadline / temporal barrier*: it guarantees a *minimum* elapsed `t`, absorbing the cost of preceding computation (sleeping only the remaining time) so **jitter never accumulates into drift**. Effects are timestamped at virtual time and **scheduled ahead** by a constant `scheduleAheadTime` (≈0.5 s on most platforms, 1 s on Raspberry Pi 1) — specifically at `(current virtual time + scheduleAheadTime)`, which is what absorbs the real-vs-virtual gap. The safety property — a program never under-runs its virtual time — they call **"time safety,"** analogous to type safety.

**(C) Function-from-time-to-events (lazy patterns).**
Tidal/Strudel (Section 1), and the [SuperCollider](https://doc.sccode.org/Classes/TempoClock.html) substrate they often drive: a `TempoClock` schedules in **beats** (tempo = beats/sec); `sched`/`schedAbs` queue tasks; `quant`/`nextTimeOnGrid(quant,phase)` snap starts to the beat grid so independently-launched patterns lock in phase; `Pbind`/`Pseq` build event streams played by an `EventStreamPlayer`.

### 2.2 Hot-swap: named mutable cell + scheduler-reads-cell

| System | Named cell | Swap mechanism |
|---|---|---|
| **Sonic Pi** | `live_loop :name` | re-run the named block → replaces body on *next iteration*; thread/name/time persist. `cue`/`sync` phase-lock voices. |
| **FoxDot** | `p1 >> pluck(...)` | the `>>` operator mutates the persistent `Player` named `p1` in place; the player self-reschedules (`self.event_index += dur; self.metro.schedule(self, ...)`). |
| **SuperCollider JITLib** | `Ndef(\a,…)`, `Pdef`, `Tdef`, `ProxySpace ~x` | first-class proxies replaced/recombined *while playing*, quant-aware so the swap lands on a bar boundary. |
| **Tidal/Strudel** | `d1 $ …` (16 orbits) | reassign the variable; the scheduler re-queries "the current pattern" next tick → glitch-free. Transitions `xfade`/`clutch`/`anticipate`/`jumpIn` smooth the swap. |
| **Extempore** | a recursing named function | redefine it; the next callback uses the new body. |

The common abstraction: **NAME → MUTABLE CELL → SCHEDULER reads the cell each tick**, so editing never restarts the clock. What makes the REPL *feel* good is (a) named cells you re-run idempotently, (b) quantized swap so edits land musically, (c) cue/sync for phase-lock, and (d) tight visual feedback (Strudel highlights the active mini-notation token; Gibber annotates running sequences in the editor; Mercury keeps a 30-line always-visible editor as a deliberate constraint).

### 2.3 The Strudel scheduler, concretely

Strudel actually ships **two** schedulers. The default desktop **NeoCyclist** (`neocyclist.mjs`, driven by `clockworker.js`) uses a query/cycle duration of **0.1 s (100 ms)**. The legacy single-instance **Cyclist** (`cyclist.mjs`, a mobile fallback) queries at the `createClock` default of **0.05 s (50 ms)**. Both add a fixed trigger offset `latency = 0.1` (100 ms) to each Hap's target time, scheduled against the **Web Audio clock**. So total latency ≈ query-duration + 100 ms (~150 ms for the 50 ms Cyclist; ~100–200 ms for NeoCyclist). The technical manual's tidy formula `deadline = whole.begin - now + minLatency` is explicitly labeled "a simplified example"; production code converts the cycle position to seconds via `/cps` and computes `targetTime = (whole.begin - num_cycles_at_cps_change)/cps + seconds_at_cps_change + latency`. The design lesson per [Chris Wilson's "A Tale of Two Clocks"](https://web.dev/audio-scheduling/): **never trust wall-clock `setInterval`; schedule against an audio sample clock and use a look-ahead window** to survive GC pauses.

---

## 3. THE KEY INSIGHT: FRP and Tidal Are the Same Abstraction

This is the conceptual unifier for WolfAnim, and it can be argued rigorously.

### 3.1 Fran: animation = function of continuous time

The seminal idea, from [Elliott & Hudak's "Functional Reactive Animation" (Fran, ICFP '97)](https://dl.acm.org/doi/10.1145/258948.258973) — winner of SIGPLAN's **Most Influential ICFP Paper Award** (given in 2007 for the 1997 paper) — is that an animation is a continuous, time-varying value. **Precision against the primary source:** the paper does *not* define `Behavior a = Time -> a` as a literal type synonym. `Behavior` and `Event` are "a pair of mutually recursive polymorphic data types" (abstract types). The function-of-time character is the *denotation*, given by a semantic function `at : Behavior α → Time → α` ("an interpretation of α-behaviors as a function from time to α-values"). `Time` is not plain ℝ but a *pointed CPO* of real time including partial/improper elements (±∞), enabling event detection by interval analysis. An event's denotation is `occ : Event α → Time × α` — a *single* non-strict (Time, value) occurrence, not a stream. (The "stream of discrete occurrences" formulation of `Event` is *later* FRP, not seminal Fran.)

Stated carefully: **a behavior's meaning is a (CPO-)continuous function of time; sampling (rendering) is a separate, late step**, giving resolution/fps independence. Images are themselves behaviors (`ImageB`), composed with `over` and transformed with `move`/`bigger`/`withColor`; `timeTransform` reparametrizes the clock. This denotational ideal is exactly what [Reanimate](https://hackage.haskell.org/package/reanimate-1.1.6.0/docs/Reanimate-Animation.html) makes practical: `Animation = Duration + (Time→SVG)` with `Time` normalized to `[0,1]`, eased by `type Signal = Double → Double` via `signalA`, parallel-composed with explicit beyond-duration policies `data Sync = SyncStretch | SyncLoop | SyncDrop | SyncFreeze`, and a `Scene` monad reified back to a pure value by `scene :: (forall s. Scene s a) -> Animation`.

### 3.2 Tidal: music = function of cyclic time

From Section 1: [a Pattern is a pure function from a query TimeSpan to a set of events](https://strudel.cc/technical-manual/patterns/). The query function *is* the pattern.

### 3.3 The structural identity

Place the two side by side:

| | **Fran / Reanimate** | **Tidal / Strudel** |
|---|---|---|
| Core type (denotation) | `Behavior a ≅ Time → a` | `Pattern a ≅ TimeSpan → [Event a]` |
| Time | continuous (CPO-valued) real time | cyclic, rational (`Fraction`) |
| Output | one value (a frame) | a *set* of timed events over the span |
| Reactivity / events | `Event α` (occurrences); `switcher`/`untilB` | Haps with a `whole`; discrete onsets |
| Continuous case | the behavior itself | a Hap with `whole = Nothing` (signal) |
| Sampling | render at instants | query a span |
| Free properties | scrubbable, reversible, time-transformable, composable | scrubbable, reversible, fast/slow/rev, hot-swappable |

Both are **"media as a pure, samplable function of time."** They differ only in two superficial ways:

1. **Point vs. span query.** Fran samples at an instant `t`; Tidal queries an interval `[b,e)`. But an instant is the degenerate interval `[t,t]`, and conversely a span query is what you need when events have *duration* (a held note spanning the query). These are the same operation at different granularities — and indeed a frame renderer *is* a span query: "give me everything visible during `[t, t+dt)`."

2. **One value vs. a set.** A `Behavior` returns one value; a `Pattern` returns a list of Haps. But layering (`stack`/`over`) shows that a scene is itself a *set* of simultaneously-present things, and a single drawn frame is the `over`-fold of that set. Symmetrically, a continuous signal in Tidal (`whole = Nothing`) returns *one* value per query instant — exactly a `Behavior`.

The unification is therefore not analogy but **identity up to the trivial isomorphism `(Time → a) ≅ (TimeSpan → [Event a])` restricted to the relevant cases.** WolfAnim already sits on the animation side of this identity: its `AnimationEffect` is a pure `Function[<|Object, t, T|>] → Object` carrying a `Duration`, and `obj["Update", T]` is the sampling step that folds effects to produce the graphics at time T. That is `Behavior[Object]` in all but name. Generalize `AnimationEffect` from a per-effect `t/duration` closure into a first-class **`Behavior[Object] → Behavior[Object]`** with a query layer, and **the same combinators that schedule visual change schedule musical events** — because both are functions of one shared clock.

**This is the whole thesis:** animation and music *do* merge naturally, not because they sound or look alike, but because the live-coding world (Tidal) and the FRP world (Fran) independently discovered the *same* mathematical object, and a single engine can render it two ways.

---

## 4. Survey of Audiovisual-Merge Systems, and the Verdict

The central question: *is there a system where the SAME structure drives sound and image — one notation, two renderers?* The honest answer is **yes, at three different layers, with caveats — but never around a symbolic/term-rewriting representation.**

### 4.1 Genuine unifiers

**Gibber (object/mapping layer).** [Roberts et al., MM'14](https://sites.cs.ucsb.edu/~holl/pubs/Roberts-2014-MM.pdf) is the strongest existence proof of a *unified high-level abstraction*. Every object — audio `Synth` or visual `Cube` — exposes the **same** `seq()` sequencing method, the **same** scheduling (`future()` sample-accurate one-shots, `Seq` loops, `onupdate` per-frame), and the **same** cross-modal *mapping*. Its signature trick: **capitalizing** a property name creates a *continuous* mapping. `cube.rotation = synth.Frequency` (capital F) auto-inserts a single *mapping object* — an **envelope follower with an affine transform chained onto its output** — that reconciles the two signals' timescales (44.1 kHz audio vs ~60 Hz video) and ranges (Gibber's default 50–3500 Hz mapped to 0–2π, user-overridable via `.min`/`.max`); lowercase takes only an instantaneous snapshot. (Direction matters: audio→visual inserts an envelope follower; visual→audio inserts a low-pass filter.) **Proxies** solve hot-swap for both graphs at once: re-running `a = Sine(...)` swaps the node in place and every sequencer/mapping pointed at `a` re-routes automatically.

**Punctual (signal layer).** [David Ogborn's Punctual](https://github.com/dktr0/Punctual) has ONE notion — a multi-channel *graph* that is a function of time/space producing numbers — and the same expression is format-agnostic until a `>>` routing operator names a sink: `osc 440 >> audio` makes sound; `osc 440 >> rgb` makes a greyscale field. Audio and video coexist in one program sharing one tempo (`cps`, `beat`, `time`). **The caveat that defines the gap** (from [REFERENCE.md](https://raw.githubusercontent.com/dktr0/Punctual/main/REFERENCE.md)): the *meaningful sources* are partly disjoint. Audio I/O and time-domain DSP (`audioin`, `delay`) are "audio only, equivalent to 0 in fragment shaders"; the fragment-coordinate functions (`fx`, `fy`, `fr`, `ft`) "produce a constant signal of 0" in audio, and the tempo vars (`time`, `beat`, `etime`, `ebeat`) are graphics-only and return 0 in audio. Ordinary oscillators and arithmetic work in both. So **what is unified is the substrate, the clock, and the notation — not a single expression literally heard *and* seen at once.** Live re-evaluation crossfades at the next cycle boundary (`<> 8` for an 8-second crossfade).

**Strudel (pattern layer).** A pattern is media-agnostic, and the **same pattern string** drives audio and [Hydra visuals simultaneously via `H()`](https://strudel.cc/learn/hydra/) after `await initHydra()`. The official docs assign the string to a variable once and reuse it:

```js
await initHydra()
let pattern = "3 4 5 [6 7]*2"
shape(H(pattern)).out(o0)                                  // visuals
n(pattern).scale("A:minor").piano().room(1)                // audio, same pattern
```

Strudel also *self-renders the symbolic structure*: `.pianoroll()`, `.punchcard()`, `._scope()`, `.spiral()`, `.color()`, plus live highlighting of the currently-sounding token. Visuals and audio are drawn from one Hap stream — but the visuals are either literal renders of event data or Hydra fed by the pattern, **not** a general animation/scene system.

### 4.2 Bridges, not unifiers (shared clock + transport only)

**Estuary** ([Ogborn et al., ICLC'17](https://iclc.toplap.org/2017/cameraReady/ICLC_2017_paper_78.pdf)) is a Haskell/Reflex-DOM browser platform whose model is `Server → Ensembles → {Definitions, Views}`; each Definition is written in a *different* language (MiniTidal, Punctual, CineCer0, Seis8s, TimeNot, Hydra) sharing a tempo and the WebDirt engine. It answers the unification question *negatively* but contributes two patterns worth stealing: **projectional/structure editing** (click to insert valid structures — syntax errors impossible; one structure shown through multiple "projections") and **explicit, nestable liveness levels** (Tanimoto's taxonomy: L3 "not live" until you click Eval; L4 "live" immediately).

**flok** ([Munshkr](https://github.com/munshkr/flok)) is the purest bridge: a P2P collaborative editor with per-language slots (Strudel, Tidal, SuperCollider, FoxDot, Mercury, Sardine, Hydra) coordinated by a pub/sub bus. It unifies the *editing surface and network*, nothing about media.

**Tidal → SuperDirt → OSC → Hydra/Processing** is the canonical "two languages bridged" production pipeline. Every Tidal event is an [OSC bundle of named parameters](https://tidalcycles.org/docs/configuration/MIDIOSC/osc/) (note, cycle, duration, custom keys), forkable to a visual engine — so visuals are *driven by* but not *the same as* the pattern.

**ORCA** is an esoteric 2D grid sequencer where letter "operators" move data spatially and emit MIDI/OSC/UDP; like the pipeline above, it is a sequencer that drives external sound/visual engines rather than a single structure rendered two ways.

**TOPLAP ethos.** The [manifesto](https://toplap.org/wiki/ManifestoDraft) — "Obscurantism is dangerous. Show us your screens"; "Code should be seen as well as heard" — makes the *code itself* a third audiovisual channel, projected behind performers at algoraves.

### 4.3 The verdict

> **A single structure that drives both sound and image already exists — at the object layer (Gibber), the signal layer (Punctual), and the pattern layer (Strudel). But in every case the unifying structure is a *signal graph*, *JS object graph*, or *FRP pattern*. NONE unifies around a *symbolic / term-rewriting representation*, and none exists in Wolfram Language.**

That is the gap WolfAnim can fill. WL's symbolic expression *is* the one structure; an `AnimationEffect` is already a function of normalized time, structurally isomorphic to a Strudel Pattern (Section 3) and to a Punctual graph. WL natively provides what the others bolted on: **exact `Rational` arithmetic** (Tidal added rationals deliberately; WL has them as the default), **lazy structural pattern-matching and term rewriting** (ideal for a query-rewriter pattern algebra), **`UpValues` operator overloading** (so `#`, `|+|`, `fast` can be real operators, not method-chains), and a **richly typeset, projectional notebook** that is "show your screen" by construction. No existing system has all of this.

---

## 5. Implications for a WL Pattern DSL

The following grounds the design in *kernel-verified* WL 15.0 facts and confirmed verdicts. Where a symbol or API is not yet confirmed for a specific role, it is marked **(proposed/unverified)**.

### 5.1 What WL 15.0 already gives you (confirmed)

- **A symbolic Computational Music layer** (tagged EXPERIMENTAL): the `Music*` family — `MusicScore`, `MusicVoice`, `MusicMeasure`, `MusicNote`, `MusicChord`, `MusicRest`, `MusicScale`, `MusicInterval`, `MusicPitch`, `MusicTempo`, `MusicTimeSignature`, `MusicKeySignature`, `MusicTransform`, `MusicPlot`, and more (kernel-confirmed via `Names["Music*"]`; introduced in 15.0). `MusicNote["C4"]` evaluates to a canonical normal form; `MusicScale["Major"]`, `MusicChord[{0,4,7}]`, `MusicInterval["PerfectFifth"]`, `MusicTempo[120]` all exist.
- **An audio backend that consumes scores:** `Audio[MusicScore[{MusicNote["C4"], MusicNote["E4"]}]]` returns a valid `Audio` object (kernel-verified) — **`MusicScore` can serve as the audio render backend for a pattern DSL.** `Sound[{SoundNote[...]}]` is the lower-latency note-trigger path; `AudioGenerator[model, t]` synthesizes arbitrary waveforms from a function of time.
- **A dual-channel synchronized renderer:** `VideoGenerator[<|"Image" -> imagespec, "Audio" -> audiospec|>, dur]` (EXPERIMENTAL) muxes a time→image function AND a time→audio function on *one* timeline. Sync is by absolute time on a shared timeline (the two specs are independent, not paired per-frame): `imagespec` can be an image, a list of images, a `Manipulate`/`AnimatedImage`, or an `imagefunc` of time `t`; `audiospec` can be an audio, a list of audio, or an `audiofunc` of time; `dur` (commonly `Duration[audio]`) sets length; `FrameRate` (default 30) governs frame sampling. **This is the single most load-bearing native capability for the merge** — and WolfAnim's existing `["Video"]` path already calls `VideoGenerator` but currently ignores the `"Audio"` channel.
- **A bounded cyclic master clock:** `Clock[{vmin,vmax}, t]` produces a repeating linear **sawtooth** ramp `vmin → vmax` over `t` seconds, jumping discontinuously back at each period; `Clock[vals, t, n]` runs exactly `n` cycles then holds `vmax`. It animates only inside refreshing objects (`Dynamic`/`Manipulate`); statically it returns `vmin`. This is a free cyclic-time / LFO source to replace `AbsoluteTime`-polling.
- **A self-rescheduling scheduler (temporal recursion):** `SessionSubmit[ScheduledTask[expr, spec]]` returns a `TaskObject` and self-reschedules (kernel-verified: a counter advanced ~20× over ~1 s). `NextScheduledTaskTime`, `StopScheduledTask`, `ScheduledTaskActiveQ` round it out. **Important correction:** `RunScheduledTask` still works in 15.0 but is officially **OBSOLETE** ("being phased out in favor of `TaskExecute`"); **prefer `SessionSubmit` + `ScheduledTask`.** This is the Extempore-style "function schedules itself" primitive — no external backend needed.

**Two constraints to design around (confirmed):** (1) `MusicTransform` has **NO** Retrograde/Reverse/Invert for voices/scores (they return unevaluated); the complete Score transform set is exactly `{Combine, Drop, Join, NormalizeAccidentals, ScaleTranspose, Separate, Take, Transpose, Trim}` — score/pitch/voice manipulations, **not** a Tidal-style cyclic time-pattern algebra, which you must build yourself. (2) For `MusicScore`, time and key signatures are **positional** arguments (`MusicScore[events, MusicTimeSignature[4,4], MusicKeySignature[0]]`); `MusicTempo` is the *only* option (`Keys[Options[MusicScore]] === {MusicTempo}`; the full value is `{MusicTempo -> Automatic}`). Passing `MusicTimeSignature -> val` as an option triggers `MusicScore::optx`.

### 5.2 Recommended architecture (the unconfirmed parts marked)

1. **Represent a pattern as a pure function** *(proposed/unverified API)*:
   ```wl
   pat[<|"Begin" -> b, "End" -> e|>] :=
     {<|"Whole" -> {wb, we}, "Part" -> {pb, pe}, "Value" -> v|>, ...}
   ```
   Keep time as exact `Rational` — WL's native exact arithmetic is a genuine advantage Haskell had to bolt on, and it makes nested polyrhythm and deterministic scrubbing exact. Continuous signals are Haps with `"Whole" -> None`. This mirrors `obj["Update", T]` (already a sampling function) generalized to a *span* query.

2. **Offer both notations, normalizing to one symbolic `Pattern[...]` head** *(proposed/unverified)*: a string mini-notation `p["bd [hh hh] sn(3,8)"]` parsed (via `StringExpression` or a small PEG) for terseness, **and** a symbolic surface using WL sequence/list syntax with operator overloading via `UpValues` — e.g. `Pattern /: a + b := combineBoth[a, b]`, with `combineLeft`/`combineRight` for `|+`/`+|`, and `fast`/`slow`/`rev`/`every` as named heads. Symbolic for composability and introspection; string for speed. The string compiles *to* the symbolic tree (`"a [b c]" ≡ seq[a, seq[b, c]]`). **Note** the structure-routing operators (`|>`-family) select one side's values, but the arithmetic family (`|+|`, `|+`, `+|`) combines *both* sides' values while only routing structure — replicate that distinction.

3. **Route one event stream to two renderers** (this is the merge): a Hap's value flows simultaneously to the **audio** backend — `Audio[MusicScore[...]]` (verified) or `Sound[{SoundNote[...]}]` for low latency — *and* to a WolfAnim `AnimationEffect`, so `color`/`scale`/`rotate`/`opacity` become patternable visual params highlighted in sync with the audio. This is the Punctual `>>`-sink idea expressed in WL: `effect >> Visual` vs `effect >> Audio` *(proposed/unverified routing layer)*. Borrow Gibber's "capitalization/operator = continuous mapping" so `shape.rotation = Continuous[amplitude]` auto-builds the rate-and-range-reconciling pipeline *(proposed/unverified; the affine + envelope-follower bridge is a Gibber pattern to replicate, not a WL primitive)*.

4. **Hot-swap inside one kernel** *(proposed/unverified)*: store each live pattern in a global symbol (`$d1`, like Tidal's `d1`); run the scheduler in an async `SessionSubmit[ScheduledTask[...]]` (verified primitive) that re-reads `$d1` every tick. Redefining `d1["…"]` reassigns the symbol; the next query uses the new pattern with the clock untouched. **Quantize the swap to the next cycle boundary** (borrowed from Sonic Pi `sync` / SuperCollider `quant`) so changes land musically; optionally cross-fade by blending old/new event streams over one cycle, reusing WolfAnim's existing rate/interpolation machinery (`rate[#t/duration]`) applied *across cycles* instead of along a finite timeline.

5. **Use a look-ahead audio-clock scheduler, not wall-clock polling** (Section 2.3 lesson): query a window ~100–200 ms ahead, schedule `Sound`/MIDI at exact deadlines, keep per-tick allocation minimal (pack event lists; avoid reconstructing the pattern tree every query) to dodge kernel GC jitter and offline-`Audio` latency. Adopt Sonic Pi's schedule-ahead + virtual-time discipline (timestamp at `virtualTime + scheduleAhead`) so visual and audio stay phase-locked.

6. **Preserve the algebra laws as tests** so the symbolic DSL is provably composable — `rev @* rev === Identity`, `fast[a] @* fast[b] === fast[a b]`, `palindrome === every[2, rev]` — a natural fit for WL term-rewriting and `VerificationTest` (and a candidate for a Lean proof layer).

### 5.3 Why WolfAnim is positioned to be first

WolfAnim's `["Update", T]` is a **pure function of time** (the FRP/Remotion model), which gives it free random-access seeking and trivial `VideoGenerator` export — the same property Remotion sells as its core advantage ("think of your component as a function that transforms a frame number into an image"), and the property Motion Canvas's stateful generator model structurally cannot provide (seeking to an earlier frame there means re-running the generator from the containing scene's start, not O(1) access). It is therefore already on the correct side of the Section 3 identity. Adding (a) a shared cyclic CPS clock (it has only linear `#t/duration` tweens today), (b) the `Pattern` query layer, and (c) a two-renderer routing/sink, turns it into **the first system where one symbolic Wolfram expression is the single source of truth, rendered as both sound and image** — closing the exact gap the survey in Section 4 identified.
