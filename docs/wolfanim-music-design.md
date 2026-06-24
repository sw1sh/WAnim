# WolfAnim Live AV Coding: WL 15.0 Music/Audio Review and a One-Pattern-Two-Renderers Design

This document does two things. **Half A** is a kernel-grounded review of the WL 15.0 capabilities that matter for live audiovisual coding — the experimental Computational Music symbolic framework and the real-time audio + scheduling stack — stated with their honest limitations. **Half B** proposes how to "reanimate" WolfAnim around a single unifying abstraction: a `Pattern` that is a pure function of (cyclic or linear) time queried over a timespan, renderable to *either* WolfAnim graphics *or* a WL `MusicScore`/`Audio` — one symbolic structure, two renderers — built directly on top of today's `AnimatedObject`/`AnimationEffect`/`Brace` paclet.

> Scope note on sourcing: every WL symbol used in the verified-backend role below is confirmed present on a live WL 15.0.0 kernel. The entire `Music*` framework and the `AudioStream` engine are officially flagged **EXPERIMENTAL** in 15.0. Anything proposed but not kernel-verified is explicitly marked **(proposed/unverified)**.

---

## Half A — WL 15.0 Capabilities Review

### A.1 The Computational Music symbolic framework

WL 15.0 ships a `Music*` family (kernel-confirmed via `Names["Music*"]`). The named symbols below are all kernel-verified to exist and evaluate; each object is an Association-backed boxed expression of the form `Head[<|...|>]` — structurally identical to WolfAnim's own `AnimatedObject[<|"Primitives"->…,"Directive"->…,"Effects"->…,"GraphicsOptions"->…|>]`, which is the single most important interoperability fact in this document.

| Layer | Symbols | Role |
|---|---|---|
| Containers | `MusicScore`, `MusicVoice`, `MusicMeasure` | hierarchical, metric |
| Events | `MusicNote`, `MusicChord`, `MusicRest` | leaf events (pitch[es] + duration) |
| Value objects | `MusicPitch`, `MusicInterval`, `MusicScale`, `MusicKeySignature`, `MusicTimeSignature`, `MusicTempo`, `MusicDuration` | musical vocabulary |
| Analysis / IO | `MusicTransform`, `MusicMeasurements`, `MusicPlot`, `MusicObjectQ` | transform, measure, draw, test |

**Construction.** `MusicNote["C4"]` canonicalizes to a full Association carrying a `MusicPitch` (e.g. `MusicNote[<|"Pitch"->MusicPitch[...]|>]`). Constructors are polymorphic: `MusicNote["C4"]`, `MusicNote[60, 1/4]`, and `MusicNote[MusicPitch["C4"], MusicDuration[1/4]]` all evaluate; the canonical value forms `MusicPitch[60]`, `MusicScale["Major"]`, `MusicChord[{0,4,7}]`, `MusicInterval["PerfectFifth"]`, and `MusicTempo[120]` are kernel-verified. A bare-string voice `MusicVoice[{"C4","E4","G4"}]` parses pitches into a voice. **(proposed/unverified)** auto-partitioning of events into measures by time signature is plausible but not separately confirmed here.

**A pitch gotcha (verified).** `MusicPitch` uses standard scientific/MIDI numbering — kernel-confirmed `MusicPitch["C4"]["MIDINumber"] == 60` and `MusicPitch["C2"]["MIDINumber"] == 36`. The legacy `SoundNote` integer convention differs: `SoundNote[0]` is middle C (MIDI 60), so `SoundNote[n]` ↔ MIDI `60 + n`. A `SoundNote`↔`MusicNote` bridge must add/subtract 60 (e.g. C2 = `MusicNote["C2"]` = MIDI 36 = `SoundNote[-24]`). Get this offset right before mixing the legacy and `Music*` worlds.

**Score assembly is argument-position-sensitive (verified).** `MusicTimeSignature` and `MusicKeySignature` are **positional** arguments; `MusicTempo` is the **only option**:

```wolfram
MusicScore[
  {MusicVoice[{"C4", "E4", "G4"}]},
  MusicTimeSignature[4, 4],   (* positional *)
  MusicKeySignature[0],        (* positional *)
  MusicTempo -> 120            (* the sole option *)
]
```

Verified: the positional form returns a valid score with `TimeSignature -> MusicTimeSignature[<|"Numerator"->4, "Denominator"->4|>]` and `KeySignature -> MusicKeySignature[<|"Fifths"->0|>]`. Passing `MusicTimeSignature -> val` as an *option* triggers `MusicScore::optx`. `Options[MusicScore]` returns `{MusicTempo -> Automatic}` (so `Keys[Options[MusicScore]] === {MusicTempo}` is `True`).

**`MusicTransform` is the workhorse — but it is a score/pitch toolset, not a cyclic time-pattern algebra.** For a `MusicScore` the complete, fixed transform set is exactly:

```
{Combine, Drop, Join, NormalizeAccidentals, ScaleTranspose, Separate, Take, Transpose, Trim}
```

These are object-specific named classes (Voice/Measure/Pitch sets are subsets of the Score set). They are score/pitch/voice manipulations — they do **not** provide a Tidal-style pattern algebra out of the box.

> **Honest limitation (verified):** there is **no `Retrograde`, `Reverse`, or `Invert`** transform for voices/scores — those keywords return *unevaluated*. Any Tidal-style `rev` must be hand-rolled by reversing the underlying NoteList. The exact option/argument syntax for `MusicTransform` should be taken from the docs: a guessed rule form (`"Transpose" -> n`) was observed to return `$Failed`; use the documented list form (e.g. `MusicTransform[music, {"Transpose", 7}]`) and verify against the reference before committing surface API to it.

**Analysis is the animation bridge (verified).** `MusicMeasurements[score, "Properties"]` returns, on this kernel, exactly:

```
{AccumulatedDurations, Ambitus, Duration, DurationBeats, Durations,
 DurationSeconds, EstimatedKey, EstimatedKeyProbabilities, Intervals,
 NoteList, NoteTimeSeries, PitchClasses}
```

The load-bearing ones for animation sync (2-arg form `MusicMeasurements[score, prop]`, all kernel-verified):

- `"AccumulatedDurations"` → onset of each note **in whole-note units**, e.g. eight 1/8 notes give `{{0, 1/8, 1/4, 3/8, 1/2, 5/8, 3/4, 7/8}}` (wrapped per voice).
- `"NoteTimeSeries"` → a plain **`List`** (head is `List`, *not* a `TimeSeries` object) of `{onsetWholeNotes, MusicNote[...]}` pairs.
- `"PitchClasses"` → `{{0, 2, 4, 7, 9, ...}}` (values 0–11, per voice).
- `"DurationSeconds"` → the score's **symbolic** wall-clock length as a `Quantity` (see the trailing-rest caveat below).

> **Unit gotcha (verified):** onsets from `"AccumulatedDurations"`/`"NoteTimeSeries"` are in **whole-note (cycle) units, not seconds**. Convert with `seconds = wholeNotes × DurationSeconds / Total[Durations]` (≈ `× 240/bpm` in 4/4). Do **not** compare them directly to an `AudioStream` `"Position"`, which is in seconds.

**Rendering / playback (verified).** `Audio[MusicScore[…]]` returns a valid `Audio` object **directly** (no `Sound` wrapper needed) — `MusicScore` is the audio render backend for a pattern DSL. `Audio[MusicNote["C4"]]` likewise renders, and `Sound`/`SoundNote` interoperate. `MusicPlot[score]` produces piano-roll Graphics. **Duration scales inversely with `MusicTempo` as expected (verified):** one whole note renders to 2.0 s at `MusicTempo->120` and 1.0 s at `->240` (`DurationSeconds = beats × 60/bpm`). MIDI roundtrips via `Export`/`Import` are documented for `MusicScore` **(exact `Export["f.mid", …]` form not re-verified here).**

> **Trailing-rest trim gotcha (verified):** the *rendered* `Audio` can be **shorter** than the symbolic bar — a 4/4 bar of eight 1/8 events ending in a rest has `DurationSeconds = 2.0 s` but `Duration[Audio[…]] ≈ 1.75 s` at 120 bpm, because the render trims trailing silence. For a **gapless looped bar**, do not loop on `Duration[Audio]`; pad the audio to the symbolic `DurationSeconds` (e.g. `AudioPad`) or the loop runs short and the groove drifts fast.

> **Limitation:** `MusicPlot` is *static* notation (no animation hooks), and `Audio[score]` is an *offline* render — there is no streaming/real-time scheduler in the music layer itself. Playback is render-then-play, not a live clock.

### A.2 The real-time audio + scheduling stack

Two complementary stacks make a Strudel-in-Wolfram feasible.

**(1) Non-blocking audio: `AudioStream` + `AudioPlay`/`AudioStop`.** `AudioStream[audio, Looping -> True]` creates a stream with `Status "Stopped"` (verified — it does *not* auto-play, so it is safe to build headless); `AudioPlay[stream]` then starts playback **without blocking the kernel**, advancing the stream's `"Position"` while the kernel stays free. The property set is kernel-verified to be exactly:

```
{AudioChannelAssignment, AudioOutputDevice, BufferSize, CurrentAudio,
 ID, Looping, Position, SoundVolume, Status}
```

`"Position"` is a time `Quantity`; `"CurrentAudio"` returns the current buffer snippet (the audio-reactivity tap); `"Looping"` is readable. Lifecycle is verified: `AudioStreams[]` lists active streams and `RemoveAudioStream[stream]` reclaims one (count `1 → 0`). **(proposed/unverified)** a live-mutable generator (`s["Function"] = newFn` with no restart) is plausible for generator-backed streams but was not exercised here — note that a stream built from a fixed `Audio` object exposes **no** `"Function"` property (it is not in the verified list above), so per-cycle hot-swap must re-create the stream, not mutate it.

The offline FX chain (pure `Audio -> Audio`) is rich: `AudioReverb`, `AudioDelay`, `AudioPitchShift`, `AudioFrequencyShift`, `AudioTimeStretch`, `AudioSpectralMap`, `AudioBlockMap`, plus `AudioPan`/`AudioAmplify`/`AudioNormalize`/`AudioFade`. `AudioGenerator` synthesizes oscillators and noise.

For audio-reactivity, `AudioMeasurements`/`AudioLocalMeasurements` expose a rich feature set including `RMSAmplitude`, `Loudness`, `SpectralCentroid`/`Flatness`/`Flux`/`RollOff`/`Crest`, `FundamentalFrequency`, `Novelty`, `ZeroCrossingRate`, `MFCC`. `AudioCapture`/`AudioRecord` pull live mic input. You analyze a live stream by grabbing `s["CurrentAudio"]` each frame and feeding it to `AudioLocalMeasurements`. The snippet tracks the stream buffer — verified default `BufferSize = 4000` samples ≈ 90.7 ms at 44.1 kHz; treat the exact feature *count* as docs-defined rather than a fixed number.

**(2) Scheduling/clock stack.** `SessionSubmit[ScheduledTask[expr, dt]]` returns a `TaskObject` and fires `expr` every `dt` seconds in the **same kernel session**, where it can mutate global symbols — the bridge to the front end: a task bumps a symbol, a `Dynamic` reading it repaints. `RunScheduledTask` is the same engine and is verified to self-reschedule (a counter advanced ~20 times over ~1 s), but it is officially **deprecated/obsolete** in favor of `TaskExecute`; prefer `SessionSubmit`/`ScheduledTask`. `TaskRemove`/`AbortScheduledTask`/`NextScheduledTaskTime` control tasks. **(proposed/unverified)** the draft's measured jitter figures (`{0.2502, 0.2493, 0.2509}` at `dt=0.25`, std ~0.6 ms) are illustrative; treat as expectation, not guarantee.

`Clock[{vmin, vmax}, t]` produces a repeating linear **sawtooth** ramp from `vmin` up to `vmax` over `t` seconds, jumping discontinuously back to `vmin` at each period end (it is "continuous" in the sense of continuous updating, not jump-free). `Clock[vals, t, n]` runs exactly `n` cycles and thereafter returns only the maximum value. `Clock[]` ramps `0->1` once per second. It is a front-end/`Dynamic`-driven time source: it animates only inside `Dynamic`/`Manipulate`/other refreshing objects (statically it returns its start value) and is **not** phase-locked to the audio engine.

**WolfAnim already uses this idiom.** `dynamicGraphics` (`/Users/swish/src/wolfram/WolfAnim/WolfAnim/AnimatedObject.m:214-232`) computes `t = AbsoluteTime[] - begin` (line 222, with `begin = AbsoluteTime[]` set in `init[]` at line 217) inside `Dynamic[Refresh[…, TrackedSymbols :> {t}, UpdateInterval -> Infinity]]`, self-driven by `Refresh` rather than an external clock.

### A.3 Limitations, stated honestly

These are load-bearing for the design — the framework must engineer *around* them.

| Limitation | Detail | Consequence |
|---|---|---|
| **Latency / granularity** | Verified default stream `BufferSize` is **4000** samples ≈ **90.7 ms** at 44.1 kHz — a hard floor; front-end `Dynamic` repaint cadence adds more. | Not sample-accurate. Schedule at **bar/cycle** granularity; bake per-note timing into rendered Audio (`MusicScore`/`AudioGenerator`), never drive per-note from `ScheduledTask`. |
| **Single kernel threading** | `ScheduledTask`, the audio thread, and `Dynamic` all contend for one kernel. | A heavy `obj["Update"]` (`RegionUnion`, `DiscretizeRegion` are expensive) stalls the clock and audibly drops/jitters cycles. Keep per-frame work cheap; precompute geometry. |
| **Stream GC** | Streams are not auto-collected; `AudioStreams[]` accumulates; `RemoveAudioStream[]` with no args deletes **all** streams globally. | A live loop must `RemoveAudioStream[specificStream]` on each swap or it leaks audio threads and eventually glitches. |
| **Audio↔Dynamic sync drift** | Stream `"Position"` (true audio clock) and the `AbsoluteTime`/`Clock` animation clock are independent and drift over minutes. | For tight A/V sync, treat `s["Position"]` as **master** and derive visual phase from it. |
| **No look-ahead scheduler** | WL has no sample-accurate look-ahead like Strudel's trigger-latency window. | Either start the next loop slightly *before* the bar boundary, or rely on `AudioStream` `Looping` for gapless repeat of a fixed bar. |
| **Experimental APIs** | The whole `Music*` family and the `AudioStream` engine are `[EXPERIMENTAL]` in 15.0. | Options/behavior may shift; pin to verified forms and isolate behind a renderer boundary. |

**Reference point (Strudel/Tidal).** Strudel's default desktop scheduler (`NeoCyclist`) queries ~100 ms windows and adds a fixed `latency` of ~100 ms against the Web Audio clock; the legacy fallback `Cyclist` queries ~50 ms with the same 100 ms latency (≈100–200 ms total) ([Strudel internals](https://strudel.cc/technical-manual/internals/)). WL's ~90 ms buffer floor is in a comparable regime, so the same look-ahead discipline applies; WL simply lacks the sample-accurate placement layer, which is why bars (not samples) are the scheduling unit.

### A.4 Kernel-verified quick-reference (this WL 15.0.0 kernel)

Everything in this table was confirmed by direct evaluation on the kernel this document was written against (WL 15.0.0, May 19 2026). The Half B demos rest only on these facts:

| Fact | Verified value |
|---|---|
| Music object | `MusicScore[{MusicVoice[{MusicNote["C4",1/4],…]}}, MusicTimeSignature[4,4], MusicTempo->120]` → `MusicObjectQ` `True` |
| Pitch numbering | `MusicPitch["C4"]["MIDINumber"]==60`, `["C2"]==36`; `SoundNote[0]`=middle C ⇒ `SoundNote[n]`↔MIDI `60+n` |
| `MusicMeasurements[s,"Properties"]` | `{AccumulatedDurations, Ambitus, Duration, DurationBeats, Durations, DurationSeconds, EstimatedKey, EstimatedKeyProbabilities, Intervals, NoteList, NoteTimeSeries, PitchClasses}` |
| Onset units | `"AccumulatedDurations"`/`"NoteTimeSeries"` onsets are **whole-note units**, not seconds |
| `"NoteTimeSeries"` head | `List` of `{onset, MusicNote}` (not a `TimeSeries`) |
| `MusicTransform` (arg-confirmed) | `{"Transpose",7}`, `{"Transpose",MusicInterval["P5"]}`, `"Trim"` ✓ ; `"Retrograde"`/`"Reverse"`/`"Invert"` ✗ |
| Render | `Audio[MusicScore[…]]` → `Audio` ✓ (no `Sound` needed); `Sound[score]`→`Sound`; `MusicPlot[score]`→Graphics |
| Tempo→duration | 1 whole note = 2.0 s @120, 1.0 s @240 |
| Trailing-rest trim | `DurationSeconds`=2.0 s but `Duration[Audio]`≈1.75 s for a bar ending in a rest |
| `AudioStream` props | `{AudioChannelAssignment, AudioOutputDevice, BufferSize, CurrentAudio, ID, Looping, Position, SoundVolume, Status}` |
| Stream creation | `AudioStream[a, Looping->True]` → `Status "Stopped"` (no auto-play); `"Position"` is a `Quantity` |
| Stream lifecycle | `AudioStreams[]` lists; `RemoveAudioStream[s]` reclaims (1→0) |
| Default `BufferSize` | `4000` samples ≈ 90.7 ms @44.1 kHz |
| Oscillator | `AudioGenerator[{"Sin",440},0.25]` → `Audio` ✓ |
| Scheduler / clock | `SessionSubmit[ScheduledTask[expr,dt]]` & `RunScheduledTask` self-reschedule; `Clock[]` ramps 0→1/s inside `Dynamic` |

---

## Half B — The Proposed Design: One Pattern, Two Renderers

### B.0 The gap and the thesis

The live-coding literature converges on one transplantable idea, confirmed across TidalCycles and Strudel: **a Pattern is a pure function from a query state (wrapping a timespan) to a list of timed events** — in Strudel terms, `query : State{TimeSpan} -> [Hap]`, where each `Hap` carries a `value`, a `part` (the slice intersecting the query) and an optional `whole` (the event's full extent); a continuous *signal* is exactly a Hap with `whole === undefined` ([Strudel internals](https://strudel.cc/technical-manual/internals/), [Tidal: what is a pattern](https://tidalcycles.org/docs/innards/what_is_a_pattern/)). This is the *same* media-as-a-function-of-time abstraction as Fran's `Behavior` — whose denotation is a function of time, `at : Behavior_a -> Time -> a` ([Functional Reactive Animation](http://conal.net/papers/icfp97/icfp97.pdf)) — the conceptual bridge between animation and music.

The systems that genuinely unify audio and visuals do so at this layer, but each with a caveat. Strudel feeds the **same** pattern string to audio and Hydra visuals via `H()` ([Strudel + Hydra](https://strudel.cc/learn/hydra/)). Punctual routes one signal graph to `>> rgb` or `>> audio` — but graphics-only inputs return 0 in audio context and vice versa, so what is unified is the *substrate, clock, and notation* rather than a single literally-heard-and-seen expression ([Punctual](https://github.com/dktr0/Punctual)). Gibber maps an audio signal onto a visual property via capitalization, auto-inserting an envelope follower chained to an affine transform to reconcile rates and ranges ([Gibber, MM'14](https://sites.cs.ucsb.edu/~holl/pubs/Roberts-2014-MM.pdf)). None unify around a *symbolic / term-rewriting* representation. **That is WolfAnim's opening:** a WL expression *is* the single structure. `AnimationEffect` is already a pure function of normalized time `#` — structurally close to a Strudel Pattern. Add (1) a shared cyclic transport, (2) a `Pattern` query layer, and (3) a routing/sink layer to `Graphics` *or* `MusicScore`/`Audio`, and one symbolic Wolfram expression becomes the single source of truth, rendered two ways.

### B.1 Core types

#### `Pattern` — the query function (the keystone)

A `Pattern` is a pure function from a query *state* (wrapping a timespan) to a list of events. Time is exact `Rational` (a native WL advantage Tidal had to bolt on) measured in **cycles**, decoupled from wall-clock.

```wolfram
(* proposed/unverified — new WolfAnim types *)

(* WAEvent mirrors a Strudel Hap: Value + Part + optional Whole. *)
(* Whole -> None  <=>  continuous signal (Strudel's whole === undefined) *)
WAEvent[<|"Value" -> v_, "Part" -> {pb_, pe_}, "Whole" -> w_|>]

(* A Pattern wraps a query function State -> {WAEvent...}. *)
Pattern[query_Function]

queryArc[Pattern[q_], b_, e_] := q[<|"Begin" -> b, "End" -> e|>]

(* An event "has onset" iff its part begins where its whole begins. *)
hasOnset[WAEvent[d_]] := d["Whole"] =!= None && d["Part"][[1]] == d["Whole"][[1]]
```

The `whole`/`part` distinction (the modern Tidal/Strudel encoding) is what lets discrete note onsets and continuous easing/LFO signals share **one** type and one algebra: `sine` is a Pattern whose events have `Whole -> None`; a kick is a Pattern whose events have a `Whole` and fire on onset.

> Historical note: this `whole === Nothing` encoding for analog signals is the *current* Tidal/Strudel representation; older Tidal carried an explicit `Analog`/`Digital` tag, and the oldest used a bare 3-tuple with no `Maybe`. The conceptual punchline — one Pattern type for both continuous and discrete — holds across all post-2010 designs.

#### `Signal` / `Behavior` — continuous patterns

`Signal[f]` is sugar for a Pattern of `Whole->None` events sampling a pure `f : Rational -> value`. WolfAnim's existing rate functions are *already* signals: `animationRateFunction` (`/Users/swish/src/wolfram/WolfAnim/WolfAnim/AnimationEffect.m:25`) defines `"Linear" -> Function[#]`, `"Quadratic" -> Function[#^2]`, `"Exponential" -> Function[Exp[#]/E]`. Promote them, and add `sine`/`saw`/`tri`/`perlin` (proposed), sampled by `segment[n]` and reshaped by `range[lo, hi]` — the Strudel signal vocabulary.

#### `Transport` — a global cyclic clock

The system's **only** mutable state. One `ScheduledTask` owns globals `$cps` (cycles/sec), `$cycle` (integer cycle index), and `$phase` (rational position in cycle). Default `$cps = 0.5625` to match Tidal's classic feel (Tidal's documented default is 0.5625 cps = 135 BPM at 4 beats/cycle; note the live Tidal source has since drifted to `0.575`, and Strudel's default is ~0.5).

```wolfram
(* proposed/unverified *)
$cps   = 0.5625;
$cycle = 0;
$phase = 0;
$transport = None;

startTransport[] := (
  $transport = SessionSubmit @ ScheduledTask[transportTick[], 1/$cps]
);
stopTransport[] := (TaskRemove[$transport]; $transport = None);
```

**Relation to the existing `AnimationEffect` timeline.** Today time is *linear and finite*: `obj["Update", T]` (`/Users/swish/src/wolfram/WolfAnim/WolfAnim/AnimatedObject.m:72-78`) does a `FoldWhile` over the `Effects` list, accumulating a local offset (the fold's second component) and feeding each effect `T - offset`, the effect's own `rate` applied to `t/duration`. This stays intact for offline/seekable rendering. The cyclic layer sits **above** it: the transport supplies `$phase`, and the renderer queries the Pattern over `[$phase, $phase + dphase)`. Because querying any cycle is a pure function, the *same* engine drives a live loop *and*, by querying cycles `0..N`, renders a finite `Video` — unifying live and offline. The current self-loop `t = AbsoluteTime[] - begin` (`AnimatedObject.m:222`) is replaced by reading `$phase` (or, for tight sync, `s["Position"]`).

### B.2 A Tidal-style combinator + mini-notation layer in WL

#### Symbolic combinators (the algebra)

Every combinator is a query rewriter: transform the *input* span before delegating, or the *output* events after. These obey clean laws (`rev@*rev === Identity`, `fast[a]@*fast[b] === fast[a b]`) — a natural fit for WL term-rewriting and `VerificationTest`.

```wolfram
(* proposed/unverified — query rewriters *)
fast[r_][Pattern[q_]] := Pattern[ st |->
  withResultTime[# / r &] @ q @ withQueryTime[# r &] @ st ]
slow[r_]            := fast[1/r]
rev[Pattern[q_]]    := (* reflect part/whole within each cycle *) Pattern[...]
stack[ps__]         := Pattern[ st |-> Join @@ (queryAt[#, st] & /@ {ps}) ]  (* parallel union *)
cat[ps__]           := (* slowcat: one sub-pattern per cycle *) Pattern[...]
fastcat[ps__]       := fast[Length[{ps}]] @ cat[ps]
every[n_, f_][p_]   := (* apply f on cycles where Mod[cycle,n]==0, via splitQueries *) p
euclid[k_, n_][p_]  := (* Bjorklund: distribute k onsets over n steps *) p
jux[f_][p_]         := stack[pan[p, -1], pan[f[p], 1]]  (* stereo / left-right split *)
```

**Operator/symbol choices idiomatic to WL.** Prefer named heads and a few `UpValues` over inventing cryptic infixes (WL lacks Haskell-style custom infix operators).

| Tidal | Proposed WL surface |
|---|---|
| `fast 2 $ p` | `fast[2] @ p` (or `p["fast", 2]`) |
| `rev p` | `rev @ p` |
| `stack [a,b]` | `stack[a, b]` |
| `a # b` (`|>`) | `a ~keepLeft~ b` |
| `a \|+\| b` | `a + b` (via `Pattern /:`) |
| `every 4 rev p` | `every[4, rev] @ p` |
| `p(3,8)` | `euclid[3, 8] @ p` |
| `jux rev p` | `jux[rev] @ p` |

> **Important caveat for the operator design (verified).** Tidal's `#` is exactly `|>` — keep **left** structure/onsets, take **right** values. The arithmetic family `|+|` (structure both), `|+` (structure left), `+|` (structure right) takes **values from both sides** and only routes *structure*. Do **not** model `|+` as a single-side value selector. The clean WL choice: overload via `UpValues` so `Pattern /: a + b := combineBoth[a, b]`, and expose `keepLeft`/`keepRight` (= `|>`/`>|`) as named heads. This all derives from the Applicative `<*>` (both), `<*` (left structure), `*>` (right structure) distinction.

#### Mini-notation (string vs symbolic)

Offer **both**, normalizing to one internal `Pattern[…]`. The string is a fast input surface; the symbolic tree is the introspectable, transformable canonical form (WL's strength). Parse a Strudel-style string with a small PEG / `StringExpression` into the same combinator tree (`"a [b c]"` ≡ `fastcat[a, fastcat[b, c]]`):

```wolfram
(* proposed/unverified *)
p["bd [hh hh] sn"]   (* space = seq, [] = subgroup *)
p["<c4 e4 g4>"]      (* <> = slowcat: one per cycle *)
p["bd(3,8)"]         (* euclid *)
p["[bd, hh*4]"]      (* , = stack; * = fast *)
```

Recommendation: symbolic for composability/introspection/proofs; string for terseness in performance. Both canonicalize to one `Pattern` head so introspection and the renderers see a single representation.

### B.3 The audiovisual bridge — one Pattern, two renderers

A Pattern's events carry abstract values. Two renderers consume the *same* event stream over the *same* cycle clock — Punctual's `>>` sink-routing idea, made symbolic:

```wolfram
(* proposed/unverified — sink routing *)
render[pat_Pattern, "Audio"]  := patternToAudio[pat]    (* -> Audio[MusicScore[...]] *)
render[pat_Pattern, "Visual"] := patternToVisual[pat]   (* -> AnimatedObject effects *)
```

**Audio renderer (verified backend).** Map each onset event in a cycle to a `MusicNote`/`MusicChord`, assemble a `MusicVoice`/`MusicScore`, render once with `Audio[MusicScore[…]]` (verified to return a valid `Audio`), and loop the rendered bar as an `AudioStream` with `Looping -> True` for gapless playback — the offline render hidden behind the bar boundary:

```wolfram
(* proposed glue; verified backend calls: MusicNote, MusicVoice, MusicScore, Audio *)
patternToAudio[pat_] := Module[{events, notes},
  events = Select[queryArc[pat, $cycle, $cycle + 1], hasOnset];
  notes  = (MusicNote[#["Value"], #["Whole"][[2]] - #["Whole"][[1]]] &) /@ events;
  Audio @ MusicScore[
    {MusicVoice[notes]}, MusicTimeSignature[4, 4], MusicTempo -> 60 $cps 4]
];
```

For low-latency single hits, prefer `Sound[{SoundNote[…]}]` over a re-render; reserve `MusicScore` rendering for whole bars.

**Visual renderer.** The same onset events trigger `AnimationEffect`s on named `AnimatedObject`s. WolfAnim's existing effect types `"Scale"`, `"Rotate"`, `"Translate"`, `"Creation"` (verified in `AnimationEffect.m`) are the visual half of "every parameter is patternable":

```wolfram
(* proposed glue; verified: AnimatedObject["Play", AnimationEffect[...]] *)
patternToVisual[pat_][obj_AnimatedObject] := Fold[
  #1["Play", AnimationEffect["Scale", 1.4,
       "Duration" -> #2["Whole"][[2]] - #2["Whole"][[1]]]] &,
  obj,
  Select[queryArc[pat, $cycle, $cycle + 1], hasOnset]
];
```

**Cross-modal mapping (Gibber's trick, made symbolic).** Gibber's capitalization maps an audio signal onto a visual property by inserting a single mapping object — an envelope follower with an affine transform chained onto its output — to reconcile rates (44.1 kHz vs ~60 Hz) and ranges. In WL, dispatch on a distinct symbolic head instead of capitalization:

```wolfram
(* proposed/unverified — audio drives animation; verified API: AudioLocalMeasurements *)
Continuous[feature_, {lo_, hi_}]  (* envelope-follow + affine remap of an audio feature *)

amp = QuantityMagnitude @ AudioLocalMeasurements[s["CurrentAudio"], "RMSAmplitude"];
obj["Apply", "Scale", 1 + Continuous[amp, {0, 0.6}]]
```

Onsets come from the *symbolic* pattern; continuous modulation comes from `AudioLocalMeasurements` on `s["CurrentAudio"]`.

### B.4 Non-blocking live-loop / hot-swap REPL in one kernel

Hot-swap = a **stable named cell** whose contents are replaced while the clock keeps running (the Sonic Pi `live_loop` / FoxDot `p1 >>` / SuperCollider `Pdef` idiom). The scheduler reads the cell each tick by *name*, so editing never restarts the clock — Extempore-style temporal recursion (a function scheduling itself by name) realized via `SessionSubmit`.

```wolfram
(* proposed/unverified *)
$loops = <||>;   (* name -> Pattern *)

liveLoop[name_String, pat_Pattern] := ($loops[name] = pat);  (* re-eval = hot-swap *)
hush[] := ($loops = <||>);

transportTick[] := (
  KeyValueMap[renderLoop[#1, #2] &, $loops];  (* render each named loop's current pattern *)
  $cycle += 1;
  $phase = Mod[$cycle, 8] / 8;                (* drive the global animation phase *)
);
```

Re-evaluating `liveLoop["bass", newPat]` overwrites the cell; the next tick uses the new pattern with the clock untouched. **Quantize the swap to the next cycle boundary** for musical transitions; optionally crossfade by blending old/new event values over one cycle, reusing WolfAnim's `rate[#/duration]` machinery across cycles.

> Discipline (non-negotiable): track and `RemoveAudioStream[specificStream]` on each swap (never the no-arg form, which deletes all streams), and keep the per-tick body cheap so the clock does not stall. The verified end-to-end skeleton — a `ScheduledTask` that each tick removes the previous stream, starts the next looping `AudioGenerator`/`MusicScore` bar, increments `$cycle`, and sets `$phase` — is consistent with the verified non-blocking `SessionSubmit`/`AudioStream` primitives; treat its multi-cycle stability as expected-and-to-be-tested rather than pre-proven on your kernel.

### B.5 Three "banger" demo sketches

> Each sketch's audio/music/scheduling calls use only kernel-verified WL 15 symbols (`Audio`, `AudioPad`, `MusicScore`, `MusicNote`, `MusicRest`, `MusicVoice`, `MusicTimeSignature`, `MusicTempo`, `AudioStream`, `AudioPlay`, `AudioCapture`, `AudioLocalMeasurements`, `MusicMeasurements`, `MusicPlot`, `Clock`, `Dynamic`, `Refresh`). The `Pattern`/`euclid`/`liveLoop` glue is proposed WolfAnim API (marked). Property spellings below are kernel-verified on this WL 15.0.0: `MusicMeasurements` `{AccumulatedDurations, Durations, PitchClasses, NoteList, NoteTimeSeries, DurationSeconds}` and `AudioStream` `{Position, CurrentAudio, BufferSize, Looping, Status}`; `AudioLocalMeasurements` feature names (`"RMSAmplitude"`, `"SpectralCentroid"`) follow the documented audio-feature set.

#### Demo 1 — Euclidean kick that pulses a polygon

A `euclid[3,8]` rhythm drives both a looping kick `AudioStream` and a `"Scale"` pop on a hexagon, locked to one transport via the audio clock.

```wolfram
(* proposed glue: euclid, $phase | verified backend: everything else *)
hex = AnimatedObject[RegularPolygon[6]];

(* one bar of a 3-in-8 kick (Bjorklund[3,8] = x..x..x.) *)
kickScore = MusicScore[
  {MusicVoice[{
     MusicNote["C2", 1/8], MusicRest[1/8], MusicRest[1/8],
     MusicNote["C2", 1/8], MusicRest[1/8], MusicRest[1/8],
     MusicNote["C2", 1/8], MusicRest[1/8]}]},
  MusicTimeSignature[4, 4], MusicTempo -> 120];

barLen  = QuantityMagnitude @ MusicMeasurements[kickScore, "DurationSeconds"]; (* 2.0 s *)
kickBar = Audio[kickScore];
(* pad the render's trimmed trailing rest back to the symbolic bar so the loop is gapless.
   Max[0, ...] guards the opposite case (a final sounding note's release tail can make the
   render slightly LONGER than the symbolic bar, which would make the pad negative). *)
kickStream = AudioStream[
   AudioPad[kickBar, {0, Max[0, barLen - QuantityMagnitude @ Duration[kickBar]]}],
   Looping -> True];
AudioPlay[kickStream];   (* non-blocking, verified *)

(* onsets are eighth-notes 0,3,6 of 8 -> seconds within the 2 s bar = {0, 0.75, 1.5} *)
beats  = {0, 3, 6} (barLen/8);
hexDyn = Dynamic[Refresh[
  With[{ph = Mod[QuantityMagnitude @ kickStream["Position"], barLen]},
    hex["Apply", "Scale",
        1 + 0.5 Boole[AnyTrue[beats, Abs[ph - #] < 0.05 &]]]["Render"]
  ], UpdateInterval -> 0.03]];
hexDyn
```

Key move: visual phase derives from `kickStream["Position"]` (the true audio clock), so the pop hits the kick even if the kernel hiccups — dodging the A/V drift limitation (A.3). Bar length comes from the **symbolic** `MusicMeasurements[…, "DurationSeconds"]` (2.0 s here), not `Duration[Audio]` (≈1.75 s — trailing rest trimmed), which is why the audio is `AudioPad`-ded to `barLen` before looping.

#### Demo 2 — Melodic pattern drawn on a staff via `MusicPlot`, animated

A scale-walk is rendered three ways from one structure: heard (`Audio`), drawn as notation (`MusicPlot`), and animated as note-heads revealed on their onsets (driven by `MusicMeasurements` `"NoteTimeSeries"`).

```wolfram
(* verified: MusicScore, MusicMeasurements, Audio, MusicPlot, AudioStream *)
melody = MusicScore[
  {MusicVoice[MusicNote[#, 1/8] & /@ {"C4","D4","E4","G4","A4","G4","E4","D4"}]},
  MusicTimeSignature[4, 4], MusicTempo -> 110
];

audio    = Audio[melody];
notation = MusicPlot[melody, ImageSize -> 480];

(* verified shapes: per-voice lists (hence First); onsets in WHOLE-NOTE units; pcs 0-11 *)
barSec  = QuantityMagnitude @ MusicMeasurements[melody, "DurationSeconds"];  (* 2.18 s *)
durs    = First @ MusicMeasurements[melody, "Durations"];                    (* {1/8,...} *)
onWhole = First @ MusicMeasurements[melody, "AccumulatedDurations"];         (* {0,1/8,...} *)
pcs     = First @ MusicMeasurements[melody, "PitchClasses"];                 (* {0,2,4,...} *)
onSec   = onWhole (barSec / Total[durs]);   (* whole-notes -> seconds *)

mStream = AudioStream[
   AudioPad[audio, {0, Max[0, barSec - QuantityMagnitude @ Duration[audio]]}], Looping -> True];
AudioPlay[mStream];
staffDyn = Dynamic[Refresh[
  With[{now = Mod[QuantityMagnitude @ mStream["Position"], barSec]},
    Graphics[{LightBlue,
      MapThread[If[#1 <= now, Disk[{#1, #2}, 0.08], {}] &, {onSec, pcs}]},
      PlotRange -> {{0, barSec}, {-1, 11}}, AspectRatio -> 1/3]
  ], UpdateInterval -> 0.03]];
Column[{notation, staffDyn}]
```

This realizes the verified bridge — drive the animation clock from `MusicMeasurements` onset data so note-heads appear exactly on their onsets. All shapes are kernel-verified: `"AccumulatedDurations"`, `"Durations"`, `"PitchClasses"` return per-voice lists (hence `First`), onsets are in **whole-note units** (converted to seconds via `barSec/Total[durs]`), and `"NoteTimeSeries"` is a plain `List` of `{onset, MusicNote}` pairs — **not** a `TimeSeries`, so `["Times"]`/`["LastTime"]` accessors do not apply.

#### Demo 3 — Audio-reactive Lissajous from live capture

`AudioCapture` feeds live mic input; `AudioLocalMeasurements` extracts features each frame; the features modulate a Lissajous figure's frequency ratio and color — Gibber-style audio→visual mapping, no symbolic onsets needed.

```wolfram
(* verified: AudioCapture, AudioLocalMeasurements (RMSAmplitude, SpectralCentroid), Clock, Dynamic *)
mic = AudioCapture[];   (* live, non-blocking handle *)

lissajous[a_, b_, phase_, n_ : 400] :=
  Line @ Table[{Sin[a t + phase], Sin[b t]}, {t, 0, 2 Pi, 2 Pi/n}];

avDyn = Dynamic[Refresh[
  Module[{snip = mic["CurrentAudio"], amp, cen, ratio, hue, ph},
    amp   = QuantityMagnitude @ AudioLocalMeasurements[snip, "RMSAmplitude"];
    cen   = QuantityMagnitude @ AudioLocalMeasurements[snip, "SpectralCentroid"];
    ratio = 2 + Round[5 Clip[cen / 4000, {0, 1}]];   (* centroid -> freq ratio: affine remap *)
    hue   = Clip[cen / 8000, {0, 1}];
    ph    = 2 Pi Clock[];                            (* sawtooth phase ramp *)
    Graphics[{Hue[hue], Thickness[0.004 + 0.02 amp],
      lissajous[3, ratio, ph]},
      PlotRange -> 1.1, Background -> Black, ImageSize -> 480]
  ], UpdateInterval -> 0.03]];
avDyn
```

Note the rate reconciliation done by hand (Clip + affine remap of `SpectralCentroid` into a small frequency ratio) — exactly the envelope-follower-plus-affine job Gibber automates and that `Continuous[…]` (B.3) would encapsulate. (`AudioLocalMeasurements` may return a list/series; reduce to a scalar before mapping.)

### B.6 Phased implementation roadmap

Built incrementally on the current paclet (`AnimatedObject`/`AnimationEffect`/`Brace`), each phase shippable.

**Phase 0 — Transport (no music yet).** Introduce `$cps`/`$cycle`/`$phase` globals and a single `SessionSubmit[ScheduledTask[…]]` transport. Retrofit `dynamicGraphics` (`AnimatedObject.m:214-232`) to read `$phase` instead of self-driving `t = AbsoluteTime[] - begin`. Deliverable: multiple `AnimatedObject`s share one scrubbable, loopable playhead. Risk: kernel contention — keep the tick body trivial.

**Phase 1 — `Pattern` core + signals.** Implement `Pattern`/`WAEvent`/`queryArc`/`hasOnset` with exact `Rational` time; promote `animationRateFunction` to first-class `Signal`s and add `sine`/`saw`/`perlin`/`segment`/`range`. Encode algebra laws as `VerificationTest`s. Deliverable: `every[4, rev] @ euclid[3,8] @ p` evaluates.

**Phase 2 — Two renderers.** `patternToVisual` (events → `AnimationEffect`s on named objects) and `patternToAudio` (events → `MusicScore` → `Audio` → looping `AudioStream`). Wire stream lifecycle hygiene (`RemoveAudioStream[specific]` per swap). Deliverable: one pattern simultaneously animates and plays (Demo 1).

**Phase 3 — Mini-notation + hot-swap REPL.** PEG/`StringExpression` parser `p["…"]` → symbolic `Pattern`; `liveLoop[name, pat]`/`hush[]` named cells with cycle-quantized swap; optional crossfade. Deliverable: edit-eval-hear-and-see live coding in a notebook.

**Phase 4 — Audio-reactive + cross-modal mapping.** `AudioCapture` → per-frame `AudioLocalMeasurements` → `Continuous[feature, {lo, hi}]` envelope+affine mapping onto visual properties (Demo 3). Deliverable: feature-driven visuals.

**Phase 5 — Polish: self-rendering + projectional feedback.** `MusicPlot`-style overlay highlighting the active step synced to playback (the "code is a third channel" TOPLAP ethos), leveraging the notebook front end.

### B.7 Open risks

- **Bar-granular scheduling only.** The buffer floor + `Dynamic` cadence mean per-note timing must be *baked into rendered Audio*, not driven from `ScheduledTask`. Fast subdivisions (`fast[8]`) within a bar live inside the `MusicScore`, not the scheduler.
- **Offline-render latency on edit.** `Audio[MusicScore[…]]` is offline; hot-swapping a *pattern* means re-rendering a bar. Re-render on the cycle *before* it plays (look-ahead), or restrict live edits to parameters that don't force a re-render.
- **Single-kernel stalls.** Expensive `obj["Update"]` paths (`RegionUnion`, `DiscretizeRegion`, `MeshRegion`) can drop cycles. Precompute/cache geometry; memoize `Update` for objects whose effects are inactive at the current phase.
- **Stream leaks.** Without disciplined `RemoveAudioStream[specific]`, leaked threads glitch audio over a long set. Needs a tracked stream registry per loop.
- **Drift.** Treat `s["Position"]` as master clock; never trust `AbsoluteTime`/`Clock` for A/V lock.
- **Experimental churn.** `Music*` and `AudioStream` are `[EXPERIMENTAL]`; pin to verified forms and isolate them behind the renderer boundary so a 15.x API shift touches one module.
- **No native `rev`/retrograde in `MusicTransform`** (verified): `"Retrograde"`, `"Reverse"`, `"Invert"` return *unevaluated* on this kernel. The documented Score transform names are `{Combine, Drop, Join, NormalizeAccidentals, ScaleTranspose, Separate, Take, Transpose, Trim}`, but only `{"Transpose", n}` / `{"Transpose", MusicInterval[…]}` and `"Trim"` were argument-form-confirmed here (`{"ScaleTranspose", 2}` / `{"Take", 2}` failed — argument syntax differs; check the docs). The pattern layer must implement `rev`/cyclic-time ops itself by rewriting the event list — do not rely on `MusicTransform` for them.

---

### Summary

WL 15.0 supplies — verified on a live kernel — every primitive needed for a native, single-kernel live AV coder: a symbolic music vocabulary (`Music*`) that renders to `Audio`, MIDI, and notation; a non-blocking, hot-swappable `AudioStream` engine with a rich reactive feature set via `AudioLocalMeasurements`; and a self-rescheduling `SessionSubmit`/`ScheduledTask` scheduler that mutates globals a `Dynamic` can track. WolfAnim's `AnimationEffect` is already a pure function of normalized time — one short reach from a Strudel/Tidal `Pattern`. The design centers on that single `Pattern` abstraction queried over cyclic rational time, fanned out by a `>>`-style sink layer to *either* WolfAnim graphics *or* `MusicScore`/`Audio`, with the audio engine's `Position` as the master clock to defeat drift. The honest constraints — bar-granular scheduling, single-kernel contention, manual stream GC, experimental APIs — shape the architecture rather than block it: schedule at bars, bake notes into rendered Audio, slave visuals to audio time, and keep per-tick work cheap. The payoff is a system no other ecosystem has: one *symbolic* Wolfram expression as the single source of truth, heard and seen at once.
