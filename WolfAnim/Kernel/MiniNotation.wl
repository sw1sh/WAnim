(* ::Package:: *)

(* WolfAnim`MiniNotation`  --  a proper AST parser for the mini-notation, built on the
   Wolfram`Parser` paclet.  It makes CyclicPattern HOLD its source string + AST (as the
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
        ParseAction[ParseLiteral["("] ~~ number ~~ ParseLiteral[","] ~~ number ~~ ParseLiteral[")"], Function[{lp, k, cm, n, rp}, {"Euclid", FromDigits[k], FromDigits[n]}]]];
    step = ParseAction[element ~~ ParseMany[modifier],
        Function[{el, mods}, Fold[Function[{e, m}, GroupNode[m[[1]], {e}, <|"Args" -> Rest[m]|>]], el, mods]]];
    seq = ParseAction[step ~~ ParseMany[ParseAction[space ~~ step, #2 &]],
        Function[{h, t}, If[t === {}, h, GroupNode["Seq", Prepend[t, h], <||>]]]];
    SetRec[seqCell, seq];
    ParseAction[optSpace ~~ seq ~~ optSpace, #2 &]
]

parseMini[str_String] := Quiet @ Check[Parse[$grammar, str], $Failed]

(* ---------- AST -> CyclicPattern, tagging each atom's events with its char span ---------- *)
tagSpan[span_][cp_] := With[{q = First[cp]}, CyclicPattern[Function[sp, (Append[#, "Source" -> span] &) /@ q[sp]]]]
ap[LeafNode["Atom", "~", _]]   := Silence
ap[LeafNode["Atom", v_, m_]]   := tagSpan[m["Source"]][Steady[v]]
ap[GroupNode["Seq", st_, _]]   := Fastcat @@ (ap /@ st)
ap[GroupNode["Sub", {x_}, _]]  := ap[x]
ap[GroupNode["Stack", ss_, _]] := Layer @@ (ap /@ ss)
ap[GroupNode["Alt", st_, _]]   := Alternate @@ (ap /@ st)
ap[GroupNode["Fast", {x_}, m_]]   := Fast[m["Args"][[1]]] @ ap[x]
ap[GroupNode["Euclid", {x_}, m_]] := Euclidean[m["Args"][[1]], m["Args"][[2]]] @ ap[x]
ap[_] := Silence

(* override the string constructor: parse to AST, derive the query, HOLD source + AST *)
WolfAnim`CyclicPattern[str_String] := With[{ast = parseMini[StringTrim[str]]},
    If[ast === $Failed, Silence, Append[ap[ast], <|"Source" -> StringTrim[str], "AST" -> ast|>]]]


(* ---------- editable, event-highlighting TraditionalForm ---------- *)
onsetQ[ev_] := ev["Whole"] =!= None && ev["Part"][[1]] == ev["Whole"][[1]]
scheduleOf[pat_, n_] := GroupBy[Select[pat["Query", 0, n], onsetQ], #["Source"] &, Function[es, #["Whole"] & /@ es]]
(* flash each atom briefly on every onset (Strudel-style) instead of lighting it for the note's
   whole duration -- so back-to-back repeats (bd*4) pulse in time with the hits rather than
   staying solidly lit (which reads as "out of sync" with the audio).  Window = the note's
   duration, clamped to [0.05, 0.1] cycle. *)
flashEnd[{on_, off_}] := on + Clip[off - on, {0.05, 0.1}]
activeSpans[sched_, phase_, n_] := With[{p = Mod[phase, n]},
    Keys @ Select[sched, AnyTrue[#, #[[1]] <= p < flashEnd[#] &] &]]
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
miniDisplay[pat_, n_ : 2] := With[{source = pat["Source"], vis = visualOf[pat]},
    DynamicModule[{src = source, curPat = pat, stream = AudioStream[Audio[pat, n], Looping -> True],
                   phase = 0., playing = True, editing = False, sched = scheduleOf[pat, n]},
        reparse[] := Module[{p = CyclicPattern[src]},
            curPat = p; sched = scheduleOf[p, n];
            Quiet[AudioStop[stream]; RemoveAudioStream[stream]];
            stream = AudioStream[Audio[p, n], Looping -> True]; Quiet @ AudioPlay[stream]; playing = True];
        Panel[
            Dynamic[
                If[editing,
                    (* EDIT MODE: a plain InputField + the static visual.  Enter or click away applies. *)
                    Column[{
                        Style["editing \[Dash] press Enter or click away to apply", 10, GrayLevel[0.55]],
                        InputField[Dynamic[src, Function[new, src = new; reparse[]; editing = False]], String,
                            FieldSize -> {Scaled[1], 1}, ContinuousAction -> False,
                            BaseStyle -> {FontFamily -> "Source Code Pro", FontSize -> 16}],
                        renderVisual[vis, curPat, n, phase, stream]
                    }, Spacings -> 0.4, Alignment -> Left],
                    (* PLAY MODE: STABLE click targets (a Button to edit, an EventHandler to
                       play/pause), each wrapping a re-rendering Dynamic -- so clicks don't get
                       lost to the 30ms refresh recreating the handler every tick. *)
                    Column[{
                        Button[
                            Tooltip[Dynamic[highlightedString[src, activeSpans[sched, phase, n]]], "click to edit"],
                            (Quiet @ AudioStop[stream]; playing = False; editing = True),
                            Appearance -> None],
                        EventHandler[
                            Dynamic @ Refresh[
                                If[playing, With[{ph = streamPhase[stream]}, If[NumericQ[ph], phase = ph]]];
                                renderVisual[vis, curPat, n, phase, stream],
                                TrackedSymbols :> {}, UpdateInterval -> 0.03],
                            {{"MouseDown", 1} :> If[playing, (Quiet @ AudioStop[stream]; playing = False), (Quiet @ AudioPlay[stream]; playing = True)],
                             {"MouseDown", 2} :> (Quiet @ AudioStop[stream]; phase = 0.; playing = False)}]
                    }, Spacings -> 0.4, Alignment -> Left]
                ],
                TrackedSymbols :> {editing}
            ],
            Background -> GrayLevel[0.1], FrameMargins -> 10
        ],
        (* AudioPlay once on first appearance.  NO SaveDefinitions: the edit's reparse must use
           the LIVE WolframParser grammar (a saved snapshot loses the compiled grammar, so
           CyclicPattern[edited] returned Silence and editing changed nothing). *)
        Initialization :> Quiet @ AudioPlay[stream],
        Deinitialization :> Quiet[AudioStop[stream]; RemoveAudioStream[stream]]]]

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
WolfAnim`CyclicPattern[q_, m___]["Trace", n_ : 2, steps_ : 32] := traceOf[CyclicPattern[q, m], n, steps]

WolfAnim`CyclicPattern /: MakeBoxes[p : WolfAnim`CyclicPattern[_, meta_Association] /; KeyExistsQ[meta, "Source"], TraditionalForm] :=
    With[{boxes = ToBoxes[miniDisplay[p, 2]]}, InterpretationBox[boxes, p]]


