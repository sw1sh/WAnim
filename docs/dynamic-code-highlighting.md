# Live code highlighting in Notebook cells — symbolic InputForm boxes (implemented prototype)

**Status:** working prototype shipped as `LiveCode` in `WolfAnim/Pattern.m`. This note
explains the approach, what is kernel-verified, and what still needs a human at a front end
to judge. An earlier version of this doc proposed a *projectional string mirror* — that was
rejected (it re-typesets a string instead of the code). The approach below is the one built.

## 1. What we want

Strudel's REPL highlights the mini-notation **in time with the sound** — the token(s)
currently sounding glow, locked to the audio clock. We want the same inside a Wolfram
notebook for a `CyclicPattern`/`Track`.

## 2. The idea that won — render the *symbolic* pattern, highlight its boxes

Don't use a mini-notation *string* and char-map into it. Write the pattern **symbolically**
(combinators + atoms) and render *that expression* to its own **InputForm boxes** — the same
boxes the front end already syntax-colors. Then wrap each atom's boxes in a `StyleBox` whose
`Background` is a `Dynamic` that lights up while that atom's events are sounding. The code you
see *is* the pattern, and the highlight rides on top of the FE's own typesetting.

```wolfram
LiveCode[ stack[ s["bd*4"], note["<c4 e4 g4>"] // fast[2] // every[4, rev] ] ]
```

renders as the literal code `stack[s["bd*4"], note["<c4 e4 g4>"] // fast[2] // every[4, rev]]`,
each `s[...]`/`note[...]` atom box flashing on its onsets, with a playhead bar underneath.
Left-click = play/pause, right-click = reset (the same click mechanics as `["Play"]`).

Avoiding strings is the whole point: the structure is already a tree, so mapping a sounding
event back to *its box* is just an id on the atom — no source-span parsing of a string.

## 3. How it works (what the prototype does)

`LiveCode` is `HoldFirst`, so it gets the pattern expression **unevaluated** and does three
passes over the held tree (`WolfAnim/Pattern.m`):

1. **Tag + play.** Replace each atom (a leaf whose head is in `$LiveAtomHeads`, see §5) with
   `tagPat[id][atom]`, which adds `"Source" -> id` to every event the atom emits, then
   `ReleaseHold` to get the real pattern. The combinators carry the extra key through because
   `mapEventTime`/`reverseCycle` now **merge** the event association instead of rebuilding it
   with only `Value/Whole/Part`. Query that tagged pattern over *N* cycles → events, each
   knowing which atom (`Source`) it came from and when it plays (`Whole`). Group into a
   per-id schedule of `{onset, offset}` cycle-intervals.

2. **Render + inject.** Replace each atom in the *same* tree with `hlAtom[itsIntervals, atom]`,
   an inert marker whose `MakeBoxes` is

   ```
   StyleBox[ MakeBoxes[atom],
             Background -> Dynamic[ If[liveActiveQ[intervals, livePhase, liveCycles],
                                       glow, transparent] ] ]
   ```

   so `MakeBoxes` of the whole tree yields the normal InputForm boxes of the code, with each
   atom's box wrapped in a highlight that reads the shared `livePhase`.

3. **Clock + transport.** Wrap it all in a `DynamicModule[{livePhase, stream, playing}, …]`:
   a looping `AudioStream` of the rendered loop, a `Refresh` (30 ms) that sets
   `livePhase = streamPosition · cps` (the audio is the master clock, so no drift), an
   `EventHandler` for the clicks, and a `ProgressIndicator` playhead. `With[{b = boxes}, …]`
   splices the boxes into the module body so the module localizes `livePhase` *inside* the
   `StyleBox` dynamics.

`liveActiveQ` lights an atom while `Mod[phase, N]` is inside any of its intervals (with a
~0.06-cycle floor so very short notes still flash). `SaveDefinitions -> True` makes the cell
self-contained.

## 4. Verified vs. needs-a-front-end

Kernel-verified (via `wolframscript`, fresh kernels):

- `LiveCode[…]` builds a `DynamicModule` with **one `StyleBox` per atom**, each containing the
  atom's InputForm boxes; the `AudioStream`, click handlers, and localized `livePhase` are all
  present; the audio renders and plays; the schedule maps events→atoms correctly. Works for
  nested combinators (`stack`, `// fast`, …) and counts atoms correctly.

Needs eyes at a front end (cannot be checked headless):

- **Does the FE syntax-color the rendered boxes**, and does the `StyleBox` `Background` ride on
  top without fighting the foreground color? (Background and FontColor are independent, so it
  should — but confirm.) If output cells don't get input-style syntax coloring, we can color
  the tokens ourselves in the `MakeBoxes` (symbols one color, strings another) and keep the
  dynamic background.
- The glow timing vs. what the ear hears (the ~90 ms audio buffer floor may make the flash
  lead/lag slightly).
- Readability of the glow color / floor on real patterns.

## 5. The atom registry, and where the shortcuts live

`LiveCode` decides "what is an atom" from `$LiveAtomHeads` (a `WolfAnim`` global, default
`{CyclicPattern}`), so it has **no** hard-coded short names. The optional, opt-in
`Strudel`` context (`WolfAnim/Strudel.wl`) defines the lowercase Strudel shortcuts
(`s`/`note`/`n`/`sound` as down-values, `fast`/`rev`/`stack`/`seq`/… as aliases) and appends
its atom heads to `$LiveAtomHeads`. So:

- The paclet stays clean — no `s`/`n` forced onto the `WolfAnim`` path.
- `LiveCode[Fastcat[CyclicPattern["bd"], CyclicPattern["hh"]]]` highlights with no shortcuts
  loaded; after `Get["…/Strudel.wl"]`, `LiveCode[seq[s["bd"], s["hh"]]]` highlights too.

Atom heads must be **down-values, not own-value aliases** (`s[a_] := CyclicPattern[a]`, not
`s = CyclicPattern`), or `_s` in the detector would evaluate `s` away and never match the held
`s[...]`.

## 6. Open questions / next steps

1. **Glow semantics** — flash-per-onset (current, with a floor) vs. stay-lit across a held
   note's duration. Easy to switch in `liveActiveQ`.
2. **Editable REPL** — wrap the code in an `InputField[Dynamic[…]]` (or make `LiveCode` accept
   edits) and hot-swap the stream at the next cycle boundary, for the full edit-hear-see loop.
   The held-expression form makes "edit" mean *re-evaluate the cell*, which is already natural
   in a notebook; an in-widget editor is the stretch.
3. **Highlight groups too** — currently only leaf atoms glow; optionally outline the active
   enclosing `[ … ]` / `< … >` group.
4. **Instrument the literally-typed Input cell** (rather than a re-rendered output) — still the
   hard, FE-fragile option; deferred. The output-cell prototype gives the experience without
   it.
5. **`Track` / multi-voice** — `LiveCode` currently takes one pattern expression; extend to a
   stack of named voices with per-voice rows.

---

*Code:* `LiveCode`, `tagPat`, `hlAtom`, `liveActiveQ`, `$LiveAtomHeads` in
`WolfAnim/Pattern.m`; the shortcuts + atom registration in `WolfAnim/Strudel.wl`. The clock and
click mechanics mirror `patternPlay`/`audioDynamic`.
