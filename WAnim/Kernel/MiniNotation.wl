(* ::Package:: *)

(* Mini-notation: Track["bd [~ bd] sd, hh*8"] parsed with the Wolfram`Parser` paclet into an AST whose
   atoms keep their character spans.  The Track holds its source and AST, so its TraditionalForm is the
   source itself, editable, each atom lighting up the instant its events sound; editing re-parses and
   re-plays it live. *)



(* ---------- grammar: mini-notation -> neutral AST, each atom carrying a {start,end} char span ---------- *)
$grammar := $grammar = Module[
    {seqCell, space, optSpace, number, atom, element, modifier, step, seq, sub, alt, comma},
    seqCell  = RecCell[];
    space    = ParseRegex[" +"];
    optSpace = ParseRegex[" *"];
    number   = ParseRegex["[0-9]+"];
    (* SpannedToken stamps Source -> {start, end} (cursor offsets: covers chars start..end-1).
       `:` lets a token carry a sample index (bd:3, Strudel-style). *)
    atom = SpannedToken[ParseRegex["[A-Za-z0-9#.~_:-]+"], ParseSucceed[Null], Function[s, LeafNode["Atom", s, <||>]]];
    comma = ParseAction[optSpace ~~ ParseLiteral[","] ~~ optSpace, #1 &];
    sub = ParseAction[ParseLiteral["["] ~~ optSpace ~~ ParseSepBy[RecRef[seqCell], comma] ~~ optSpace ~~ ParseLiteral["]"],
        Function[{lb, s1, seqs, s2, rb}, If[Length[seqs] == 1, GroupNode["Sub", seqs, <||>], GroupNode["Stack", seqs, <||>]]]];
    alt = ParseAction[ParseLiteral["<"] ~~ optSpace ~~ RecRef[seqCell] ~~ optSpace ~~ ParseLiteral[">"],
        Function[{lb, s1, sq, s2, rb}, GroupNode["Alt", If[MatchQ[sq, GroupNode["Seq", _, _]], sq[[2]], {sq}], <||>]]];
    element = ParseChoice[sub, alt, atom];
    modifier = ParseChoice[
        ParseAction[ParseLiteral["*"] ~~ number, Function[{st, num}, {"Fast", FromDigits[num]}]],
        ParseAction[ParseLiteral["/"] ~~ number, Function[{st, num}, {"Slow", FromDigits[num]}]],
        ParseAction[ParseLiteral["!"] ~~ number, Function[{st, num}, {"Repl", FromDigits[num]}]],
        ParseAction[ParseLiteral["@"] ~~ number, Function[{st, num}, {"Weight", FromDigits[num]}]],
        ParseAction[ParseLiteral["("] ~~ number ~~ ParseLiteral[","] ~~ number ~~ ParseLiteral[")"], Function[{lp, k, cm, n, rp}, {"Euclid", FromDigits[k], FromDigits[n]}]]];
    step = ParseAction[element ~~ ParseMany[modifier],
        Function[{el, mods}, Fold[Function[{e, m}, GroupNode[m[[1]], {e}, <|"Args" -> Rest[m]|>]], el, mods]]];
    seq = ParseAction[step ~~ ParseMany[ParseAction[space ~~ step, #2 &]],
        Function[{h, t}, If[t === {}, h, GroupNode["Seq", Prepend[t, h], <||>]]]];
    SetRec[seqCell, seq];
    (* a top-level "a b, c d" stacks its sequences, as Strudel does (no brackets needed) *)
    ParseAction[optSpace ~~ ParseSepBy[seq, comma] ~~ optSpace,
        Function[{s1, seqs, s2}, If[Length[seqs] == 1, First[seqs], GroupNode["Stack", seqs, <||>]]]]
]

parseMini[str_String] := With[{r = Quiet @ Check[Parse[$grammar, str], $Failed]}, If[FailureQ[r], $Failed, r]]

(* ---------- AST -> Track, tagging each atom's events with its char span ---------- *)
tagSpan[span_][cp_] := With[{q = First[cp]}, Track[Function[sp, (Append[#, "Source" -> span] &) /@ q[sp]]]]
(* a rest "~" is still an EVENT: tag it like any atom so its step highlights in the source and
   occupies the cycle, but it carries the value "~" which the audio + roll skip (see restQ). *)
ap[LeafNode["Atom", v_, m_]]   := tagSpan[m["Source"]][steady[v]]
(* a sequence is a WEIGHTED cat (Tidal timecat): x@3 takes 3 slots, `_` (hold) extends the
   previous step by one slot, everything else weighs 1 *)
holdQ[LeafNode["Atom", "_", _]] := True
holdQ[_] := False
stepWeight[GroupNode["Weight", {x_}, m_]] := {m["Args"][[1]], x}
stepWeight[nd_] := {1, nd}
seqItems[nodes_] := Fold[Function[{acc, nd},
    If[holdQ[nd],
        If[acc === {}, acc, ReplacePart[acc, {-1, 1} -> acc[[-1, 1]] + 1]],
        Append[acc, stepWeight[nd]]]], {}, nodes]
ap[GroupNode["Seq", st_, _]]   := timecat[{#[[1]], ap[#[[2]]]} & /@ seqItems[st]]
ap[GroupNode["Weight", {x_}, _]] := ap[x]   (* a lone x@n outside a seq is just x *)
ap[GroupNode["Sub", {x_}, _]]  := ap[x]
ap[GroupNode["Stack", ss_, _]] := layer @@ (ap /@ ss)
ap[GroupNode["Alt", st_, _]]   := TrackAlternate @@ (ap /@ st)
(* replicate: hh!8 = eight hh as eight separate steps in the cycle (unlike hh*8 = speed up) *)
ap[GroupNode["Repl", {x_}, m_]]   := TrackSequence @@ ConstantArray[ap[x], m["Args"][[1]]]
ap[GroupNode["Fast", {x_}, m_]]   := TrackSpeed[m["Args"][[1]]] @ ap[x]
ap[GroupNode["Slow", {x_}, m_]]   := TrackSpeed[1 / m["Args"][[1]]] @ ap[x]
ap[GroupNode["Euclid", {x_}, m_]] := TrackEuclid[m["Args"][[1]], m["Args"][[2]]] @ ap[x]
ap[_] := silence

(* override the string constructor: parse to AST, derive the query, HOLD source + AST *)
(* A source string is mini-notation, optionally followed by a postfix " // <op>" chain (fast, slow,
   rev, degrade, euclid, every, late, early, sc, and the sound: sound, gain, pan, room, delay, dec).
   It is the inverse of the source the operations append (Track.wl `chain`), so TrackSpeed[2][p] and
   Track["... // fast 2"] are the same pattern. *)
Track[str0_String] := With[{str = StringTrim[str0]},
    If[StringContainsQ[str, "//"],
        Fold[applyChainStep, Track[StringTrim @ First @ StringSplit[str, "//"]],
            StringTrim /@ Rest @ StringSplit[str, "//"]],
        With[{ast = parseMini[str]},
            (* a typo must not fail silently while live coding: say so, and play nothing *)
            If[ast === $Failed, Message[Track::parse, str]; silence, Track[First[ap[ast]], <|"Source" -> str, "AST" -> ast|>]]]]]
Track::parse = "Could not parse the mini-notation \"`1`\"; the track is silent.";

parseChainNum[s_] := Which[
    StringContainsQ[s, "/"], With[{ab = ToExpression /@ StringSplit[s, "/"]}, ab[[1]]/ab[[2]]],
    True, ToExpression[s]]   (* handles ints, decimals AND negatives (FromDigits chokes on "-") *)
chainFnOf[name_] := Switch[name, "rev", Reverse, _, Identity]
applyChainStep[pat_, stepStr_] := With[{toks = StringSplit[stepStr]},
    Switch[First[toks, ""],
        "fast", TrackSpeed[parseChainNum[toks[[2]]]][pat],
        "slow", TrackSpeed[1 / parseChainNum[toks[[2]]]][pat],
        "rev", Reverse[pat],
        "degrade", TrackDegrade[If[Length[toks] >= 2, parseChainNum[toks[[2]]], 0.5]][pat],
        "euclid", TrackEuclid[FromDigits[toks[[2]]], FromDigits[toks[[3]]], If[Length[toks] >= 4, FromDigits[toks[[4]]], 0]][pat],
        "every", TrackEvery[FromDigits[toks[[2]]], chainFnOf[toks[[3]]]][pat],
        "late", TrackShift[parseChainNum[toks[[2]]]][pat],
        "early", TrackShift[-parseChainNum[toks[[2]]]][pat],
        "sc", TrackScale[toks[[2]]][pat],
        "sound", Instrument[toks[[2]]][pat],
        "gain", Instrument["Gain" -> parseChainNum[toks[[2]]]][pat],
        "pan", Instrument["Pan" -> parseChainNum[toks[[2]]]][pat],
        "room", Instrument["Reverb" -> parseChainNum[toks[[2]]]][pat],
        "delay", Instrument["Delay" -> parseChainNum[toks[[2]]]][pat],
        "dec", Instrument["Decay" -> parseChainNum[toks[[2]]]][pat],
        _, pat]]


(* ---------- editable, event-highlighting TraditionalForm ---------- *)
scheduleOf[pat_, n_] := GroupBy[Select[pat["Query", 0, n], hasOnset], #["Source"] &, Function[es, #["Whole"] & /@ es]]
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
   The view (visualsOf[pat]: PianoRoll/Punchcard/Oscilloscope/Bar) is the SAME one StandardForm shows,
   rendered from `renderVisual` (shared from Pattern.wl).  Two states via `editing`:
     - editing=False: ONE refreshing Dynamic draws [highlight] over [visual], 30 ms ticks.
     - editing=True : a stable InputField (no refresh, so the cursor survives) over the visual.
   `curPat` tracks the live-parsed pattern so an edit also updates the piano-roll visual. *)
miniDisplay[pat_, n_ : 2] := With[{source = pat["Source"], viss = visualsOf[pat], solo = soloFlagQ[pat], defs = userDefinitions[pat]},
    DynamicModule[{id = Unique[], src = source, curPat = pat, stream = AudioStream[renderAudio[pat, n, True], Looping -> True],
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
                                    Quiet @ AudioStop[stream]; stream = AudioStream[renderAudio[curPat, n, True], Looping -> True];
                                    registerStream[id, stream, n]; editing = False)}],
                            Spacer[8],
                            Button[Style["\:25b6 apply", 13], (
                                curPat = Track[src]; sched = scheduleOf[curPat, n];
                                Quiet @ AudioStop[stream]; stream = AudioStream[renderAudio[curPat, n, True], Looping -> True];
                                registerStream[id, stream, n]; editing = False)]
                        }, Alignment -> Center],
                        Dynamic[Style["\:2192 " <> src, 11, GrayLevel[0.5], FontFamily -> "Source Code Pro"]]
                    }, Alignment -> Left, Spacings -> 0.3],
                    Button[
                        Tooltip[Dynamic @ Refresh[highlightedString[src, activeSpans[sched, visPhase[n], n]],
                            TrackedSymbols :> {}, UpdateInterval -> 0.04], "click to edit"],
                        editing = True, Appearance -> None]
                ],
                TrackedSymbols :> {editing}
            ],
            (* VISUAL: built ONCE; the self-updating inner Dynamics drive the playhead/wave each
               frame off the transport clock.  Rebuilt only on edit (curPat/stream change) or on
               enable/disable ($Streams).  Click = global play/pause, right-click = disable/enable
               this track, double-click = solo (only this). *)
            EventHandler[
                Dynamic[frameIfDisabled[id, renderVisuals[viss, curPat, n, stream]],
                    TrackedSymbols :> {curPat, stream, $Streams}],
                {{"MouseDown", 1} :> (If[AbsoluteTime[] - lastClick < 0.3, soloStream[id, stream, n], If[$Playing, TrackPause[], TrackPlay[]]]; lastClick = AbsoluteTime[]),
                 {"MouseDown", 2} :> If[enabledQ[id], (Quiet @ AudioStop[stream]; unregisterStream[id]), registerStream[id, stream, n]]}]
        }, Spacings -> 0.5, Alignment -> Left], Background -> GrayLevel[0.1], FrameMargins -> 10],
        (* start the clock + audio together on first appearance.  Saving definitions leaves out the
           package's internal symbols, so an edit's reparse still uses the LIVE grammar. *)
        Initialization :> (Needs["WolframInstitute`WAnim`"]; restoreDefinitions[defs];
            If[! MemberQ[AudioStreams[], stream], stream = AudioStream[renderAudio[curPat, n, True], Looping -> True]];
            registerStream[id, stream, n]; If[solo, soloStream[id, stream, n]]; If[! $Playing, TrackPlay[]]),
        Deinitialization :> (unregisterStream[id]; Quiet[AudioStop[stream]; RemoveAudioStream[stream]])]]

(* ---------- extractable trace of the dynamic play (for debugging headless) ---------- *)
(* p["Trace", n] returns every event (token, cycle interval, audio-time in seconds, char span)
   PLUS the highlight timeline (phase -> the source substrings lit), so the text<->audio<->visual
   correspondence is fully inspectable without a front end. *)
traceText[src_, span_] := If[ListQ[span] && span =!= None, StringTake[src, {span[[1]], span[[2]] - 1}], Missing[]]
traceOf[pat_, n_, steps_] := Module[{src = pat["Source"], events, sched, cs = N[1/$CyclesPerSecond]},
    events = SortBy[Select[pat["Query", 0, n], hasOnset], #["Whole"][[1]] &];
    sched = scheduleOf[pat, n];
    <|
        "Source" -> src, "Visual" -> visualsOf[pat][[1, 1]], "Cycles" -> n, "CycleSeconds" -> cs,
        "Events" -> (<|"Token" -> #["Value"], "Cycle" -> N[#["Whole"]], "AudioTime" -> N[#["Whole"][[1]] cs],
                       "Span" -> #["Source"], "Text" -> traceText[src, #["Source"]]|> & /@ events),
        "Highlight" -> Table[With[{ph = N[n k/steps]},
            <|"Phase" -> ph, "Lit" -> (traceText[src, #] & /@ activeSpans[sched, ph, n])|>], {k, 0, steps - 1}]
    |>
]
(t_Track)["Trace", n_ : 2, steps_ : 32] := traceOf[t, n, steps]

Track /: MakeBoxes[p : Track[_, meta_Association] /; KeyExistsQ[meta, "Source"], TraditionalForm] :=
    With[{boxes = ToBoxes[miniDisplay[p, cyclesOf[p]]]}, InterpretationBox[boxes, p]]


