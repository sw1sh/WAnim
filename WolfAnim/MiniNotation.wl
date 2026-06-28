(* WolfAnim`MiniNotation`  --  a proper AST parser for the mini-notation, built on the
   Wolfram`Parser` paclet.  It makes CyclicPattern HOLD its source string + AST (as the
   pattern's 2nd metadata arg), and renders an EDITABLE, event-highlighting TraditionalForm:
   the input string is reconstructed as boxes, each atom's characters light up the instant
   its events sound, and editing the field re-parses + re-plays live.

   Requires the Wolfram`Parser` paclet.  Load AFTER WolfAnim:
       PacletDirectoryLoad["<.../WolframParser/Parser>"];   (* or install the paclet *)
       Get["<.../WolfAnim/MiniNotation.wl>"]                                          *)

BeginPackage["WolfAnim`MiniNotation`", {"WolfAnim`", "Wolfram`Parser`"}]

Begin["`Private`"]

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
activeSpans[sched_, phase_, n_] := With[{p = Mod[phase, n]},
    Keys @ Select[sched, AnyTrue[#, #[[1]] <= p < Max[#[[2]], #[[1]] + 0.06] &] &]]
litQ[i_, active_] := AnyTrue[active, #[[1]] <= i < #[[2]] &]   (* span {s,e} covers chars s..e-1 *)
highlightedString[str_, active_] := Row[Table[
    Style[StringTake[str, {i}], Background -> If[litQ[i, active], RGBColor[1, 0.82, 0.3, 0.8], Automatic]],
    {i, StringLength[str]}],
    BaseStyle -> {FontFamily -> "Source Code Pro", FontWeight -> Bold, FontSize -> 17, FontColor -> GrayLevel[0.9]}]

(* one Dynamic both advances the phase from the audio Position AND re-renders the highlighted
   string -- so the highlight tracks the clock directly (no cross-Dynamic dependency to drop). *)
miniDisplay[pat_, n_ : 2] := DynamicModule[{src = pat["Source"], stream = Null, phase = 0., playing = True, sched = <||>},
    reparse[] := Module[{p = CyclicPattern[src]},
        sched = scheduleOf[p, n];
        If[stream =!= Null, Quiet[AudioStop[stream]; RemoveAudioStream[stream]]];
        stream = AudioStream[Audio[p, n], Looping -> True]; AudioPlay[stream]; playing = True];
    reparse[];
    Deploy @ Panel[Column[{
        InputField[Dynamic[src, (src = #; reparse[]) &], String,
            FieldSize -> {Scaled[1], 1}, ContinuousAction -> False,
            BaseStyle -> {FontFamily -> "Source Code Pro", FontSize -> 15}],
        EventHandler[
            Dynamic @ Refresh[
                If[playing && stream =!= Null, phase = QuantityMagnitude[stream["Position"]] $CyclesPerSecond];
                highlightedString[src, activeSpans[sched, phase, n]],
                TrackedSymbols :> {phase, src}, UpdateInterval -> 0.03],
            {
                {"MouseDown", 1} :> If[playing, (AudioStop[stream]; playing = False), (AudioPlay[stream]; playing = True)],
                {"MouseDown", 2} :> (AudioStop[stream]; phase = 0.; playing = False)
            }],
        Dynamic @ Refresh[ProgressIndicator[Mod[phase, n], {0, n}, ImageSize -> {Scaled[1], 3}],
            TrackedSymbols :> {phase}, UpdateInterval -> 0.05]
    }, Spacings -> 0.6], Background -> GrayLevel[0.1], FrameMargins -> 12],
    SaveDefinitions -> True]

WolfAnim`CyclicPattern /: MakeBoxes[p : WolfAnim`CyclicPattern[_, meta_Association] /; KeyExistsQ[meta, "Source"], TraditionalForm] :=
    With[{boxes = ToBoxes[miniDisplay[p, 2]]}, InterpretationBox[boxes, p]]

End[]

EndPackage[]
