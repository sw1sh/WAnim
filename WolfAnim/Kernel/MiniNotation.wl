(* ::Package:: *)

(* WolfAnim`MiniNotation`  --  a proper AST parser for the mini-notation, built on the
   Wolfram`Parser` paclet.  It makes Track HOLD its source string + AST (as the
   pattern's 2nd metadata arg), and renders an EDITABLE, event-highlighting TraditionalForm:
   the input string is reconstructed as boxes, each atom's characters light up the instant
   its events sound, and editing the field re-parses + re-plays live.

   Requires the Wolfram`Parser` paclet.  Load AFTER WolfAnim:
       PacletDirectoryLoad["<.../WolframParser/Parser>"];   (* or install the paclet *)
       Get["<.../WolfAnim/MiniNotation.wl>"]                                          *)



(* ---------- grammar: mini-notation -> neutral AST, each atom carrying a {start,end} char span ---------- *)
$grammar := $grammar = Module[
    {seqCell, space, optSpace, number, atom, element, modifier, step, seq, sub, alt, comma},
    seqCell  = RecCell[];
    space    = ParseRegex[" +"];
    optSpace = ParseRegex[" *"];
    number   = ParseRegex["[0-9]+"];
    (* SpannedToken stamps Source -> {start, end} (cursor offsets: covers chars start..end-1) *)
    atom = SpannedToken[ParseRegex["[A-Za-z0-9#.~_-]+"], ParseSucceed[Null], Function[s, LeafNode["Atom", s, <||>]]];
    comma = ParseAction[optSpace ~~ ParseLiteral[","] ~~ optSpace, #1 &];
    sub = ParseAction[ParseLiteral["["] ~~ optSpace ~~ ParseSepBy[RecRef[seqCell], comma] ~~ optSpace ~~ ParseLiteral["]"],
        Function[{lb, s1, seqs, s2, rb}, If[Length[seqs] == 1, GroupNode["Sub", seqs, <||>], GroupNode["Stack", seqs, <||>]]]];
    alt = ParseAction[ParseLiteral["<"] ~~ optSpace ~~ RecRef[seqCell] ~~ optSpace ~~ ParseLiteral[">"],
        Function[{lb, s1, sq, s2, rb}, GroupNode["Alt", If[MatchQ[sq, GroupNode["Seq", _, _]], sq[[2]], {sq}], <||>]]];
    element = ParseChoice[sub, alt, atom];
    modifier = ParseChoice[
        ParseAction[ParseLiteral["*"] ~~ number, Function[{st, num}, {"Fast", FromDigits[num]}]],
        ParseAction[ParseLiteral["!"] ~~ number, Function[{st, num}, {"Repl", FromDigits[num]}]],
        ParseAction[ParseLiteral["("] ~~ number ~~ ParseLiteral[","] ~~ number ~~ ParseLiteral[")"], Function[{lp, k, cm, n, rp}, {"Euclid", FromDigits[k], FromDigits[n]}]]];
    step = ParseAction[element ~~ ParseMany[modifier],
        Function[{el, mods}, Fold[Function[{e, m}, GroupNode[m[[1]], {e}, <|"Args" -> Rest[m]|>]], el, mods]]];
    seq = ParseAction[step ~~ ParseMany[ParseAction[space ~~ step, #2 &]],
        Function[{h, t}, If[t === {}, h, GroupNode["Seq", Prepend[t, h], <||>]]]];
    SetRec[seqCell, seq];
    ParseAction[optSpace ~~ seq ~~ optSpace, #2 &]
]

parseMini[str_String] := Quiet @ Check[Parse[$grammar, str], $Failed]

(* ---------- AST -> Track, tagging each atom's events with its char span ---------- *)
tagSpan[span_][cp_] := With[{q = First[cp]}, Track[Function[sp, (Append[#, "Source" -> span] &) /@ q[sp]]]]
(* a rest "~" is still an EVENT: tag it like any atom so its step highlights in the source and
   occupies the cycle, but it carries the value "~" which the audio + roll skip (see restQ). *)
ap[LeafNode["Atom", "~", m_]]  := tagSpan[m["Source"]][Steady["~"]]
ap[LeafNode["Atom", v_, m_]]   := tagSpan[m["Source"]][Steady[v]]
ap[GroupNode["Seq", st_, _]]   := Fastcat @@ (ap /@ st)
ap[GroupNode["Sub", {x_}, _]]  := ap[x]
ap[GroupNode["Stack", ss_, _]] := Layer @@ (ap /@ ss)
ap[GroupNode["Alt", st_, _]]   := Alternate @@ (ap /@ st)
(* replicate: hh!8 = eight hh as eight separate steps in the cycle (unlike hh*8 = speed up) *)
ap[GroupNode["Repl", {x_}, m_]]   := Fastcat @@ ConstantArray[ap[x], m["Args"][[1]]]
ap[GroupNode["Fast", {x_}, m_]]   := Fast[m["Args"][[1]]] @ ap[x]
ap[GroupNode["Euclid", {x_}, m_]] := Euclidean[m["Args"][[1]], m["Args"][[2]]] @ ap[x]
ap[_] := Silence

(* override the string constructor: parse to AST, derive the query, HOLD source + AST *)
(* A source string is mini-notation, optionally followed by a postfix " // <op>" chain
   (fast/slow/rev/degrade/euclid/every/late/early).  This is the inverse of the combinators'
   source-building (Pattern.wl `chain`), so Fast[2][p] and Track["... // fast 2"] are
   the same pattern -- the bijection. *)
WolfAnim`Track[str0_String] := With[{str = StringTrim[str0]},
    If[StringContainsQ[str, "//"],
        Fold[applyChainStep, Track[StringTrim @ First @ StringSplit[str, "//"]],
            StringTrim /@ Rest @ StringSplit[str, "//"]],
        With[{ast = parseMini[str]},
            If[ast === $Failed, Silence, Append[ap[ast], <|"Source" -> str, "AST" -> ast|>]]]]]

parseChainNum[s_] := Which[
    StringContainsQ[s, "/"], With[{ab = ToExpression /@ StringSplit[s, "/"]}, ab[[1]]/ab[[2]]],
    StringContainsQ[s, "."], ToExpression[s], True, FromDigits[s]]
chainFnOf[name_] := Switch[name, "rev", Reverse, "degrade", Degrade, _, Identity]
applyChainStep[pat_, stepStr_] := With[{toks = StringSplit[stepStr]},
    Switch[First[toks, ""],
        "fast", Fast[parseChainNum[toks[[2]]]][pat],
        "slow", Slow[parseChainNum[toks[[2]]]][pat],
        "rev", Reverse[pat],
        "degrade", If[Length[toks] >= 2, Degrade[parseChainNum[toks[[2]]]][pat], Degrade[pat]],
        "euclid", Euclidean[FromDigits[toks[[2]]], FromDigits[toks[[3]]]][pat],
        "every", Every[FromDigits[toks[[2]]], chainFnOf[toks[[3]]]][pat],
        "late", Late[parseChainNum[toks[[2]]]][pat],
        "early", Early[parseChainNum[toks[[2]]]][pat],
        "gain", Gain[parseChainNum[toks[[2]]]][pat],
        _, pat]]


(* ---------- editable, event-highlighting TraditionalForm ---------- *)
onsetQ[ev_] := ev["Whole"] =!= None && ev["Part"][[1]] == ev["Whole"][[1]]
scheduleOf[pat_, n_] := GroupBy[Select[pat["Query", 0, n], onsetQ], #["Source"] &, Function[es, #["Whole"] & /@ es]]
(* light each atom for EXACTLY its event's duration: lit while the phase is within a note's
   [onset, offset).  A token whose several hits share one source span (e.g. bd*4) stays lit
   across them -- its span is genuinely sounding the whole time. *)
activeSpans[sched_, phase_, n_] := With[{p = Mod[phase, n]},
    Keys @ Select[sched, AnyTrue[#, #[[1]] <= p < #[[2]] &] &]]
litQ[i_, active_] := AnyTrue[active, #[[1]] <= i < #[[2]] &]   (* span {s,e} covers chars s..e-1 *)
highlightedString[str_, active_] := Row[Table[
    Style[StringTake[str, {i}], Background -> If[litQ[i, active], RGBColor[1, 0.82, 0.3, 0.8], Automatic]],
    {i, StringLength[str]}],
    BaseStyle -> {FontFamily -> "Source Code Pro", FontWeight -> Bold, FontSize -> 17, FontColor -> GrayLevel[0.9]}]

(* The editable TraditionalForm: the highlighted source IS the editor -- click it to enter
   text mode (a stable InputField), click the Visual below to play/pause (right-click resets).
   The Visual (visualOf[pat]: Bar/PianoRoll/Oscilloscope) is the SAME one StandardForm shows,
   rendered from `renderVisual` (shared from Pattern.wl).  Two states via `editing`:
     - editing=False: ONE refreshing Dynamic draws [highlight] over [visual], 30 ms ticks.
     - editing=True : a stable InputField (no refresh, so the cursor survives) over the visual.
   `curPat` tracks the live-parsed pattern so an edit also updates the piano-roll visual. *)
miniDisplay[pat_, n_ : 2] := With[{source = pat["Source"], viss = visualsOf[pat], solo = soloFlagQ[pat]},
    DynamicModule[{id = Unique[], src = source, curPat = pat, stream = AudioStream[Audio[pat, n], Looping -> True],
                   editing = False, lastClick = 0., sched = scheduleOf[pat, n]},
        (* The apply (re-parse) action is INLINED into the apply Button + Enter handler below.
           A DynamicModule-local f[]:= and Method->"Queued" both write to the wrong (un-localized)
           symbols, so the new pattern never reached the display.  Inline + default (preemptive)
           keeps the writes in the DM scope.  Safe because the render is ~10ms and the wall-clock
           playhead never reads the stream. *)
        Panel[Column[{
            (* SOURCE: highlight (play) <-> editor (edit).  The highlight self-refreshes off the
               shared `phase`.  Click it to edit; type, then Enter or the apply Button. *)
            Dynamic[
                If[editing,
                    Column[{
                        Row[{
                            EventHandler[
                                InputField[Dynamic[src, (src = #) &], String, ContinuousAction -> True,
                                    FieldSize -> {Scaled[0.7], 1},
                                    BaseStyle -> {FontFamily -> "Source Code Pro", FontSize -> 16, FontColor -> GrayLevel[0.9]}],
                                {"ReturnKeyDown" :> (
                                    curPat = Track[src]; sched = scheduleOf[curPat, n];
                                    Quiet @ AudioStop[stream]; stream = AudioStream[Audio[curPat, n], Looping -> True];
                                    registerStream[id, stream, n]; editing = False)}],
                            Spacer[8],
                            Button[Style["\:25b6 apply", 13], (
                                curPat = Track[src]; sched = scheduleOf[curPat, n];
                                Quiet @ AudioStop[stream]; stream = AudioStream[Audio[curPat, n], Looping -> True];
                                registerStream[id, stream, n]; editing = False)]
                        }, Alignment -> Center],
                        Dynamic[Style["\:2192 " <> src, 11, GrayLevel[0.5], FontFamily -> "Source Code Pro"]]
                    }, Alignment -> Left, Spacings -> 0.3],
                    Button[
                        Tooltip[Dynamic @ Refresh[highlightedString[src, activeSpans[sched, clockPhase[n], n]],
                            TrackedSymbols :> {}, UpdateInterval -> 0.04], "click to edit"],
                        editing = True, Appearance -> None]
                ],
                TrackedSymbols :> {editing}
            ],
            (* VISUAL: built ONCE; the self-updating inner Dynamics drive the playhead/wave each
               frame off the transport clock.  Rebuilt only on edit (curPat/stream change) or on
               enable/disable ($Streams).  Click = global play/pause, right-click = disable/enable
               this track, double-click = solo (only this). *)
            insetClicks[
                Dynamic[frameIfDisabled[id, renderVisuals[viss, curPat, n, stream]],
                    TrackedSymbols :> {curPat, stream, $Streams}],
                viss,
                {{"MouseDown", 1} :> (If[AbsoluteTime[] - lastClick < 0.3, soloStream[id, stream, n], If[$Playing, TrackPause[], TrackPlay[]]]; lastClick = AbsoluteTime[]),
                 {"MouseDown", 2} :> If[enabledQ[id], (Quiet @ AudioStop[stream]; unregisterStream[id]), registerStream[id, stream, n]]}]
        }, Spacings -> 0.5, Alignment -> Left], Background -> GrayLevel[0.1], FrameMargins -> 10],
        (* start the clock + audio together on first appearance.  NO SaveDefinitions: the edit's
           reparse needs the LIVE grammar. *)
        Initialization :> (registerStream[id, stream, n]; If[solo, soloStream[id, stream, n]]; If[! $Playing, TrackPlay[]]),
        Deinitialization :> (unregisterStream[id]; Quiet[AudioStop[stream]; RemoveAudioStream[stream]])]]

(* ---------- extractable trace of the dynamic play (for debugging headless) ---------- *)
(* p["Trace", n] returns every event (token, cycle interval, audio-time in seconds, char span)
   PLUS the highlight timeline (phase -> the source substrings lit), so the text<->audio<->visual
   correspondence is fully inspectable without a front end. *)
traceText[src_, span_] := If[ListQ[span] && span =!= None, StringTake[src, {span[[1]], span[[2]] - 1}], Missing[]]
traceOf[pat_, n_, steps_] := Module[{src = pat["Source"], events, sched, cs = N[1/$CyclesPerSecond]},
    events = SortBy[Select[pat["Query", 0, n], onsetQ], #["Whole"][[1]] &];
    sched = scheduleOf[pat, n];
    <|
        "Source" -> src, "Visual" -> visualOf[pat], "Cycles" -> n, "CycleSeconds" -> cs,
        "Events" -> (<|"Token" -> #["Value"], "Cycle" -> N[#["Whole"]], "AudioTime" -> N[#["Whole"][[1]] cs],
                       "Span" -> #["Source"], "Text" -> traceText[src, #["Source"]]|> & /@ events),
        "Highlight" -> Table[With[{ph = N[n k/steps]},
            <|"Phase" -> ph, "Lit" -> (traceText[src, #] & /@ activeSpans[sched, ph, n])|>], {k, 0, steps - 1}]
    |>
]
WolfAnim`Track[q_, m___]["Trace", n_ : 2, steps_ : 32] := traceOf[Track[q, m], n, steps]

WolfAnim`Track /: MakeBoxes[p : WolfAnim`Track[_, meta_Association] /; KeyExistsQ[meta, "Source"], TraditionalForm] :=
    With[{boxes = ToBoxes[miniDisplay[p, cyclesOf[p]]]}, InterpretationBox[boxes, p]]


