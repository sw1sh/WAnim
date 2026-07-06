(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Steady, Silence, Fast, Slow, Layer, Alternate, Every, Euclidean, Degrade, Track, $CyclesPerSecond, $AudioLatency, $DefaultWave, $DefaultVisual, LoadSamples, Synth, Gain, Late, Early, Stagger, Superimpose, $SampleBank, Oscilloscope, PianoRoll, Punchcard, Beat, Struct, Bars, Solo, TrackPlay, TrackPause, TrackReset, TrackSeek, Fastcat, LiveCode, $LiveAtomHeads}]

(* shared with MiniNotation.wl so the TraditionalForm can render the same live Visual *)
PackageScoped[{renderVisual, renderVisuals, visualsOf, visualOf, cyclesOf, buttonsQ, clockPhase, visPhase, seekStream, registerStream, unregisterStream, enabledQ, soloStream, soloFlagQ, frameIfDisabled, $Playing, $Streams}]



(* ::Section:: A cyclic-time Pattern algebra (one structure, two renderers) *)

(* A Track is a pure function of cyclic, exact-rational time: given a query
   timespan it returns the timed events that fall in it.  This is the TidalCycles /
   Strudel "Pattern = query : TimeSpan -> [Event]" abstraction, transplanted to WL with
   native Rational time.  The SAME pattern is rendered two ways: to sound (MusicScore ->
   Audio) and to vision (a piano roll / AnimatedObject effects).  See
   docs/wolfanim-music-design.md. *)


(* cycles per second; 0.5625 cps = 135 BPM at 4 beats/cycle = TidalCycles' classic feel *)
$CyclesPerSecond = 0.5625

(* seconds every VISUAL (playhead / punchcard line / highlight) is shifted back from the audio
   transport, to compensate output-buffer latency (what you HEAR lags the transport).  Tune it to
   YOUR system: RAISE if the visual runs ahead of the sound, LOWER (toward 0) if it lags behind. *)
$AudioLatency = 0.05

(* default oscillator timbre for pitched notes (Sine/Triangle/Sawtooth/Square/Supersaw). *)
$DefaultWave = "Sawtooth"

(* default live Visual for patterns with none set: "PianoRoll" (labeled blocks), "Bar", "Oscilloscope". *)
$DefaultVisual = "PianoRoll"

(* ONE global transport: a shared clock + a registry of every live stream.  TrackPlay /
   TrackPause / TrackSeek[cyclePos] / TrackReset act on ALL patterns at once, and a newly-created
   player joins at the current clock position.  $Playing is the shared transport state; $Streams
   maps a per-player id to {stream, nCycles}.  In a player: LEFT-click toggles global play/pause;
   RIGHT-click (or the stop button) disables just THAT track -- stops it and drops it from the
   registry so global play/pause no longer touch it; right-click again re-registers/re-enables. *)
(* TRANSPORT clock (not wall clock): it accumulates only the time spent PLAYING, so pausing
   freezes it and resuming continues -- no jump.  $ClockAccum = transport seconds banked while
   paused; $ClockStart = AbsoluteTime[] of the current playing segment (None while paused). *)
$ClockAccum = 0.
$ClockStart = None
$Playing = False
$Streams = <||>
$SoloMaster = None   (* id of the track currently soloing (via double-click / Solo), or None *)
$SoloSaved = <||>    (* the registry entries THIS solo froze, restored verbatim on un-solo *)
clockSeconds[] := If[$ClockStart === None, $ClockAccum, $ClockAccum + (AbsoluteTime[] - $ClockStart)]
clockPhase[n_] := Mod[clockSeconds[] $CyclesPerSecond, n]
(* continuous, unwrapped clock for scrolling visuals; shift back by $AudioLatency so a bar meets
   the line when you HEAR it (output buffering delays the sound behind the transport). *)
clockPhaseRaw[] := (clockSeconds[] - $AudioLatency) $CyclesPerSecond
visPhase[n_] := Mod[clockPhaseRaw[], n]   (* wrapped + latency-compensated: what every visual shows, so the playhead matches the HEARD sound (seekStream still uses the raw clockPhase for the stream position) *)
seekStream[{stream_, n_}] := Quiet[stream["Position"] = Quantity[Mod[clockPhase[n], n] / $CyclesPerSecond, "Seconds"]]
(* a just-created AudioStream may ignore a Position set before it is ready and then play from 0 --
   desynced from the transport, e.g. when a StandardForm<->TraditionalForm switch spawns a fresh
   stream.  Seek, play, then RE-seek once it is running so it always lands on the transport. *)
registerStream[id_, stream_, n_] := ($Streams[id] = {stream, n}; If[$Playing, seekStream[{stream, n}]; Quiet @ AudioPlay[stream]; seekStream[{stream, n}]])
unregisterStream[id_] := ($Streams = KeyDrop[$Streams, id]; If[$SoloMaster === id, soloRestore[]];)
(* user-facing global transport (exported): act on every registered stream at once.
   TrackPlay[]/TrackPause[] run/halt the shared clock; TrackSeek[cyclePos] jumps the whole
   transport to a cycle position (seeking every stream there); TrackReset[] == TrackSeek[0]. *)
TrackPlay[]  := (If[$ClockStart === None, $ClockStart = AbsoluteTime[]]; $Playing = True; Scan[Function[sn, seekStream[sn]; Quiet @ AudioPlay[First @ sn]], Values @ $Streams])
TrackPause[] := (If[$ClockStart =!= None, $ClockAccum += AbsoluteTime[] - $ClockStart; $ClockStart = None]; $Playing = False; Scan[Function[sn, Quiet @ AudioPause[First @ sn]], Values @ $Streams])
TrackSeek[pos_] := ($ClockAccum = pos / $CyclesPerSecond; $ClockStart = If[$Playing, AbsoluteTime[], None]; Scan[Function[sn, seekStream[sn]; If[$Playing, Quiet @ AudioPlay[First @ sn]]], Values @ $Streams])
TrackReset[] := TrackSeek[0]

(* a track is "enabled" iff it is in the registry; right-click toggles that.  Solo is a TOGGLE:
   the first double-click freezes every OTHER currently-active track (saving their registry entries
   in $SoloSaved) and plays only this one.  Double-clicking the SAME track again restores exactly
   those it froze -- tracks already frozen beforehand are untouched, since they were never in
   $Streams to be saved.  Switching the solo to another track first un-solos the previous one.
   All of it propagates across players through the shared $Streams. *)
enabledQ[id_] := KeyExistsQ[$Streams, id]
soloRestore[] := (
    Scan[Function[k, $Streams[k] = $SoloSaved[k];
        If[$Playing, seekStream[$SoloSaved[k]]; Quiet @ AudioPlay[First @ $SoloSaved[k]]]], Keys @ $SoloSaved];
    $SoloSaved = <||>; $SoloMaster = None)
soloStream[id_, stream_, n_] := If[$SoloMaster === id,
    soloRestore[],   (* 2nd double-click on the soloing track -> un-solo, thaw only its victims *)
    (If[$SoloMaster =!= None, soloRestore[]];     (* switching solo -> undo the previous one first *)
     $Streams[id] = {stream, n};
     With[{victims = DeleteCases[Keys @ $Streams, id]},
        $SoloSaved = KeyTake[$Streams, victims];
        Scan[Function[k, Quiet @ AudioStop[First @ $Streams[k]]], victims]];
     $Streams = <|id -> {stream, n}|>; $SoloMaster = id;
     If[$ClockStart === None, $ClockStart = AbsoluteTime[]]; $Playing = True;
     seekStream[{stream, n}]; Quiet @ AudioPlay[stream])]
(* disabled tracks are wrapped in a thick red frame so they read as muted at a glance *)
frameIfDisabled[id_, viz_] := If[enabledQ[id], viz,
    Framed[viz, FrameStyle -> Directive[RGBColor[1, 0.25, 0.25], AbsoluteThickness[3]], FrameMargins -> 5, RoundingRadius -> 7, Background -> None]]

patternTempo[] := 240 $CyclesPerSecond


(* ::Subsection:: Events and timespans *)

(* An event is <|"Value" -> v, "Whole" -> {wb, we} | None, "Part" -> {pb, pe}|>.
   "Whole" is the event's full extent (None for a continuous signal sample);
   "Part" is the slice intersecting the query.  It "has onset" iff its part begins
   where its whole begins -- i.e. the note actually starts inside the query. *)

sam[t_] := Floor[t]
nextSam[t_] := Floor[t] + 1

hasOnset[ev_] := ev["Whole"] =!= None && ev["Part"][[1]] == ev["Whole"][[1]]

eventDuration[ev_] := ev["Whole"][[2]] - ev["Whole"][[1]]

(* break a query span into pieces that never cross an integer cycle boundary *)
spanCycles[{b_, e_}] /; b >= e := {}
spanCycles[{b_, e_}] /; e <= nextSam[b] := {{b, e}}
spanCycles[{b_, e_}] := Prepend[spanCycles[{nextSam[b], e}], {b, nextSam[b]}]

(* map a function over every time coordinate of an event *)
(* keeps any extra event keys (e.g. "Source" used by LiveCode) and rewrites Whole/Part *)
mapEventTime[f_][ev_] := <|ev,
    "Whole" -> If[ev["Whole"] === None, None, f /@ ev["Whole"]],
    "Part" -> f /@ ev["Part"]
|>


(* ::Subsection:: Constructors *)

(* the canonical form is Track[queryFunction]; these are its query methods *)
Track[q : (_Function | _Symbol), ___]["Query", b_, e_] := q[{b, e}]
Track[q : (_Function | _Symbol), ___]["Cycle", c_ : 0] := q[{c, c + 1}]
Track[q : (_Function | _Symbol), ___]["Onsets", b_ : 0, e_ : 1] := Select[q[{b, e}], hasOnset]

(* a string-parsed pattern carries its source + AST as an optional 2nd arg (an Association);
   derived patterns (from combinators) are single-arg and have no source. *)
Track[_, meta_Association]["Source"] := Lookup[meta, "Source", None]
Track[_, meta_Association]["AST"] := Lookup[meta, "AST", None]
Track[_]["Source"] := None
Track[_]["AST"] := None

(* Steady[v] -- TidalCycles "pure": one event per cycle carrying value v *)
Steady[v_] := Track[Function[span,
    Function[piece, <|"Value" -> v, "Whole" -> {sam[piece[[1]]], nextSam[piece[[1]]]}, "Part" -> piece|>] /@ spanCycles[span]
]]

Silence = Track[Function[span, {}]]

(* mini-notation string -> pattern *)
Track[s_String] := parseSequence[StringTrim[s]]


(* ::Subsection:: The combinator algebra (query rewriters) *)

(* BIJECTION: every pattern keeps a source.  A combinator applied to a SOURCE-BEARING pattern
   appends a postfix " // <op>" to its source string, so Fast[2]/Reverse/... round-trip to
   editable text (parsed back by the // chain handler in MiniNotation.wl).  Source-LESS in ->
   source-less out, so the grammar's own internal use of Fast/Euclidean/... while building a
   pattern attaches nothing. *)
patSource[Track[_, m_Association]] := Lookup[m, "Source", None]
patSource[_] := None
chainNum[r_] := Which[IntegerQ[r], ToString[r], Head[r] === Rational, ToString[r, InputForm], True, ToString[N[r]]]
chainFnName[Reverse] := "rev"
chainFnName[Degrade] := "degrade"
chainFnName[f_] := ToString[f, InputForm]
chain[p_, frag_, derived_] := With[{s = patSource[p]},
    If[s === None, derived, Track[First[derived], <|"Source" -> s <> " // " <> frag|>]]]

(* Fast[r] compresses time by r; Slow[r] stretches it. Operator forms: Fast[2] @ p. *)
Fast[r_][p : Track[q : (_Function | _Symbol), ___]] := chain[p, "fast " <> chainNum[r],
    Track[Function[span, mapEventTime[#/r &] /@ q[r # & /@ span]]]]
Fast[_][Silence] := Silence
Slow[r_][p_Track] := chain[p, "slow " <> chainNum[r], Fast[1/r][p]]

(* Reverse a pattern within each cycle (overloads System`Reverse on the new type) *)
Track /: Reverse[p : Track[q : (_Function | _Symbol), ___]] := chain[p, "rev",
    Track[Function[span, Join @@ (reverseCycle[q, #] & /@ spanCycles[span])]]]
reverseCycle[q_, {b_, e_}] := With[{c = sam[b]},
    With[{reflect = Function[{x, y}, {2 c + 1 - y, 2 c + 1 - x}]},
        Function[ev, <|ev,
            "Whole" -> If[ev["Whole"] === None, None, reflect @@ ev["Whole"]],
            "Part" -> reflect @@ ev["Part"]
        |>] /@ q[reflect @@ {b, e}]
    ]
]

(* Layer -- play patterns simultaneously (TidalCycles "stack"): union of events *)
Layer[ps__Track] := Track[Function[span,
    Join @@ (Function[p, p["Query", span[[1]], span[[2]]]] /@ {ps})
]]
Layer[ps_List] := Layer @@ ps
Layer[p_Track] := p

(* Alternate -- one sub-pattern per cycle (TidalCycles "slowcat" / mini-notation <...>) *)
Alternate[p_Track] := p
Alternate[ps__Track] := With[{pats = {ps}, n = Length[{ps}]},
    Track[Function[span, Join @@ (alternateCycle[pats, n, #] & /@ spanCycles[span])]]
]
alternateCycle[pats_, n_, {b_, e_}] := With[{c = sam[b]},
    With[{off = c - Floor[c/n]},
        mapEventTime[# + off &] /@ pats[[Mod[c, n] + 1]]["Query", b - off, e - off]
    ]
]

(* within-cycle sequence (mini-notation spaces): fast[n] of slowcat *)
fastcatList[{p_}] := p
fastcatList[ps_List] := Fast[Length[ps]][Alternate @@ ps]

(* Every[n, f] applies transform f only on cycles where Mod[cycle, n] == 0 *)
Every[n_, f_][p : Track[q : (_Function | _Symbol), ___]] := chain[p, "every " <> ToString[n] <> " " <> chainFnName[f],
    Track[Function[span,
        Join @@ (Function[piece,
            If[Mod[sam[piece[[1]]], n] == 0,
                f[Track[q]]["Query", piece[[1]], piece[[2]]],
                q[piece]
            ]] /@ spanCycles[span])]]]

(* Euclidean[k, n] -- Bjorklund rhythm: k onsets spread maximally evenly over n steps *)
Euclidean[k_, n_][p_Track] := chain[p, "euclid " <> ToString[k] <> " " <> ToString[n], Euclidean[k, n, 0][p]]
Euclidean[k_, n_, rot_][p_] := fastcatList[If[#, p, Silence] & /@ RotateLeft[bjorklund[k, n], rot]]

bjorklund[k_, n_] := Which[
    k <= 0, ConstantArray[False, n],
    k >= n, ConstantArray[True, n],
    True, bjork[ConstantArray[{True}, k], ConstantArray[{False}, n - k]]
]
bjork[a_, b_] := If[Length[b] <= 1,
    Flatten[Join[a, b]],
    With[{m = Min[Length[a], Length[b]]},
        bjork[
            Table[Join[a[[i]], b[[i]]], {i, m}],
            If[Length[a] > m, a[[m + 1 ;;]], b[[m + 1 ;;]]]
        ]
    ]
]

(* Degrade -- drop ~fraction of onsets deterministically per cycle.
   The unary form is restricted to a pattern argument so the operator form
   Degrade[0.5] does NOT match it (which would recurse Degrade[0.5][0.5]...). *)
Degrade[p_Track] := Degrade[0.5][p]
Degrade[fraction_][p : Track[q : (_Function | _Symbol), ___]] := chain[p, If[TrueQ[fraction == 0.5], "degrade", "degrade " <> chainNum[fraction]],
    Track[Function[span, Select[q[span], stableHash[#] >= fraction &]]]]
stableHash[ev_] := Mod[Hash[{ev["Whole"], ev["Value"]}], 1000]/1000.

(* time shift, and layering combinators *)
Late[t_][p : Track[q : (_Function | _Symbol), ___]] := chain[p, "late " <> chainNum[t],
    Track[Function[span, mapEventTime[# + t &] /@ q[# - t & /@ span]]]]
Early[t_][p_Track] := chain[p, "early " <> chainNum[t], Late[-t][p]]
Superimpose[f_][p_] := Layer[p, f[p]]
Stagger[t_, f_][p_] := Layer[p, Late[t][f[p]]]


(* ::Subsection:: Mini-notation parser *)

(* split a string on any separator char, respecting [], <>, () nesting *)
splitTop[s_String, seps_List] := Module[{depth = 0, cur = "", out = {}, ch},
    Do[
        ch = StringTake[s, {i}];
        Which[
            MemberQ[{"[", "<", "("}, ch], depth++; cur = cur <> ch,
            MemberQ[{"]", ">", ")"}, ch], depth--; cur = cur <> ch,
            depth == 0 && MemberQ[seps, ch], (If[StringTrim[cur] =!= "", AppendTo[out, StringTrim[cur]]]; cur = ""),
            True, cur = cur <> ch
        ],
        {i, StringLength[s]}
    ];
    If[StringTrim[cur] =!= "", AppendTo[out, StringTrim[cur]]];
    out
]

(* "a b c" -> fastcat; the top-level sequence *)
parseSequence[s_String] := With[{steps = splitTop[s, {" "}]},
    Switch[Length[steps], 0, Silence, 1, parseStep[steps[[1]]], _, fastcatList[parseStep /@ steps]]
]

(* "a, b" inside [] -> Layer; otherwise a plain sequence *)
parseStack[s_String] := With[{parts = splitTop[s, {","}]},
    If[Length[parts] <= 1, parseSequence[s], Layer @@ (parseSequence /@ parts)]
]

(* one step: an element followed by modifiers like  *n  /n  (k,n[,r]) *)
parseStep[tok_String] := With[{ev = parseElement[tok]}, applyModifiers[ev[[1]], ev[[2]]]]

(* returns {pattern, leftoverModifierString} *)
parseElement[tok_String] := Which[
    StringStartsQ[tok, "["], With[{close = matchBracket[tok, "[", "]"]},
        {parseStack[StringTake[tok, {2, close - 1}]], StringDrop[tok, close]}],
    StringStartsQ[tok, "<"], With[{close = matchBracket[tok, "<", ">"]},
        {Alternate @@ (parseStep /@ splitTop[StringTake[tok, {2, close - 1}], {" "}]), StringDrop[tok, close]}],
    True, With[{m = StringPosition[tok, "*" | "/" | "(", 1]},
        If[m === {},
            {atomPattern[tok], ""},
            {atomPattern[StringTake[tok, m[[1, 1]] - 1]], StringDrop[tok, m[[1, 1]] - 1]}
        ]
    ]
]

(* index of the bracket matching the opener at position 1 *)
matchBracket[s_String, open_, close_] := Module[{depth = 0, ch},
    Do[
        ch = StringTake[s, {i}];
        If[ch === open, depth++]; If[ch === close, depth--];
        If[depth == 0, Return[i]],
        {i, StringLength[s]}
    ]
]

applyModifiers[p_, ""] := p
applyModifiers[p_, mods_String] := Which[
    StringStartsQ[mods, "*"], With[{r = readNumber[StringDrop[mods, 1]]},
        applyModifiers[Fast[r[[1]]][p], r[[2]]]],
    StringStartsQ[mods, "/"], With[{r = readNumber[StringDrop[mods, 1]]},
        applyModifiers[Slow[r[[1]]][p], r[[2]]]],
    StringStartsQ[mods, "("], With[{close = matchBracket[mods, "(", ")"]},
        With[{args = ToExpression["{" <> StringTake[mods, {2, close - 1}] <> "}"]},
            applyModifiers[(Euclidean @@ args)[p], StringDrop[mods, close]]
        ]],
    True, p
]

(* read a leading number, return {number, rest} *)
readNumber[s_String] := With[{m = StringCases[s, StartOfString ~~ d : (DigitCharacter | ".").. :> d, 1]},
    If[m === {}, {1, s}, {ToExpression[m[[1]]], StringDrop[s, StringLength[m[[1]]]]}]
]

atomPattern["~"] := Silence
atomPattern[a_String] := Steady[If[StringMatchQ[a, (DigitCharacter | "-")..], ToExpression[a], a]]


(* ::Subsection:: Sample bank -- load drum / one-shot WAVs, addressed by name *)

$SampleBank = <||>

LoadSample[name_String, file_String] := ($SampleBank[name] = AudioNormalize @ AudioChannelMix[Import[file], "Mono"])
LoadSamples[dir_String] := (LoadSample[FileBaseName[#], #] & /@ FileNames["*.wav", dir]; Keys[$SampleBank])
sampleQ[v_] := KeyExistsQ[$SampleBank, v]


(* ::Subsection:: Notation: pitched events -> MusicScore (drives Sound / MusicPlot) *)

(* a value's pitch.  A token can be a pitch-name string ("c4"), a raw MIDI integer, a WL 15
   Music* object (MusicNote/MusicPitch/MusicChord), or an old SoundNote -- all first-class. *)
valueMidi[v_Integer] := v
valueMidi[v_String] := Quiet @ Check[MusicPitch[v]["MIDINumber"], Missing[]]
valueMidi[mp_MusicPitch] := Quiet @ Check[mp["MIDINumber"], Missing[]]
valueMidi[mn_MusicNote] := Quiet @ Check[mn["Pitch"]["MIDINumber"], Missing[]]
valueMidi[SoundNote[p_Integer, ___]] := 60 + p
valueMidi[SoundNote[p_String, ___]] := valueMidi[p]
valueMidi[_] := Missing[]
(* every sounding MIDI pitch of a value: one for a note, several for a chord, none for a drum *)
valuePitches[mc_MusicChord] := Quiet @ Check[#["MIDINumber"] & /@ mc["PitchList"], {}]
valuePitches[SoundNote[ps_List, ___]] := Flatten[valuePitches /@ ps]
valuePitches[v_] := With[{m = valueMidi[v]}, If[NumericQ[m], {Round[m]}, {}]]
(* a rest "~" is a SILENT event: it occupies its step and highlights in the source, but the audio
   and the piano roll skip it (so it neither sounds nor draws a block). *)
restQ[v_] := v === "~"
(* short label for the roll: strings as-is, otherwise the pitch name(s) *)
midiName[m_] := Quiet @ Check[ToString[MusicPitch[Round @ m]["Key"]] <> ToString[MusicPitch[Round @ m]["Octave"]], ToString[Round @ m]]
labelOf[v_String] := v
labelOf[v_] := With[{ps = valuePitches[v]}, If[ps === {}, ToString[v, InputForm], StringRiffle[midiName /@ ps, "+"]]]

(* a voice is a bare pattern or a Synth / Gain wrapper; patternOf recovers the pattern *)
patternOf[SynthVoice[_, p_]] := p
patternOf[GainVoice[_, v_]] := patternOf[v]
patternOf[p_] := p

(* events (one cycle-range) -> a monophonic MusicVoice: simultaneous onsets become chords;
   gaps and non-pitch (sample) tokens become rests.  Durations are whole-note units. *)
eventsToVoice[events_, nCycles_] := Module[{byOnset, items = {}, t = 0, dur, grp, pitches},
    If[events === {}, Return[MusicVoice[{MusicRest[nCycles]}]]];
    byOnset = KeySort @ GroupBy[events, #["Whole"][[1]] &];
    KeyValueMap[(
        grp = #2; dur = Min[eventDuration /@ grp];
        If[#1 > t, AppendTo[items, MusicRest[#1 - t]]];
        pitches = DeleteMissing[valueMidi[#["Value"]] & /@ grp];
        AppendTo[items, Which[pitches === {}, MusicRest[dur], Length[pitches] == 1, MusicNote[pitches[[1]], dur], True, MusicChord[pitches, dur]]];
        t = Max[t, #1] + dur
    ) &, byOnset];
    If[t < nCycles, AppendTo[items, MusicRest[nCycles - t]]];
    MusicVoice[items]
]
patternVoice[v_, nCycles_ : 1] := eventsToVoice[Select[patternOf[v]["Query", 0, nCycles], hasOnset], nCycles]

patternScore[voices_List, nCycles_] := MusicScore[patternVoice[#, nCycles] & /@ voices, MusicTimeSignature[4, 4], MusicTempo -> patternTempo[]]
patternScore[v : _Track | _SynthVoice | _GainVoice, nCycles_] := patternScore[{v}, nCycles]
patternScore[Track[voices_List, ___], nCycles_] := patternScore[voices, nCycles]


(* ::Subsection:: Audio renderer: drum samples + oscillator synth + MusicScore, overlaid *)

(* a voice carrying a wave gets oscillator synthesis; Gain scales its level *)
Synth[wave_String][p_] := SynthVoice[wave, p]
(* Gain on a Track stays a Track (so it still displays + chains visuals) and carries its gain as
   metadata; on any other voice it wraps in GainVoice.  Bijection: appends " // gain g" to source. *)
Gain[g_][p : Track[q : (_Function | _Symbol), ___]] := With[{gained = setMeta[p, "Gain", g gainMeta[p]], s = patSource[p]},
    If[s === None, gained, setMeta[gained, "Source", s <> " // gain " <> chainNum[g]]]]
Gain[g_][v_] := GainVoice[g, v]

(* Beat[positions, steps] (Strudel .beat): place a value pattern's value at specific step positions
   each cycle -- positions a comma-list string "0,7.3,10.2" or a list, steps = steps per cycle.
   Struct["1 0 1 1"] (Strudel .struct) is the boolean-mask form: value on each "1"/"t" step. *)
beatPositions[s_String] := ToExpression /@ StringSplit[s, ","]
beatPositions[l_List] := l
sampleValue[p_, t_] := With[{evs = Select[patternOf[p]["Query", Floor[t], Floor[t] + 1],
    #["Whole"] =!= None && #["Whole"][[1]] <= t < #["Whole"][[2]] &]},
    If[evs === {}, Missing[], First[evs]["Value"]]]
beatCycle[ps_, steps_, p_, {b_, e_}] := With[{c = Floor[b]},
    With[{ons = (c + #/steps) & /@ ps},
        With[{nxt = Append[Rest[ons], c + 1]},
            DeleteCases[MapThread[Function[{on, nx}, With[{val = sampleValue[p, on]},
                If[on < e && nx > b && val =!= Missing[],
                    <|"Value" -> val, "Whole" -> {on, nx}, "Part" -> {Max[on, b], Min[nx, e]}|>, Nothing]]],
                {ons, nxt}], Nothing]]]]
Beat[pos_, steps_][p_] := With[{ps = Sort[N @ beatPositions[pos]]},
    Track[Function[span, Join @@ (beatCycle[ps, steps, p, #] & /@ spanCycles[span])]]]
Struct[structStr_String][p_] := With[{toks = StringSplit[structStr]},
    Beat[Flatten[Position[toks, "1" | "t" | "true"]] - 1, Length[toks]][p]]

cycleSeconds[] := 1 / $CyclesPerSecond
midiToFreq[m_] := 440. * 2 ^ ((m - 69) / 12.)
silence[sec_] := AudioGenerator["Silence", Max[sec, 0.001]]
at[onsetCycles_] := onsetCycles cycleSeconds[]

fitDuration[a_, sec_] := With[{d = QuantityMagnitude @ Duration[a]},
    Which[d < sec - 0.0005, AudioPad[a, {0, sec - d}], d > sec + 0.0005, AudioTrim[a, Quantity[{0, sec}, "Seconds"]], True, a]]

mix[layers_] := With[{ls = DeleteCases[Flatten[{layers}], Nothing]},
    Switch[Length[ls], 0, Nothing, 1, ls[[1]], _, AudioOverlay[ls]]]
fitTo[Nothing, nCycles_] := silence[nCycles cycleSeconds[]]
fitTo[a_, nCycles_] := fitDuration[a, nCycles cycleSeconds[]]

(* per-note amplitude envelope (anti-click attack + release scaled to the note) *)
env[a_, durSec_] := AudioFade[a, {0.004, Min[0.09, 0.5 durSec]}]
oscNote[wave_, f_, durSec_] := env[Switch[wave,
    "Supersaw", AudioOverlay[AudioGenerator[{"Sawtooth", f #}, durSec] & /@ {0.993, 1., 1.007}],
    _, AudioGenerator[{wave, f}, durSec]], durSec]

(* synthesized drum fallback so percussion tokens are audible with NO samples loaded -- the
   default before LoadSamples replaces them with real WAVs.  Memoized per token. *)
perc[a_, rel_] := AudioFade[a, {0.002, rel}]
hpf[a_, f_] := HighpassFilter[a, f]
synthDrum[v_] := synthDrum[v] = AudioNormalize @ Switch[ToLowerCase[v],
    "bd" | "kick" | "bass" | "b", perc[AudioGenerator[{"Sine", 55}, 0.22], 0.2],
    "sn" | "sd" | "snare", perc[AudioOverlay[{AudioGenerator["Pink", 0.16], AudioGenerator[{"Sine", 185}, 0.16]}], 0.14],
    "hh" | "ch" | "hat" | "h", perc[hpf[AudioGenerator["White", 0.05], 7000], 0.045],
    "oh" | "open", perc[hpf[AudioGenerator["White", 0.2], 6000], 0.18],
    "cp" | "clap" | "hc", perc[AudioGenerator["White", 0.09], 0.08],
    "cr" | "crash" | "ride" | "rd", perc[hpf[AudioGenerator["White", 0.5], 5000], 0.45],
    "rim" | "rs" | "cl", perc[AudioGenerator[{"Sine", 330}, 0.04], 0.035],
    "tom" | "lt" | "mt" | "ht" | "t", perc[AudioGenerator[{"Sine", 120}, 0.18], 0.16],
    _, perc[AudioGenerator["White", 0.05], 0.045]]
drumSound[v_] := If[sampleQ[v], $SampleBank[v], synthDrum[v]]
(* drum/percussion events (a loaded sample, or any non-pitch token) placed at their onsets *)
sampleLayer[events_] := mix[AudioPad[drumSound[#["Value"]], {at[#["Whole"][[1]]], 0}] & /@
    Select[events, ! restQ[#["Value"]] && (sampleQ[#["Value"]] || valuePitches[#["Value"]] === {}) &]]
(* pitched events -> MusicScore -> Audio (acoustic-ish) *)
musicLayer[events_, nCycles_] := With[{pe = Select[events, ! sampleQ[#["Value"]] && NumericQ[valueMidi[#["Value"]]] &]},
    If[pe === {}, Nothing, Audio[MusicScore[{eventsToVoice[pe, nCycles]}, MusicTimeSignature[4, 4], MusicTempo -> patternTempo[]]]]]
(* pitched events -> oscillator synth -> Audio *)
oscLayer[events_, wave_] := mix[Flatten[Function[ev,
    Function[m, AudioPad[oscNote[wave, midiToFreq[m], eventDuration[ev] cycleSeconds[]], {at[ev["Whole"][[1]]], 0}]] /@ valuePitches[ev["Value"]]
] /@ Select[events, valuePitches[#["Value"]] =!= {} && ! sampleQ[#["Value"]] &]]]

voiceAudio[GainVoice[g_, v_], nCycles_] := voiceAudio[v, nCycles]  (* gain applied post-normalize via gainMeta *)
voiceAudio[SynthVoice[wave_, p_], nCycles_] := fitTo[oscLayer[Select[p["Query", 0, nCycles], hasOnset], wave], nCycles]
(* default pitched rendering uses self-contained OSCILLATORS, not MusicScore/FluidSynth: the
   external soundfont backend is slow to re-render on every live edit and was the likely source
   of the kernel-reconnect ("MathLink") dialog + instability.  Set $DefaultWave to retimbre, or
   wrap a voice in Synth["..."] for an explicit oscillator.  (MusicScore is still used by
   ["Score"]/MusicPlot/Sound.) *)
voiceAudio[p_Track, nCycles_] := With[{ev = Select[p["Query", 0, nCycles], hasOnset]},
    fitTo[mix[{sampleLayer[ev], oscLayer[ev, $DefaultWave]}], nCycles]]

(* sum the voices at their natural per-voice level -- NO peak-normalize, so a Track[a,b,c]
   sounds exactly like playing a, b, c in separate players (which the speakers also just sum).
   nCycles comes from cyclesOf via the player, so // Bars[n] widens the window. *)
(* auto-normalize PER VOICE (peak), never on the summed mix: an individual track plays at a healthy
   level, and a combined Track is the SUM of those same normalized voices -- so a voice sounds the
   same solo or in the mix (the mix is just louder, like separate players summed by the speakers).
   A silent voice passes through untouched (no divide-by-zero boost). *)
normAudio[a_] := With[{pk = Quiet @ Check[QuantityMagnitude @ AudioMeasurements[a, "Max"], 0.]},
    If[NumericQ[pk] && pk > 0.0001, AudioNormalize[a], a]]
(* a voice's Gain (from // Gain[g]) is applied AFTER the peak-normalize -- a gain inside voiceAudio
   would just be undone by normAudio, which is why Gain used to be inaudible. *)
gainMeta[Track[_, m_Association]] := Lookup[m, "Gain", 1]
gainMeta[GainVoice[g_, v_]] := g gainMeta[v]
gainMeta[_] := 1
voiceRendered[v_, nCycles_] := AudioAmplify[normAudio @ voiceAudio[v, nCycles], gainMeta[v]]
renderAudio[t : Track[voices_List, ___], nCycles_] := AudioAmplify[fitDuration[mix[voiceRendered[#, nCycles] & /@ voices], nCycles cycleSeconds[]], gainMeta[t]]
renderAudio[v_, nCycles_] := fitTo[voiceRendered[v, nCycles], nCycles]

Track /: Audio[p_Track, nCycles_ : 1] := renderAudio[p, nCycles]
Track /: MusicPlot[p_Track, nCycles_ : 1, opts___] := MusicPlot[patternScore[p, nCycles], opts]
Track /: Sound[p_Track, nCycles_ : 1] := Sound[patternScore[p, nCycles]]
SynthVoice /: Audio[v_SynthVoice, nCycles_ : 1] := renderAudio[v, nCycles]
GainVoice /: Audio[v_GainVoice, nCycles_ : 1] := renderAudio[v, nCycles]


(* ::Subsection:: Track: a multi-voice composition (each line its own timbre/voice) *)

voiceQ[v_] := MatchQ[v, _Track | _SynthVoice | _GainVoice]
voiceLikeQ[v_] := StringQ[v] || voiceQ[v]
asVoice[s_String] := Track[s]
asVoice[v_] := v
Track[ps__?voiceQ] := Track[{ps}]
(* mini-notation strings compose as voices too: Track["bass", "chords", "arp"] -- >=2 args, at
   least one a String (a lone Track[s_String] stays the single mini-notation parse). *)
Track[a_?voiceLikeQ, b__?voiceLikeQ] /; ! AllTrue[{a, b}, voiceQ] := Track[asVoice /@ {a, b}]
Track[t_Track] := t

Track[voices_List, ___]["Voices"] := voices
Track[voices_List, ___]["Score", nCycles_ : 1] := patternScore[voices, nCycles]

Track /: Audio[Track[voices_List, ___], nCycles_ : 1] := renderAudio[Track[voices], nCycles]
Track /: MusicPlot[Track[voices_List, ___], nCycles_ : 1, opts___] := MusicPlot[patternScore[voices, nCycles], opts]
Track /: Sound[Track[voices_List, ___], nCycles_ : 1] := Sound[patternScore[voices, nCycles]]


(* ::Subsection:: Vision renderer: piano roll (static) and an audio-synced animation *)

(* pitched tokens take their MIDI row; sample / non-pitch tokens (bd, hh, ...) get a stable
   low percussion row so a drum pattern still draws instead of an empty (black) roll. *)
laneValue[val_] := With[{ps = valuePitches[val]}, If[ps =!= {}, First[ps], 36 + Mod[Hash[val], 8]]]
(* one block per sounding pitch (a chord draws a block per note); drums get a synthetic row *)
rollData[v_, nCycles_] := With[{evs = Select[patternOf[v]["Query", 0, nCycles], hasOnset[#] && ! restQ[#["Value"]] &]},
    Flatten[Function[ev, With[{ps = valuePitches[ev["Value"]]},
        If[ps === {},
            {{ev["Whole"], 36 + Mod[Hash[ev["Value"]], 8], labelOf[ev["Value"]]}},
            {ev["Whole"], #, If[StringQ[ev["Value"]], ev["Value"], midiName[#]]} & /@ ps]]] /@ evs, 1]
]

(* all colors are LightDarkSwitched[light, dark] so the roll adapts to the FE appearance;
   every default is overridable via the options below (FontSize, Background, BlockColor,
   LabelColor, PlayheadColor, GridColor, FrameStyle, AspectRatio, ImageSize), and any extra
   Graphics options pass through. *)
Options[pianoRoll] = {
    FontSize -> 9, Background -> Automatic, "BlockColor" -> Automatic, "LabelColor" -> Automatic,
    "PlayheadColor" -> Automatic, "GridColor" -> Automatic, FrameStyle -> Automatic,
    AspectRatio -> 1/3, ImageSize -> 480
};
blockColor[Automatic, hue_] := LightDarkSwitched[Hue[hue, 0.7, 0.7], Hue[hue, 0.55, 0.95]]
blockColor[c_, _] := c
pianoRoll[patsOrTrack_, nCycles_ : 1, highlight_ : None, opts : OptionsPattern[]] := Module[
    {lanes, data, mids, lo, hi, bg, blk, labelCol, playCol, gridCol, frameCol, fs, lab},
    lanes = Which[MatchQ[patsOrTrack, Track[_List, ___]], patsOrTrack["Voices"], MatchQ[patsOrTrack, _List], patsOrTrack, True, {patsOrTrack}];
    data = MapIndexed[Function[{lane, i}, {First[i], #} & /@ rollData[lane, nCycles]], lanes];
    mids = Cases[Flatten[data, 1][[All, 2, 2]], _Integer];
    If[mids === {}, Return[Graphics[{}, ImageSize -> OptionValue[ImageSize]]]];
    lo = Min[mids] - 2; hi = Max[mids] + 2;
    fs = OptionValue[FontSize];   blk = OptionValue["BlockColor"];
    bg       = OptionValue[Background]      /. Automatic -> LightDarkSwitched[GrayLevel[0.96], GrayLevel[0.13]];
    labelCol = OptionValue["LabelColor"]    /. Automatic -> LightDarkSwitched[GrayLevel[0.1], GrayLevel[0.95]];
    playCol  = OptionValue["PlayheadColor"] /. Automatic -> LightDarkSwitched[RGBColor[0.15, 0.15, 0.2, 0.85], GrayLevel[1, 0.85]];
    gridCol  = OptionValue["GridColor"]     /. Automatic -> LightDarkSwitched[GrayLevel[0.8], GrayLevel[0.28]];
    frameCol = OptionValue[FrameStyle]      /. Automatic -> LightDarkSwitched[GrayLevel[0.6], GrayLevel[0.4]];
    (* label rides a background-coloured pill so it stays legible whether the block is wide
       (label inside) or narrow (label overflows onto the roll background). *)
    lab[token_, ctr_] := Text[Style[token, fs, FontFamily -> "Source Code Pro", FontWeight -> Bold, FontColor -> labelCol, Background -> bg], ctr];
    Graphics[{
        EdgeForm[LightDarkSwitched[GrayLevel[0.75], GrayLevel[0.1]]],
        MapThread[Function[{laneData, hue},
            Function[{li, wrt}, {
                blockColor[blk, hue], Rectangle[{wrt[[1, 1]], wrt[[2]] - 0.42}, {wrt[[1, 2]], wrt[[2]] + 0.42}],
                lab[wrt[[3]], {Mean[wrt[[1]]], wrt[[2]]}]
            }] @@@ laneData
        ], {data, If[Length[lanes] == 1, {0.58}, Range[0, Length[lanes] - 1]/Length[lanes]]}],
        If[highlight === None, {}, {playCol, Thickness[0.006], Line[{{Mod[highlight, nCycles], lo}, {Mod[highlight, nCycles], hi}}]}]
    },
        PlotRange -> {{0, nCycles}, {lo, hi}}, AspectRatio -> OptionValue[AspectRatio], Background -> bg,
        GridLines -> {Range[0, nCycles], None}, GridLinesStyle -> gridCol,
        Frame -> True, FrameStyle -> frameCol, FrameTicks -> {{None, None}, {Range[0, nCycles], None}},
        ImageSize -> OptionValue[ImageSize], FilterRules[{opts}, Options[Graphics]]
    ]
]

Track[q : (_Function | _Symbol), ___]["PianoRoll", nCycles_ : 1, opts : OptionsPattern[pianoRoll]] := pianoRoll[Track[q], nCycles, None, opts]
Track[voices_List, ___]["PianoRoll", nCycles_ : 1, opts : OptionsPattern[pianoRoll]] := pianoRoll[Track[voices], nCycles, None, opts]

(* Punchcard: a SCROLLING view (unlike the piano roll's moving playhead over fixed blocks).  Each
   event is a full-band-height rectangle; the strip scrolls RIGHT -> LEFT past a FIXED "now" line,
   so a bar sounds as its left edge crosses the line.  One horizontal band per voice; bar colour is
   per-token, opacity rides the voice's gain (// Gain[g] dims the bars).  `phase` is the CONTINUOUS
   (unwrapped) clock position so the scroll never jumps at the cycle boundary. *)
valueHue[v_] := Mod[Hash[v], 997]/997.   (* integer mod FIRST -- Hash is ~10^18, so scaling it as a float loses all fractional precision *)
punchColor[Automatic, v_] := LightDarkSwitched[Hue[valueHue[v], 0.55, 0.78], Hue[valueHue[v], 0.5, 0.95]]
punchColor[c_, _] := c
Options[punchcard] = {FontSize -> 9, Background -> Automatic, "BlockColor" -> Automatic, "LabelColor" -> Automatic,
    "PlayheadColor" -> Automatic, "GridColor" -> Automatic, FrameStyle -> Automatic, AspectRatio -> 1/4,
    ImageSize -> 480, "Window" -> Automatic};
punchcard[patsOrTrack_, nCycles_ : 1, phase_ : None, opts : OptionsPattern[]] := Module[
    {ph, w, x0, lanes, nl, bg, blk, labCol, lineCol, gridCol, frameCol, fs, bar},
    ph = If[phase === None, 0., N @ phase];
    w = OptionValue["Window"] /. Automatic -> nCycles;
    x0 = 0.5 w;   (* the fixed now-line down the MIDDLE: past scrolls off left, future enters right *)
    lanes = Which[MatchQ[patsOrTrack, Track[_List, ___]], patsOrTrack["Voices"], MatchQ[patsOrTrack, _List], patsOrTrack, True, {patsOrTrack}];
    nl = Length[lanes];
    fs = OptionValue[FontSize];  blk = OptionValue["BlockColor"];
    bg       = OptionValue[Background]      /. Automatic -> LightDarkSwitched[GrayLevel[0.96], GrayLevel[0.12]];
    labCol   = OptionValue["LabelColor"]    /. Automatic -> LightDarkSwitched[GrayLevel[0.1], GrayLevel[0.97]];
    lineCol  = OptionValue["PlayheadColor"] /. Automatic -> LightDarkSwitched[RGBColor[0.85, 0.2, 0.2], RGBColor[1, 0.9, 0.35]];
    gridCol  = OptionValue["GridColor"]     /. Automatic -> LightDarkSwitched[GrayLevel[0.82], GrayLevel[0.25]];
    frameCol = OptionValue[FrameStyle]      /. Automatic -> LightDarkSwitched[GrayLevel[0.6], GrayLevel[0.4]];
    (* screen x = absoluteTime - now + x0, so onsets at `now` land on the line and scroll left *)
    bar[gn_, band_][ev_] := With[{x1 = ev["Whole"][[1]] - ph + x0, x2 = ev["Whole"][[2]] - ph + x0, val = ev["Value"]},
        {Opacity[Clip[0.3 + 0.7 gn, {0.12, 1}]], punchColor[blk, val],
         Rectangle[{x1, band[[1]] + 0.05}, {x2, band[[2]] - 0.05}],
         Text[Style[labelOf[val], fs, FontFamily -> "Source Code Pro", FontWeight -> Bold, FontColor -> labCol], {Mean[{x1, x2}], Mean[band]}]}];
    Graphics[{
        EdgeForm[LightDarkSwitched[GrayLevel[0.7, 0.5], GrayLevel[0.05, 0.5]]],
        MapIndexed[Function[{lane, i}, bar[gainMeta[lane], {nl - First[i], nl - First[i] + 1}] /@
            Select[patternOf[lane]["Query", ph - x0 - 1, ph + w - x0], hasOnset[#] && ! restQ[#["Value"]] && #["Whole"][[2]] > ph - x0 &]], lanes],
        {lineCol, Thickness[0.011], Line[{{x0, 0}, {x0, Max[nl, 1]}}]}
    },
        PlotRange -> {{0, w}, {0, Max[nl, 1]}}, PlotRangeClipping -> True,
        AspectRatio -> OptionValue[AspectRatio], Background -> bg,
        GridLines -> {None, Range[0, nl]}, GridLinesStyle -> gridCol,
        Frame -> True, FrameStyle -> frameCol, FrameTicks -> None,
        ImageSize -> OptionValue[ImageSize], FilterRules[{opts}, Options[Graphics]]
    ]
]
(* pass the WHOLE track (keep its Gain metadata) so dot size/opacity reflects // Gain[g] *)
(t : Track[_Function | _Symbol, ___])["Punchcard", nCycles_ : 1, opts : OptionsPattern[punchcard]] := punchcard[t, nCycles, None, opts]
(t : Track[_List, ___])["Punchcard", nCycles_ : 1, opts : OptionsPattern[punchcard]] := punchcard[t, nCycles, None, opts]

(* live: loop the rendered bar through an AudioStream and scrub the playhead across the
   piano roll from the stream's true position (the master clock).  Returns a Dynamic. *)
patternPlay[patsOrTrack_, nCycles_ : 1] := With[{aud = renderAudio[patsOrTrack, nCycles]},
    DynamicModule[{stream = AudioStream[aud, Looping -> True], playing = True, head = 0.},
        AudioPlay[stream];
        Dynamic[
            Refresh[
                If[playing, head = (QuantityMagnitude[stream["Position"]] - $AudioLatency) $CyclesPerSecond];
                EventHandler[
                    pianoRoll[patsOrTrack, nCycles, head],
                    {
                        (* left-click: play / pause *)
                        {"MouseDown", 1} :> If[playing, (AudioStop[stream]; playing = False), (AudioPlay[stream]; playing = True)],
                        (* right-click: reset to the start, paused *)
                        {"MouseDown", 2} :> (AudioStop[stream]; RemoveAudioStream[stream]; stream = AudioStream[aud, Looping -> True]; head = 0.; playing = False)
                    }
                ],
                TrackedSymbols :> {head, playing}, UpdateInterval -> 0.03
            ]
        ],
        (* stop + free the stream when the cell is re-evaluated or deleted, so re-evals don't
           pile up orphan loops all playing at once *)
        Deinitialization :> Quiet[AudioStop[stream]; RemoveAudioStream[stream]],
        SaveDefinitions -> True
    ]
]
Track[q : (_Function | _Symbol), m___]["Play", nCycles_ : 2] := livePlayer[Track[q, m], nCycles, True]
Track[voices_List, ___]["Play", nCycles_ : 2] := livePlayer[Track[voices], nCycles, True]

(* ["Scope"] plays the loop and shows a live oscilloscope of the audio stream's current
   buffer; same click mechanics as ["Play"] (left = play/pause, right = reset). *)
Options[scopeFrame] = {ImageSize -> 480, AspectRatio -> 1/3, Background -> GrayLevel[0.08],
    "WaveColor" -> RGBColor[0.25, 1, 0.55], FrameStyle -> GrayLevel[0.3], "GridColor" -> GrayLevel[0.25]};
(* waveform as a PACKED [0,1] x amplitude point list, downsampled to <=256 points: few points +
   a FIXED x-range keep both the data and the Graphics shell cheap and static. *)
scopePoints[snippet_] := Module[{w, m},
    w = Quiet @ Check[Flatten @ AudioData[snippet], {}];
    If[! VectorQ[w, NumericQ], w = {}];
    m = Length[w];
    If[m > 256, w = w[[1 ;; m ;; Ceiling[m / 256]]]];
    If[Length[w] < 2, w = {0., 0.}];
    m = Length[w];
    Developer`ToPackedArray @ N @ Transpose[{Subdivide[0., 1., m - 1], w}]]
(* the Graphics SHELL (frame / background / zero line / fixed range) holding `line` as its wave.
   Built ONCE; for the live visual `line` is a Dynamic[Line[..]] so ONLY the waveform primitive
   re-rasterizes each frame -- the FE never re-typesets the frame/axes (the real fps lever, since
   WL has no GPU 2D-render path).  Raw Graphics, never ListLinePlot. *)
scopeShell[line_, o : OptionsPattern[scopeFrame]] := Graphics[{
        OptionValue[scopeFrame, {o}, "GridColor"], AbsoluteThickness[0.6], Line[{{0, 0}, {1, 0}}],
        OptionValue[scopeFrame, {o}, "WaveColor"], AbsoluteThickness[1.2], line},
    PlotRange -> {{0, 1}, {-1.05, 1.05}}, AspectRatio -> OptionValue[scopeFrame, {o}, AspectRatio],
    Background -> OptionValue[scopeFrame, {o}, Background], Frame -> True, FrameTicks -> None,
    FrameStyle -> OptionValue[scopeFrame, {o}, FrameStyle], ImageSize -> OptionValue[scopeFrame, {o}, ImageSize], ImagePadding -> 4]
(* static one-shot scope (used by the ["Scope"] method's own refresh) *)
scopeFrame[snippet_, opts : OptionsPattern[]] := scopeShell[Line @ scopePoints[snippet], opts]
(* the LIVE oscilloscope visual: shell built once, inner Dynamic re-draws only the wave Line *)
scopeWidget[stream_, opts : OptionsPattern[]] := scopeShell[
    Dynamic[Line @ scopePoints @ stream["CurrentAudio"], TrackedSymbols :> {}, UpdateInterval -> 0.03], opts]

scopePlay[patsOrTrack_, nCycles_ : 2] := With[{aud = renderAudio[patsOrTrack, nCycles]},
    DynamicModule[{stream = AudioStream[aud, Looping -> True], playing = True, frame = 0},
        AudioPlay[stream];
        Dynamic[
            Refresh[
                frame++;
                EventHandler[
                    scopeFrame[stream["CurrentAudio"]],
                    {
                        {"MouseDown", 1} :> If[playing, (AudioStop[stream]; playing = False), (AudioPlay[stream]; playing = True)],
                        {"MouseDown", 2} :> (AudioStop[stream]; RemoveAudioStream[stream]; stream = AudioStream[aud, Looping -> True]; playing = False)
                    }
                ],
                TrackedSymbols :> {frame}, UpdateInterval -> 0.04
            ]
        ],
        SaveDefinitions -> True
    ]
]
Track[q : (_Function | _Symbol), ___]["Scope", nCycles_ : 2] := scopePlay[Track[q], nCycles]
Track[voices_List, ___]["Scope", nCycles_ : 2] := scopePlay[Track[voices], nCycles]


(* ::Subsection:: The "Visual" property + the unified live player *)

(* A pattern's Visual is what it shows as its live display: the labeled "PianoRoll" (default),
   a progress "Bar", or the "Oscilloscope".  PianoRoll[p] / Oscilloscope[p] return p with it
   set; p["Visual"] reads it.  $DefaultVisual sets the global default for unset patterns. *)
(* a pattern carries a LIST of visual specs {name, opts}; multiple stack in a Column.  Each
   setter APPENDS, so p // Oscilloscope // PianoRoll shows both. *)
visualsOf[Track[_, m_Association]] := Lookup[m, "Visuals", {{$DefaultVisual, {}}}]
visualsOf[_Track] := {{"PianoRoll", {}}}
visualsOf[_] := {{$DefaultVisual, {}}}
visualOf[pat_] := visualsOf[pat][[1, 1]]
buttonsQ[pat_] := AnyTrue[visualsOf[pat], TrueQ @ Lookup[Association @ #[[2]], "Buttons", False] &]
setVisual[Track[q_, m_Association], name_, o_ : {}] := Track[q, <|m, "Visuals" -> Append[Lookup[m, "Visuals", {}], {name, o}]|>]
setVisual[Track[q_], name_, o_ : {}] := Track[q, <|"Visuals" -> {{name, o}}|>]

(* PianoRoll[p, opts] / Oscilloscope[p, opts] add a visual AND stash its options: the pianoRoll
   styling (FontSize/Background/"BlockColor"/...) plus "Buttons"->True for transport buttons.
   The curried form chains postfix:  p // PianoRoll[Background -> Red] // Oscilloscope. *)
PianoRoll[p_Track, opts___] := setVisual[p, "PianoRoll", {opts}]
Oscilloscope[p_Track, opts___] := setVisual[p, "Oscilloscope", {opts}]
PianoRoll[opts : OptionsPattern[]][p_Track] := setVisual[p, "PianoRoll", {opts}]
Oscilloscope[opts : OptionsPattern[]][p_Track] := setVisual[p, "Oscilloscope", {opts}]
Punchcard[p_Track, opts___] := setVisual[p, "Punchcard", {opts}]
Punchcard[opts : OptionsPattern[]][p_Track] := setVisual[p, "Punchcard", {opts}]
Track[_, m_Association]["Visual"] := Lookup[m, "Visuals", {{"Bar"}}][[1, 1]]
Track[_]["Visual"] := "Bar"

(* Bars[n] sets the loop/display window -- how many cycles (= bars) the player + its audio span
   (default 2).  Curried, so it chains postfix:  p // Bars[4]  (e.g. <a b c d> shows all four).
   (Named Bars, not Cycles: System`Cycles is protected.) *)
setMeta[Track[q_, m_Association], k_, v_] := Track[q, <|m, k -> v|>]
setMeta[Track[q_], k_, v_] := Track[q, <|k -> v|>]
(* a combined Track inherits the MAX Bars of its voices (so a 4-cycle voice in the mix isn't
   truncated to 2), unless // Bars[n] set an explicit window on the whole composition. *)
maxCycles[voices_] := If[voices === {}, 2, Max[cyclesOf /@ voices]]
cyclesOf[Track[voices_List, m_Association]] := Lookup[m, "Cycles", maxCycles[voices]]
cyclesOf[Track[voices_List]] := maxCycles[voices]
cyclesOf[Track[_, m_Association]] := Lookup[m, "Cycles", 2]
cyclesOf[_] := 2
Bars[n_][p_Track] := setMeta[p, "Cycles", n]
Bars[p_Track, n_] := setMeta[p, "Cycles", n]
(pat_Track)["Cycles"] := cyclesOf[pat]

(* Solo[p] marks a track so that, when its player appears, it silences every OTHER live track
   (i.e. disables everything but this one).  Postfix operator too:  p // Solo.  Verb form. *)
Solo[p_Track] := setMeta[p, "Solo", True]
soloFlagQ[Track[_, m_Association]] := TrueQ @ Lookup[m, "Solo", False]
soloFlagQ[_] := False

(* the default Visual: a simple clickable progress bar with a playhead *)
visualBar[phase_, n_] := With[{x = Mod[phase, n]},
    Graphics[{
        GrayLevel[0.25], Rectangle[{0, 0}, {n, 1}],
        Hue[0.57, 0.45, 0.6], Rectangle[{0, 0}, {x, 1}],
        Hue[0.54, 0.85, 1], Rectangle[{x - 0.007 n, 0}, {x + 0.007 n, 1}]
    }, PlotRange -> {{0, n}, {0, 1}}, AspectRatio -> 1/24, ImageSize -> 480, Background -> GrayLevel[0.13],
        ImagePadding -> 1, Frame -> True, FrameTicks -> None, FrameStyle -> GrayLevel[0.3]]]

(* render one visual (name + its options) as a SELF-UPDATING widget: each reads the clock / stream
   itself on its own UpdateInterval, so the host player builds the visual ONCE (no per-frame
   rebuild of the whole graphic) and only the playhead / wave-Line re-rasterizes.  renderVisuals
   stacks a list of specs into a Column.  Shared (PackageScoped) so TraditionalForm matches. *)
renderVisual["PianoRoll", pat_, n_, stream_, opts_] := Dynamic[pianoRoll[pat, n, visPhase[n], Sequence @@ FilterRules[opts, Options[pianoRoll]]], TrackedSymbols :> {}, UpdateInterval -> 0.03]
renderVisual["Punchcard", pat_, n_, stream_, opts_] := Dynamic[punchcard[pat, n, clockPhaseRaw[], Sequence @@ FilterRules[opts, Options[punchcard]]], TrackedSymbols :> {}, UpdateInterval -> 0.03]
renderVisual["Oscilloscope", pat_, n_, stream_, opts_] := scopeWidget[stream, Sequence @@ FilterRules[opts, Options[scopeFrame]]]
renderVisual[_, pat_, n_, stream_, opts_] := Dynamic[visualBar[visPhase[n], n], TrackedSymbols :> {}, UpdateInterval -> 0.03]
renderVisuals[specs_, pat_, n_, stream_] := With[{ss = If[specs === {}, {{$DefaultVisual, {}}}, specs]},
    If[Length[ss] == 1,
        renderVisual[ss[[1, 1]], pat, n, stream, ss[[1, 2]]],
        Column[Function[s, renderVisual[s[[1]], pat, n, stream, s[[2]]]] /@ ss, Spacings -> 0.3, Alignment -> Left]]]

(* safe playhead read: a not-yet-ready / replaced stream can return a non-Quantity, which
   used to throw inside the refresh and break the whole visualization -- guard it. *)
streamPhase[stream_] := With[{pos = Quiet @ stream["Position"]},
    If[QuantityQ[pos], (QuantityMagnitude[pos] - $AudioLatency) $CyclesPerSecond, $Failed]]

(* the unified live player behind StandardForm and ["Play"]: loop the audio, scrub the playhead,
   click the visual to play/pause; right-click disables this track, double-click solos it (the
   rest go red-framed/disabled).  Paused unless autoplay.
   Playhead is WALL-CLOCK (t0), not stream Position -- polling the stream was what broke the
   player for combinator-derived patterns (Fast/Reverse/...) shown as StandardForm. *)
livePlayer[patOrTrack_, n_ : 2, autoplay_ : False] := With[
    {aud = renderAudio[patOrTrack, n], viss = visualsOf[patOrTrack], buttons = buttonsQ[patOrTrack], solo = soloFlagQ[patOrTrack]},
    DynamicModule[{id = Unique[], stream = AudioStream[aud, Looping -> True], lastClick = 0.},
        (* visual built ONCE (self-updating inner Dynamics drive the playhead/wave); this outer
           Dynamic only re-wraps in the red frame when $Streams (enable/disable) changes. *)
        With[{visual = Dynamic[frameIfDisabled[id, renderVisuals[viss, patOrTrack, n, stream]], TrackedSymbols :> {$Streams}]},
            If[buttons,
                (* buttons: play/pause = global; disable = this track on/off; solo = only this *)
                Column[{
                    Row[{
                        Button["\:25b6", TrackPlay[]],
                        Button["\:23f8", TrackPause[]],
                        Tooltip[Button["\:23f9", If[enabledQ[id], (Quiet @ AudioStop[stream]; unregisterStream[id]), registerStream[id, stream, n]]], "disable this track"],
                        Tooltip[Button["\:25c9", soloStream[id, stream, n]], "solo this track"]
                    }, Spacer[3]],
                    visual
                }, Spacings -> 0.4, Alignment -> Left],
                (* click the visual: left = play/pause (all); right = disable/enable this track;
                   double-click = solo -- play only this track, disable every other *)
                EventHandler[visual,
                    {{"MouseDown", 1} :> (If[AbsoluteTime[] - lastClick < 0.3, soloStream[id, stream, n], If[$Playing, TrackPause[], TrackPlay[]]]; lastClick = AbsoluteTime[]),
                     {"MouseDown", 2} :> If[enabledQ[id], (Quiet @ AudioStop[stream]; unregisterStream[id]), registerStream[id, stream, n]]}]
            ]],
        (* join the global transport: register this stream (plays at the clock position if the
           transport is running); a Solo-marked track silences the rest on appearance; autoplay
           starts the transport if nothing is playing yet *)
        Initialization :> (registerStream[id, stream, n]; If[solo, soloStream[id, stream, n]]; If[autoplay && ! $Playing, TrackPlay[]]),
        Deinitialization :> (unregisterStream[id]; Quiet[AudioStop[stream]; RemoveAudioStream[stream]])
        (* NO SaveDefinitions: it snapshots & re-injects the SHARED $Streams registry per player,
           clobbering live cross-player state (disable/solo/frame) on every (re)display. *)
    ]
]


(* ::Subsection:: Visualizations -- waveform and spectrogram of a pattern / track / audio *)

Options[scopeStatic] = Options[scopeFrame];
scopeStatic[a_, opts : OptionsPattern[]] := AudioPlot[a, AspectRatio -> OptionValue[AspectRatio],
    Background -> OptionValue[Background], PlotStyle -> OptionValue["WaveColor"], Frame -> True,
    FrameTicks -> None, FrameStyle -> OptionValue[FrameStyle], ImageSize -> OptionValue[ImageSize]]
(* static scope of audio/a pattern.  The Except guard keeps this catch-all from firing on the
   heads of the OTHER Oscilloscope forms: _Rule/_RuleDelayed so an options-only
   Oscilloscope[Background->..] stays the operator above, and _Pattern so that on a RELOAD --
   when this DownValue already exists -- defining the curried Oscilloscope[opts:OptionsPattern[]]
   subvalue doesn't evaluate its head Oscilloscope[Pattern[opts,OptionsPattern[]]] into a scope
   (which would hit renderAudio[Pattern[..],2] and throw Duration/AudioPlot errors). *)
Oscilloscope[x : Except[_Rule | _RuleDelayed | _Pattern], nCycles_ : 2, opts : OptionsPattern[scopeStatic]] := scopeStatic[If[MatchQ[x, _Audio], x, renderAudio[x, nCycles]], opts]

Track /: Spectrogram[p_Track, nCycles_ : 2, opts : OptionsPattern[]] := Spectrogram[renderAudio[p, nCycles], opts, ImageSize -> 480]
Track /: Spectrogram[t_Track, nCycles_ : 2, opts : OptionsPattern[]] := Spectrogram[renderAudio[t, nCycles], opts, ImageSize -> 480]


Fastcat[ps__] := fastcatList[{ps}]

(* heads LiveCode treats as atoms (single-token leaves).  The optional Strudel` context
   (WolfAnim/Strudel.wl) registers its own s/note/n/sound here when loaded; the lowercase
   Strudel-style shortcuts now live there, NOT in this paclet context. *)
$LiveAtomHeads = {Track}


(* ::Subsection:: LiveCode -- a symbolic pattern shown as its own InputForm boxes, with each
   atom's box highlighting (Strudel-REPL style) the instant its events sound.  Write the
   pattern symbolically (no mini-notation string) from s/note/n/sound atoms + combinators:
       LiveCode[ stack[ s["bd*4"], note["<c4 e4 g4>"] // fast[2] ] ]
   Left-click = play/pause, right-click = reset. *)

(* tag an atom's events with a source id so we can map events back to the box they came from;
   combinators preserve the extra "Source" key (mapEventTime/reverseCycle now merge it). *)
tagPat[id_][Track[q : (_Function | _Symbol), ___]] := Track[Function[span, (Append[#, "Source" -> id] &) /@ q[span]]]

(* hlAtom is an inert box-time marker: render the atom's own boxes wrapped in a StyleBox whose
   Background lights up while any of its events is sounding (Dynamic on the shared livePhase). *)
SetAttributes[hlAtom, HoldRest]
hlAtom /: MakeBoxes[hlAtom[intervals_, atom_], fmt_] := StyleBox[
    MakeBoxes[atom, fmt],
    Background -> Dynamic[If[liveActiveQ[intervals, livePhase, liveCycles], RGBColor[1, 0.82, 0.25, 0.65], RGBColor[0, 0, 0, 0]]]
]
liveActiveQ[intervals_, phase_, n_] := With[{p = Mod[phase, n]}, AnyTrue[intervals, #[[1]] <= p < Max[#[[2]], #[[1]] + 0.06] &]]

$liveAtom := Alternatives @@ (Blank /@ $LiveAtomHeads)

SetAttributes[LiveCode, HoldFirst]
LiveCode[expr_, nCycles_ : 2] := Module[{held = Hold[expr], atomPos, pat, events, byId, boxExpr, boxes},
    (* ids by position so the same atom gets the same id in the pattern and the boxes; build the
       replacements OUTSIDE the Hold (ReplaceAll into a Hold would NOT evaluate the rule RHS). *)
    atomPos = Position[held, $liveAtom];
    pat = ReleaseHold @ ReplacePart[held, Table[
        atomPos[[i]] -> Replace[Extract[held, atomPos[[i]], Hold], Hold[x_] :> tagPat[i][x]], {i, Length[atomPos]}]];
    events = Select[pat["Query", 0, nCycles], hasOnset];
    byId = GroupBy[events, #["Source"] &, Function[es, #["Whole"] & /@ es]];
    boxExpr = ReplacePart[held, Table[
        atomPos[[i]] -> Replace[Extract[held, atomPos[[i]], Hold], Hold[x_] :> hlAtom[Lookup[byId, i, {}], x]], {i, Length[atomPos]}]];
    boxes = Replace[boxExpr, Hold[c_] :> MakeBoxes[c, StandardForm]];
    With[{b = boxes, aud = renderAudio[pat, nCycles], nC = nCycles},
        DynamicModule[{livePhase = 0., liveCycles = nC, stream = AudioStream[aud, Looping -> True], playing = True},
            AudioPlay[stream];
            EventHandler[
                Panel[
                    Column[{
                        RawBoxes[b],
                        Dynamic @ Refresh[
                            If[playing, livePhase = QuantityMagnitude[stream["Position"]] $CyclesPerSecond];
                            ProgressIndicator[Mod[livePhase, nC], {0, nC}, ImageSize -> {Full, 4}],
                            TrackedSymbols :> {}, UpdateInterval -> 0.03]
                    }, Spacings -> 0.8],
                    Background -> GrayLevel[0.1], FrameMargins -> 14,
                    BaseStyle -> {FontFamily -> "Source Code Pro", FontSize -> 15, FontColor -> GrayLevel[0.92]}
                ],
                {
                    {"MouseDown", 1} :> If[playing, (AudioStop[stream]; playing = False), (AudioPlay[stream]; playing = True)],
                    {"MouseDown", 2} :> (AudioStop[stream]; RemoveAudioStream[stream]; stream = AudioStream[aud, Looping -> True]; livePhase = 0.; playing = False)
                }
            ],
            SaveDefinitions -> True
        ]
    ]
]


(* ::Subsection:: Formatting *)

(* StandardForm is the LIVE piano roll: a looping AudioStream with the playhead scrubbing
   across it, left-click play/pause, right-click reset.  (Get the static still via ["PianoRoll"].) *)
Track /: MakeBoxes[p : Track[_Function | _Symbol, ___],StandardForm] :=
    With[{boxes = ToBoxes[livePlayer[p, cyclesOf[p], True]]}, InterpretationBox[boxes, p]]
Track /: MakeBoxes[t : Track[_List, ___], StandardForm] :=
    With[{boxes = ToBoxes[livePlayer[t, cyclesOf[t], True]]}, InterpretationBox[boxes, t]]

(* TraditionalForm is the editable mini-notation code with per-onset highlighting (defined in
   MiniNotation.wl, for source-bearing patterns).  A pattern with no source string -- a
   combinator result -- has no code to show, so it falls back to the static roll here.
   Switch forms with Cell > Convert To. *)
Track /: MakeBoxes[p : Track[_Function | _Symbol, ___] /; p["Source"] === None, TraditionalForm] :=
    With[{boxes = ToBoxes[pianoRoll[p, 2], StandardForm]}, InterpretationBox[boxes, p]]
Track /: MakeBoxes[t : Track[_List, ___], TraditionalForm] :=
    With[{boxes = ToBoxes[pianoRoll[t, 2], StandardForm]}, InterpretationBox[boxes, t]]
