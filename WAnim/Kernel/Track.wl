(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Track, TrackSpeed, TrackShift, TrackSequence, TrackAlternate, TrackEvery, TrackEuclid, TrackDegrade, TrackSuperimpose,
    TrackStruct, TrackScale, TrackPulse, $CyclesPerSecond}]

PackageScoped[{patQ, queryOf, hasOnset, restQ, valuePitches, labelOf, midiName, setMeta, metaOf, voicesOf, cyclesOf, steady, silence,
    layer, timecat, fastcatList, chainNum, patSource}]


(* ::Section:: *)
(*Track: a pattern of events in cyclic time*)

(* A Track is a pure function of exact-rational time: asked for a span of cycles, it returns the timed
   events that fall in it -- the TidalCycles / Strudel "Pattern = query : span -> [event]", with WL's
   rationals for time.  Track[query, meta] is one voice; Track[{voice, ...}, meta] stacks voices, each
   keeping its own instrument.  The meta association carries the mini-notation "Source" (so every
   combinator round-trips to editable text), the voice's "Instrument", the "Mixer" and the live view.
   An event is <|"Value" -> v, "Whole" -> {b, e}, "Part" -> {pb, pe}|>, optionally with a "Velocity":
   the whole is the note's extent, the part the slice inside the query. *)

(* the tempo live tracks play at: 0.5625 cycles per second is 135 BPM at four beats a cycle *)
$CyclesPerSecond = 0.5625;

patQ[x_] := MatchQ[x, Track[_Function | _Symbol, ___]];
queryOf[Track[q : (_Function | _Symbol), ___]] := q;
queryOf[Track[vs_List, ___]] := Function[span, Join @@ (queryOf[#][span] & /@ vs)];

sam[t_] := Floor[t];
nextSam[t_] := Floor[t] + 1;
hasOnset[ev_] := ev["Whole"] =!= None && ev["Part"][[1]] == ev["Whole"][[1]];
(* a span broken into pieces that never cross a cycle boundary *)
spanCycles[{b_, e_}] /; b >= e := {};
spanCycles[{b_, e_}] /; e <= nextSam[b] := {{b, e}};
spanCycles[{b_, e_}] := Prepend[spanCycles[{nextSam[b], e}], {b, nextSam[b]}];
(* a function applied to every time of an event, keeping its other keys *)
mapEventTime[f_][ev_] := <|ev, "Whole" -> If[ev["Whole"] === None, None, f /@ ev["Whole"]], "Part" -> f /@ ev["Part"]|>;

(* queries, for one voice or a stack *)
(t_Track)["Query", b_, e_] := queryOf[t][{b, e}];
(t_Track)["Onsets", b_ : 0, e_ : 1] := Select[queryOf[t][{b, e}], hasOnset];
(t_Track)["Source"] := Lookup[metaOf[t], "Source", None];
(t_Track)["Voices"] := voicesOf[t];
(t_Track)["Cycles"] := cyclesOf[t];

metaOf[Track[_, m_Association]] := m;
metaOf[_Track] := <||>;
setMeta[Track[q_, m_Association : <||>], k_, v_] := Track[q, <|m, k -> v|>];
(* the voices a track sounds with, a stack flattened *)
voicesOf[Track[vs_List, ___]] := Join @@ (voicesOf /@ vs);
voicesOf[t_Track] := {t};
(* how many cycles it shows and loops: its "Cycles", else the longest of its voices', else 2 *)
cyclesOf[t_Track] := Lookup[metaOf[t], "Cycles", Replace[t, {Track[vs : {__}, ___] :> Max[cyclesOf /@ vs], _ -> 2}]];


(* ::Subsection:: *)
(*Constructors*)

(* one event a cycle carrying v, and the empty pattern *)
steady[v_] := Track[Function[span, Function[piece, <|"Value" -> v, "Whole" -> {sam[piece[[1]]], nextSam[piece[[1]]]}, "Part" -> piece|>] /@ spanCycles[span]]];
silence = Track[Function[span, {}]];
Track[] := silence;

(* Track[{{onset, duration, value}, ...}] plays exactly those events (a fourth element is the velocity):
   linear time rather than a cycle, for a score written out note by note *)
eventRowsQ[l_] := MatchQ[l, {{_ ? NumericQ, _ ? NumericQ, _, ___} ..}];
Track[rows_List ? eventRowsQ] := With[{ev = SortBy[rows, First]}, Track[Function[span, eventsIn[ev, span]]]];
eventsIn[ev_, {b_, e_}] := Map[<|"Value" -> #[[3]], "Whole" -> {#[[1]], #[[1]] + #[[2]]}, "Part" -> {Max[b, #[[1]]], Min[e, #[[1]] + #[[2]]]},
    "Velocity" -> If[Length[#] > 3, #[[4]], 1]|> &, Select[ev, #[[1]] < e && #[[1]] + #[[2]] > b &]];

(* voices stack: Track[a, b, ...] is Track[{a, b, ...}], mini-notation strings included *)
voiceLikeQ[v_] := StringQ[v] || MatchQ[v, _Track];
Track[a_ ? voiceLikeQ, b__ ? voiceLikeQ] := Track[Replace[{a, b}, s_String :> Track[s], {1}]];
Track[t_Track] := t;


(* ::Subsection:: *)
(*Operations*)

(* An operation applied to a pattern that has a source appends " // op" to it, so the result is still
   editable text that parses back to the same pattern (MiniNotation.wl reads the chain).  Applied to
   a stack it applies to each voice. *)
patSource[t_Track] := Lookup[metaOf[t], "Source", None];
patSource[_] := None;
chainNum[r_] := Which[IntegerQ[r], ToString[r], Head[r] === Rational, ToString[r, InputForm], True, ToString[N[r]]];
chain[p_, frag_, derived_] := With[{s = patSource[p]}, If[s === None, derived, setMeta[derived, "Source", s <> " // " <> frag]]];
(* the result of an operation keeps the voice's instrument and view, but not its source *)
derive[p_, q_] := Track[q, KeyDrop[metaOf[p], "Source"]];

onVoices[op_] := (op[args___][Track[vs_List, m___]] := Track[op[args] /@ vs, m]);
Scan[onVoices, {TrackSpeed, TrackShift, TrackEvery, TrackEuclid, TrackDegrade, TrackSuperimpose, TrackStruct, TrackScale}];

(* TrackSpeed[r] plays r times faster (r < 1 slower) *)
TrackSpeed[r_][p_ ? patQ] := With[{q = queryOf[p]}, chain[p, If[r >= 1 || ! NumericQ[r], "fast " <> chainNum[r], "slow " <> chainNum[1 / r]],
    derive[p, Function[span, mapEventTime[# / r &] /@ q[r # & /@ span]]]]];

(* TrackShift[t] plays t cycles later (t < 0 earlier) *)
TrackShift[t_][p_ ? patQ] := With[{q = queryOf[p]}, chain[p, If[t >= 0, "late " <> chainNum[t], "early " <> chainNum[-t]],
    derive[p, Function[span, mapEventTime[# + t &] /@ q[# - t & /@ span]]]]];

(* Reverse plays each cycle backwards *)
Track /: Reverse[p : Track[_Function | _Symbol, ___]] := With[{q = queryOf[p]}, chain[p, "rev", derive[p, Function[span, Join @@ (reverseCycle[q, #] & /@ spanCycles[span])]]]];
Track /: Reverse[Track[vs_List, m___]] := Track[Reverse /@ vs, m];
reverseCycle[q_, {b_, e_}] := With[{c = sam[b]}, With[{reflect = Function[{x, y}, {2 c + 1 - y, 2 c + 1 - x}]},
    <|#, "Whole" -> If[#["Whole"] === None, None, reflect @@ #["Whole"]], "Part" -> reflect @@ #["Part"]|> & /@ q[reflect[b, e]]]];

(* layer: the events of several patterns as one voice (mini-notation's "a, b") *)
layer[p_] := p;
layer[ps__] := Track[Function[span, Join @@ (queryOf[#][span] & /@ {ps})]];

(* TrackAlternate[a, b, ...] plays one pattern a cycle, in turn (mini-notation's <a b>) *)
TrackAlternate[p_] := asPattern[p];
TrackAlternate[ps__] := With[{pats = asPattern /@ {ps}, n = Length[{ps}]}, Track[Function[span, Join @@ (alternateCycle[pats, n, #] & /@ spanCycles[span])]]];
alternateCycle[pats_, n_, {b_, e_}] := With[{c = sam[b]}, With[{off = c - Floor[c / n]},
    mapEventTime[# + off &] /@ pats[[Mod[c, n] + 1]]["Query", b - off, e - off]]];
asPattern[s_String] := Track[s];
asPattern[t_Track] := t;

(* TrackSequence[a, b, ...] plays the patterns one after another within each cycle *)
TrackSequence[ps__] := fastcatList[asPattern /@ {ps}];
fastcatList[{p_}] := p;
fastcatList[ps_List] := timecat[{1, #} & /@ ps];
(* concatenate within one cycle, each pattern taking a slot in proportion to its weight; in every
   cycle c a pattern's own cycle c is squeezed into its slot, so a nested <a b> still alternates *)
timecat[{{_, p_}}] := p;
timecat[items_List] := With[{ws = items[[All, 1]], ps = items[[All, 2]]}, With[{bounds = Accumulate[Prepend[ws, 0]] / Total[ws]},
    Track[Function[span, Join @@ MapThread[catSlice[#1, #2, #3, span] &, {ps, Most[bounds], Rest[bounds]}]]]]];
catSlice[p_, b_, e_, span_] := Join @@ (Function[piece, With[{c = sam[piece[[1]]]},
    With[{sb = Max[piece[[1]], c + b], se = Min[piece[[2]], c + e]},
        If[sb >= se, {}, With[{toC = Function[t, c + (t - c - b) / (e - b)], fromC = Function[t, c + b + (t - c) (e - b)]},
            mapEventTime[fromC] /@ p["Query", toC[sb], toC[se]]]]]]] /@ spanCycles[span]);

(* TrackEvery[n, f] applies f on every nth cycle *)
TrackEvery[n_, f_][p_ ? patQ] := With[{q = queryOf[p], fq = queryOf[f[Track[queryOf[p]]]]}, chain[p, "every " <> ToString[n] <> " " <> chainFnName[f],
    derive[p, Function[span, Join @@ (If[Mod[sam[#[[1]]], n] == 0, fq[#], q[#]] & /@ spanCycles[span])]]]];
chainFnName[Reverse] := "rev";
chainFnName[f_] := ToString[f, InputForm];

(* TrackEuclid[k, n] plays on k of n steps, spread as evenly as possible (Bjorklund); rot rotates it *)
TrackEuclid[k_, n_, rot_ : 0][p_ ? patQ] := chain[p, "euclid " <> ToString[k] <> " " <> ToString[n] <> If[rot == 0, "", " " <> ToString[rot]],
    derive[p, queryOf[fastcatList[If[#, Track[queryOf[p]], silence] & /@ RotateLeft[bjorklund[k, n], rot]]]]];
bjorklund[k_, n_] := Which[k <= 0, ConstantArray[False, n], k >= n, ConstantArray[True, n], True, bjork[ConstantArray[{True}, k], ConstantArray[{False}, n - k]]];
bjork[a_, b_] := If[Length[b] <= 1, Flatten[Join[a, b]], With[{m = Min[Length[a], Length[b]]},
    bjork[Table[Join[a[[i]], b[[i]]], {i, m}], If[Length[a] > m, a[[m + 1 ;;]], b[[m + 1 ;;]]]]]];

(* TrackDegrade[x] drops a fraction x of the events, the same ones every time *)
TrackDegrade[x_][p_ ? patQ] := With[{q = queryOf[p]}, chain[p, "degrade " <> chainNum[x],
    derive[p, Function[span, Select[q[span], Mod[Hash[{#["Whole"], #["Value"]}], 1000] / 1000. >= x &]]]]];

(* TrackSuperimpose[f] plays the pattern together with f of it; TrackSuperimpose[f, t] shifts that t cycles later *)
TrackSuperimpose[f_, t_ : 0][p_ ? patQ] := derive[p, queryOf[layer[p, TrackShift[t][f[p]]]]];

(* TrackStruct["1 ~ 1 1"] plays the pattern's value on the steps marked 1; TrackStruct[positions, steps]
   on the given step positions of a cycle cut into steps (Strudel's struct and beat) *)
TrackStruct[mask_String][p_ ? patQ] := With[{toks = StringSplit[mask]}, TrackStruct[Flatten[Position[toks, "1" | "t" | "x"]] - 1, Length[toks]][p]];
TrackStruct[pos_, steps_][p_ ? patQ] := With[{ps = Sort[N @ If[StringQ[pos], ToExpression /@ StringSplit[pos, ","], pos]]},
    derive[p, Function[span, Join @@ (structCycle[ps, steps, p, #] & /@ spanCycles[span])]]];
structCycle[ps_, steps_, p_, {b_, e_}] := With[{c = Floor[b]}, With[{ons = c + ps / steps}, With[{nxt = Append[Rest[ons], c + 1]},
    DeleteCases[MapThread[Function[{on, nx}, With[{val = valueAt[p, on]},
        If[on < e && nx > b && ! MissingQ[val], <|"Value" -> val, "Whole" -> {on, nx}, "Part" -> {Max[on, b], Min[nx, e]}|>, Nothing]]], {ons, nxt}], Nothing]]]];
valueAt[p_, t_] := With[{evs = Select[p["Query", Floor[t], Floor[t] + 1], #["Whole"] =!= None && #["Whole"][[1]] <= t < #["Whole"][[2]] &]},
    If[evs === {}, Missing[], First[evs]["Value"]]];

(* TrackScale["C:minor"] reads integer values as degrees of the scale: 0 the root, negative below *)
$scales = <|"major" -> {0, 2, 4, 5, 7, 9, 11}, "minor" -> {0, 2, 3, 5, 7, 8, 10}, "dorian" -> {0, 2, 3, 5, 7, 9, 10}, "phrygian" -> {0, 1, 3, 5, 7, 8, 10},
    "lydian" -> {0, 2, 4, 6, 7, 9, 11}, "mixolydian" -> {0, 2, 4, 5, 7, 9, 10}, "locrian" -> {0, 1, 3, 5, 6, 8, 10}, "majpent" -> {0, 2, 4, 7, 9},
    "minpent" -> {0, 3, 5, 7, 10}, "ionian" -> {0, 2, 4, 5, 7, 9, 11}, "aeolian" -> {0, 2, 3, 5, 7, 8, 10}|>;
TrackScale[] := Keys[$scales];
TrackScale[spec_String][p_ ? patQ] := With[{parts = StringSplit[ToLowerCase[spec], ":"], q = queryOf[p]},
    With[{root = Quiet @ Check[MusicPitch[If[StringContainsQ[parts[[1]], DigitCharacter], parts[[1]], parts[[1]] <> "4"]]["MIDINumber"], 60],
            ints = Lookup[$scales, If[Length[parts] > 1, parts[[2]], "major"], $scales["major"]]},
        chain[p, "sc " <> spec, derive[p, Function[span, <|#, "Value" -> scaleDegree[root, ints, #["Value"]]|> & /@ q[span]]]]]];
scaleDegree[root_, ints_, d_Integer] := root + 12 Quotient[d, Length[ints]] + ints[[Mod[d, Length[ints]] + 1]];
scaleDegree[root_, ints_, v_String] /; StringMatchQ[v, ("-" | "") ~~ DigitCharacter ..] := scaleDegree[root, ints, ToExpression[v]];
scaleDegree[_, _, v_] := v;


(* ::Subsection:: *)
(*Values*)

(* a value's MIDI pitches: a note name ("c4"), a MIDI number, a MusicPitch, MusicNote or MusicChord;
   none for a drum name *)
valueMidi[v_Integer] := v;
valueMidi[v_String] := Quiet @ Check[MusicPitch[v]["MIDINumber"], Missing[]];
valueMidi[mp_MusicPitch] := Quiet @ Check[mp["MIDINumber"], Missing[]];
valueMidi[mn_MusicNote] := Quiet @ Check[mn["Pitch"]["MIDINumber"], Missing[]];
valueMidi[_] := Missing[];
valuePitches[mc_MusicChord] := Quiet @ Check[#["MIDINumber"] & /@ mc["PitchList"], {}];
valuePitches[v_] := With[{m = valueMidi[v]}, If[NumericQ[m], {Round[m]}, {}]];
(* a rest "~" is an event that takes its step and lights up in the source, but makes no sound *)
restQ[v_] := v === "~";
midiName[m_] := Quiet @ Check[ToString[MusicPitch[Round @ m]["Key"]] <> ToString[MusicPitch[Round @ m]["Octave"]], ToString[Round @ m]];
labelOf[v_String] := v;
labelOf[v_] := With[{ps = valuePitches[v]}, If[ps === {}, ToString[v, InputForm], StringRiffle[midiName /@ ps, "+"]]];


(* ::Subsection:: *)
(*Notation*)

(* track["MusicPlot", n] and track["Sound", n]: each voice as a MusicVoice, simultaneous notes as chords *)
eventsToVoice[events_, n_] := Module[{items = {}, t = 0, dur, pitches},
    KeyValueMap[(dur = Min[#2[[All, "Whole"]] /. {b_, e_} :> e - b];
        If[#1 > t, AppendTo[items, MusicRest[#1 - t]]];
        pitches = Union @@ (valuePitches[#["Value"]] & /@ #2);
        AppendTo[items, Which[pitches === {}, MusicRest[dur], Length[pitches] == 1, MusicNote[pitches[[1]], dur], True, MusicChord[pitches, dur]]];
        t = Max[t, #1] + dur) &, KeySort @ GroupBy[events, #["Whole"][[1]] &]];
    If[t < n, AppendTo[items, MusicRest[n - t]]];
    MusicVoice[If[items === {}, {MusicRest[n]}, items]]];
trackScore[t_, n_] := MusicScore[eventsToVoice[Select[#["Query", 0, n], hasOnset[#] && ! restQ[#["Value"]] &], n] & /@ voicesOf[t],
    MusicTimeSignature[4, 4], MusicTempo -> 240 $CyclesPerSecond];
(t_Track)["MusicPlot", n : (_ ? NumericQ | Automatic) : Automatic, opts___] := MusicPlot[trackScore[t, Replace[n, Automatic :> cyclesOf[t]]], opts];
(t_Track)["Sound", n : (_ ? NumericQ | Automatic) : Automatic] := Sound[trackScore[t, Replace[n, Automatic :> cyclesOf[t]]]];


(* ::Section:: *)
(*Picture locked to sound*)

(* TrackPulse[track, decay][t] is 1 at each onset of the track and decays exponentially (decay per
   cycle) until the next: the kick that makes a picture hop, read off the same Track that sounds it.
   t is in cycles, the unit an AnimatedGraphics counts in. *)
TrackPulse[track_Track, decay_ : 18][t_] := With[{on = Quiet @ track["Onsets", t - 4, t + 10^-9]},
    If[! ListQ[on] || on === {}, 0., N @ Exp[-decay (t - Max[#["Whole"][[1]] & /@ on])]]];
