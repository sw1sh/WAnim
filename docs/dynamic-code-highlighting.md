# Design note (proposal) — live code highlighting in Notebook cells, Strudel-REPL style

**Status:** proposal for review. Nothing here is built yet. The goal is to agree on a shape
before committing code. Author's recommendation is in §6.

## 1. What we want

In the [Strudel](https://strudel.cc) REPL, while a pattern plays the **mini-notation lights
up in time with the sound**: the token(s) currently sounding glow, synced to the audio clock.
It turns the code into a third feedback channel alongside what you hear and what you see.

We want the same thing for WolfAnim's `CyclicPattern`/`Track` **inside a Wolfram notebook**:
play a pattern and watch its mini-notation string flash on each onset, locked to playback.

## 2. How Strudel does it (for reference)

- The mini-notation parser produces an AST whose **leaves keep their source location**
  (a character span in the typed string).
- The scheduler emits *haps* (timed events); each hap carries a reference back to the source
  location it came from.
- A CodeMirror **decoration** highlights those spans for the duration of each hap.
- The master clock is the Web Audio clock; a look-ahead scheduler paints decorations slightly
  ahead and clears them when the hap ends.

Three ingredients: (a) **source-mapped events**, (b) a **clock**, (c) a way to **style spans
of the displayed code** live. We have good analogues for (b) and (c); (a) is the work.

## 3. What the WL notebook gives us, and what it doesn't

**We have:**
- A real master clock: `AudioStream[...]["Position"]` (seconds), already what `["Play"]`/
  `["Scope"]` scrub from. `phaseCycles = Position * $CyclesPerSecond`.
- Live typesetting: `Dynamic`, `Refresh[…, UpdateInterval->…, TrackedSymbols:>…]`, and
  per-element styling via `StyleBox`/`Framed`/`Highlighted`/`Background`. A box can have a
  `Dynamic` background that reads a shared symbol — so a token can glow on demand.
- `EventHandler` for the click mechanics we already use (left = play/pause, right = reset).
- `InputField[Dynamic[str], String]` for an editable text field that re-parses on change.

**We don't have (cheaply):**
- A clean, supported way to **restyle the user's actual typed Input cell** while they edit it.
  The front end owns those boxes; rewriting them mid-edit is invasive and FE-version-fragile.
- Public per-token bounding boxes for an arbitrary cell (needed to overlay highlights on the
  real cell).

So the robust path is a **projectional mirror**: render the mini-notation ourselves as styled
boxes we fully control, rather than instrumenting the typed cell. That mirror can also be
editable, giving the REPL feel without fighting the front end.

## 4. The core idea — a source→time schedule

Everything rests on annotating events with where they came from in the string.

1. **Source-mapped parser (Phase 0).** Today `parseSequence`/`parseStep`/`parseElement`
   (`WolfAnim/Pattern.m`) discard character offsets. Add a position-tracking mode that threads
   the absolute offset through the recursion so each `atomPattern` records
   `"Source" -> {i, j}` (the char span of its token) on the events it produces. Steady/atom set
   it; the combinators (`fast`, `rev`, `every`, …) already `mapEventTime` over events — they
   just need to **preserve the extra `"Source"` key** (mostly free, since they rebuild the
   association). `CyclicPattern[str]` also stashes the original `str`.

2. **Schedule.** For a pattern `p` over `N` cycles:
   ```
   events   = Select[p["Query", 0, N], hasOnset]
   schedule = {#["Source"], #["Whole"]} & /@ events     (* {span, {t0, t1}} in cycles *)
   ```
   Group by span → for each source span, the list of cycle-intervals when it is sounding.

3. **Active test.** At play phase `φ` (cycles), span `{i,j}` is lit iff some interval
   `{t0,t1}` for it satisfies `t0 <= Mod[φ, N] < t0 + glow`, where `glow` is a short window
   (the hap's `t1-t0`, or a fixed ~80 ms so brief notes still flash visibly). This is an
   interval lookup, cheap to do per frame for typical token counts.

## 5. Proposed surface

### Phase 1 — `LiveCode` projectional view (the realistic core)

```wolfram
LiveCode["bd*4, ~ cp ~ cp, <c e g> "]      (* or:  pattern["Highlight", nCycles] *)
```

Returns a `DynamicModule` that:
- parses the string once into the pattern **and** a token list with spans + the schedule;
- renders the string as a monospace `Row`/`Grid` of per-token boxes, each token a
  `Framed`/`StyleBox` whose `Background` is
  `Dynamic[If[active[span, phase], litColor, GrayLevel[0.12]]]`;
- starts a hidden looping `AudioStream` of the rendered loop and drives a shared `phase` from
  its `Position` (`Refresh`, `UpdateInterval -> 0.03`);
- uses the **same click mechanics** as `["Play"]`/`["Scope"]` — left-click on the code =
  play/pause, right-click = reset.

This is a read-only-by-default, fully-controlled mirror of the code that plays and glows. It
needs nothing from the front end beyond ordinary Dynamic typesetting, so it is robust.

Optionally stack it with the existing piano roll (`["Play"]`) so code, roll, and sound all
scrub together.

### Phase 2 — editable mini-REPL

Wrap the code in `InputField[Dynamic[codeString], String, ...]` (monospace). On change:
re-parse → rebuild the schedule → **hot-swap the stream at the next cycle boundary**
(quantized, reusing the loop length so the groove doesn't jump). That is the Strudel
edit-hear-see loop, living inside one notebook output cell. Highlighting overlays the field's
text via a `Dynamic` `Background`/`Overlay` aligned to the field (monospace makes column math
exact: char *k* sits at *k·em*).

### Phase 3 — instrument the *actual* typed cell (stretch / research)

To light the real code the user typed (not a mirror), the options, roughly worst-to-best:
- **(a) Box surgery** — on evaluate, replace the cell's `BoxData` with a styled tree (each
  token a `StyleBox` with a `Dynamic` background). Clobbers in-progress edits; brittle.
- **(b) Overlay** — compute token bounding boxes from FE box info and draw highlight
  rectangles in an attached/overlay cell. No public per-token bounds API; position math is
  fragile across FE versions and zoom.
- **(c) A dedicated cell style** (`"Pattern"`) whose stylesheet renders its string content
  through the Phase-1 machinery, so *typing in a `Pattern` cell* auto-highlights. Most
  "native", but needs a stylesheet + a content→pattern hook, and constrains the cell to a
  single pattern string.

Recommendation: treat Phase 3 as research; (c) is the most promising if we pursue it.

## 6. Recommendation

Ship **Phase 0 + Phase 1** first: source-mapped events plus the `LiveCode` projectional
view. It delivers ~90% of the value (play, watch the code flash in time, click to control)
with no front-end fragility, and it composes with the piano roll and `["Scope"]` we already
have. Add **Phase 2** (editable field + quantized hot-swap) once Phase 1 feels right. Defer
Phase 3.

## 7. Open questions for review

1. **Glow semantics.** Flash per onset (brief glow = the hap, Strudel-like) vs. stay-lit
   across a held note? Proposal: flash per onset with a short floor (~80 ms) so fast steps
   still read.
2. **Granularity.** Highlight only the active leaf token, or also dim/outline its enclosing
   group (`[ … ]`, `< … >`)? Proposal: leaf glow, with an optional faint outline on the active
   group.
3. **`a*4` and Euclid.** One token, several haps — flash the token on each hit. Confirm that
   reads well, or split visually.
4. **Mirror vs. real cell.** Is a projectional mirror acceptable for v1 (recommended), or is
   highlighting the literally-typed cell a hard requirement (pushing us to Phase 3)?
5. **Latency.** `Position` is the true clock, but the audible buffer floor is the default
   `BufferSize` (~90 ms). The glow can lead/lag by that much — leave it, or apply a fixed
   offset so the flash matches what the ear hears?
6. **Editable v1?** Start read-only (Phase 1) or jump to the editable field (Phase 2)?

## 8. Rough effort

- Phase 0 (source-mapped parser): small-to-medium — localized to the parser + preserving one
  key through the combinators; covered by `VerificationTest`s on the schedule.
- Phase 1 (`LiveCode` view): medium — schedule + a styled-box renderer + the existing
  play/clock/click plumbing.
- Phase 2 (editable + hot-swap): medium — field + cycle-quantized stream swap.
- Phase 3: open-ended research.

---

*Grounding in the current code:* the clock and click mechanics already exist in
`patternPlay`/`scopePlay` and `audioDynamic` (`WolfAnim/Pattern.m`, `WolfAnim/AnimatedObject.m`);
the parser to extend is `parseSequence`→`atomPattern` in `WolfAnim/Pattern.m`; events are
associations with `"Whole"`/`"Part"`, to which Phase 0 adds `"Source"`.
