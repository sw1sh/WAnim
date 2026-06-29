(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{CyclicPattern, Steady, Silence, Fast, Slow, Layer, Alternate, Every, Euclidean, Degrade, Track, $CyclesPerSecond, $AudioLatency, $DefaultWave, $DefaultVisual, LoadSamples, Synth, Gain, Late, Early, Stagger, Superimpose, $SampleBank, Oscilloscope, PianoRoll, Fastcat, LiveCode, $LiveAtomHeads}]

(* shared with MiniNotation.wl so the TraditionalForm can render the same live Visual *)
PackageScoped[{renderVisual, visualOf, streamPhase}]



(* ::Section:: A cyclic-time Pattern algebra (one structure, two renderers) *)

(* A CyclicPattern is a pure function of cyclic, exact-rational time: given a query
   timespan it returns the timed events that fall in it.  This is the TidalCycles /
   Strudel "Pattern = query : TimeSpan -> [Event]" abstraction, transplanted to WL with
   native Rational time.  The SAME pattern is rendered two ways: to sound (MusicScore ->
   Audio) and to vision (a piano roll / AnimatedObject effects).  See
   docs/wolfanim-music-design.md. *)


(* cycles per second; 0.5625 cps = 135 BPM at 4 beats/cycle = TidalCycles' classic feel *)
$CyclesPerSecond = 0.5625

(* seconds to shift the visual playhead/highlight back from the audio stream's reported
   position, to compensate output latency (what you hear lags what the stream reports).
   Default 0 = no shift; raise it (~0.05-0.2) if the highlight flashes ahead of the sound. *)
$AudioLatency = 0.

(* default oscillator timbre for pitched notes (Sine/Triangle/Sawtooth/Square/Supersaw). *)
$DefaultWave = "Sawtooth"

(* default live Visual for patterns with none set: "PianoRoll" (labeled blocks), "Bar", "Oscilloscope". *)
$DefaultVisual = "PianoRoll"

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

(* the canonical form is CyclicPattern[queryFunction]; these are its query methods *)
CyclicPattern[q_, ___]["Query", b_, e_] := q[{b, e}]
CyclicPattern[q_, ___]["Cycle", c_ : 0] := q[{c, c + 1}]
CyclicPattern[q_, ___]["Onsets", b_ : 0, e_ : 1] := Select[q[{b, e}], hasOnset]

(* a string-parsed pattern carries its source + AST as an optional 2nd arg (an Association);
   derived patterns (from combinators) are single-arg and have no source. *)
CyclicPattern[_, meta_Association]["Source"] := Lookup[meta, "Source", None]
CyclicPattern[_, meta_Association]["AST"] := Lookup[meta, "AST", None]
CyclicPattern[_]["Source"] := None
CyclicPattern[_]["AST"] := None

(* Steady[v] -- TidalCycles "pure": one event per cycle carrying value v *)
Steady[v_] := CyclicPattern[Function[span,
    Function[piece, <|"Value" -> v, "Whole" -> {sam[piece[[1]]], nextSam[piece[[1]]]}, "Part" -> piece|>] /@ spanCycles[span]
]]

Silence = CyclicPattern[Function[span, {}]]

(* mini-notation string -> pattern *)
CyclicPattern[s_String] := parseSequence[StringTrim[s]]


(* ::Subsection:: The combinator algebra (query rewriters) *)

(* Fast[r] compresses time by r; Slow[r] stretches it. Operator forms: Fast[2] @ p. *)
Fast[r_][CyclicPattern[q_, ___]] := CyclicPattern[Function[span,
    mapEventTime[#/r &] /@ q[r # & /@ span]
]]
Fast[_][Silence] := Silence
Slow[r_][p_] := Fast[1/r][p]

(* Reverse a pattern within each cycle (overloads System`Reverse on the new type) *)
CyclicPattern /: Reverse[CyclicPattern[q_, ___]] := CyclicPattern[Function[span,
    Join @@ (reverseCycle[q, #] & /@ spanCycles[span])
]]
reverseCycle[q_, {b_, e_}] := With[{c = sam[b]},
    With[{reflect = Function[{x, y}, {2 c + 1 - y, 2 c + 1 - x}]},
        Function[ev, <|ev,
            "Whole" -> If[ev["Whole"] === None, None, reflect @@ ev["Whole"]],
            "Part" -> reflect @@ ev["Part"]
        |>] /@ q[reflect @@ {b, e}]
    ]
]

(* Layer -- play patterns simultaneously (TidalCycles "stack"): union of events *)
Layer[ps__CyclicPattern] := CyclicPattern[Function[span,
    Join @@ (Function[p, p["Query", span[[1]], span[[2]]]] /@ {ps})
]]
Layer[ps_List] := Layer @@ ps
Layer[p_CyclicPattern] := p

(* Alternate -- one sub-pattern per cycle (TidalCycles "slowcat" / mini-notation <...>) *)
Alternate[p_CyclicPattern] := p
Alternate[ps__CyclicPattern] := With[{pats = {ps}, n = Length[{ps}]},
    CyclicPattern[Function[span, Join @@ (alternateCycle[pats, n, #] & /@ spanCycles[span])]]
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
Every[n_, f_][CyclicPattern[q_, ___]] := CyclicPattern[Function[span,
    Join @@ (Function[piece,
        If[Mod[sam[piece[[1]]], n] == 0,
            f[CyclicPattern[q]]["Query", piece[[1]], piece[[2]]],
            q[piece]
        ]] /@ spanCycles[span])
]]

(* Euclidean[k, n] -- Bjorklund rhythm: k onsets spread maximally evenly over n steps *)
Euclidean[k_, n_][p_] := Euclidean[k, n, 0][p]
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
Degrade[p_CyclicPattern] := Degrade[0.5][p]
Degrade[fraction_][CyclicPattern[q_, ___]] := CyclicPattern[Function[span,
    Select[q[span], stableHash[#] >= fraction &]
]]
stableHash[ev_] := Mod[Hash[{ev["Whole"], ev["Value"]}], 1000]/1000.

(* time shift, and layering combinators *)
Late[t_][CyclicPattern[q_, ___]] := CyclicPattern[Function[span, mapEventTime[# + t &] /@ q[# - t & /@ span]]]
Early[t_] := Late[-t]
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

valueMidi[v_Integer] := v
valueMidi[v_String] := Quiet@Check[MusicPitch[v]["MIDINumber"], Missing[]]
valueMidi[_] := Missing[]

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
patternScore[v : _CyclicPattern | _SynthVoice | _GainVoice, nCycles_] := patternScore[{v}, nCycles]
patternScore[Track[voices_List], nCycles_] := patternScore[voices, nCycles]


(* ::Subsection:: Audio renderer: drum samples + oscillator synth + MusicScore, overlaid *)

(* a voice carrying a wave gets oscillator synthesis; Gain scales its level *)
Synth[wave_String][p_] := SynthVoice[wave, p]
Gain[g_][v_] := GainVoice[g, v]

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
    Select[events, sampleQ[#["Value"]] || ! NumericQ[valueMidi[#["Value"]]] &]]
(* pitched events -> MusicScore -> Audio (acoustic-ish) *)
musicLayer[events_, nCycles_] := With[{pe = Select[events, ! sampleQ[#["Value"]] && NumericQ[valueMidi[#["Value"]]] &]},
    If[pe === {}, Nothing, Audio[MusicScore[{eventsToVoice[pe, nCycles]}, MusicTimeSignature[4, 4], MusicTempo -> patternTempo[]]]]]
(* pitched events -> oscillator synth -> Audio *)
oscLayer[events_, wave_] := mix[Function[ev,
    AudioPad[oscNote[wave, midiToFreq[valueMidi[ev["Value"]]], eventDuration[ev] cycleSeconds[]], {at[ev["Whole"][[1]]], 0}]] /@
    Select[events, NumericQ[valueMidi[#["Value"]]] &]]

voiceAudio[GainVoice[g_, v_], nCycles_] := AudioAmplify[voiceAudio[v, nCycles], g]
voiceAudio[SynthVoice[wave_, p_], nCycles_] := fitTo[oscLayer[Select[p["Query", 0, nCycles], hasOnset], wave], nCycles]
(* default pitched rendering uses self-contained OSCILLATORS, not MusicScore/FluidSynth: the
   external soundfont backend is slow to re-render on every live edit and was the likely source
   of the kernel-reconnect ("MathLink") dialog + instability.  Set $DefaultWave to retimbre, or
   wrap a voice in Synth["..."] for an explicit oscillator.  (MusicScore is still used by
   ["Score"]/MusicPlot/Sound.) *)
voiceAudio[p_CyclicPattern, nCycles_] := With[{ev = Select[p["Query", 0, nCycles], hasOnset]},
    fitTo[mix[{sampleLayer[ev], oscLayer[ev, $DefaultWave]}], nCycles]]

renderAudio[Track[voices_List], nCycles_] := AudioNormalize @ fitDuration[mix[voiceAudio[#, nCycles] & /@ voices], nCycles cycleSeconds[]]
renderAudio[v_, nCycles_] := fitTo[voiceAudio[v, nCycles], nCycles]

CyclicPattern /: Audio[p_CyclicPattern, nCycles_ : 1] := renderAudio[p, nCycles]
CyclicPattern /: MusicPlot[p_CyclicPattern, nCycles_ : 1, opts___] := MusicPlot[patternScore[p, nCycles], opts]
CyclicPattern /: Sound[p_CyclicPattern, nCycles_ : 1] := Sound[patternScore[p, nCycles]]
SynthVoice /: Audio[v_SynthVoice, nCycles_ : 1] := renderAudio[v, nCycles]
GainVoice /: Audio[v_GainVoice, nCycles_ : 1] := renderAudio[v, nCycles]


(* ::Subsection:: Track: a multi-voice composition (each line its own timbre/voice) *)

voiceQ[v_] := MatchQ[v, _CyclicPattern | _SynthVoice | _GainVoice]
Track[ps__?voiceQ] := Track[{ps}]
Track[t_Track] := t

Track[voices_List]["Voices"] := voices
Track[voices_List]["Score", nCycles_ : 1] := patternScore[voices, nCycles]

Track /: Audio[Track[voices_List], nCycles_ : 1] := renderAudio[Track[voices], nCycles]
Track /: MusicPlot[Track[voices_List], nCycles_ : 1, opts___] := MusicPlot[patternScore[voices, nCycles], opts]
Track /: Sound[Track[voices_List], nCycles_ : 1] := Sound[patternScore[voices, nCycles]]


(* ::Subsection:: Vision renderer: piano roll (static) and an audio-synced animation *)

(* pitched tokens take their MIDI row; sample / non-pitch tokens (bd, hh, ...) get a stable
   low percussion row so a drum pattern still draws instead of an empty (black) roll. *)
laneValue[val_] := With[{m = valueMidi[val]}, If[NumericQ[m], Round[m], 36 + Mod[Hash[val], 8]]]
rollData[v_, nCycles_] := With[{evs = Select[patternOf[v]["Query", 0, nCycles], hasOnset]},
    {#["Whole"], laneValue[#["Value"]], #["Value"]} & /@ evs   (* {whole, row, token} *)
]

pianoRoll[patsOrTrack_, nCycles_ : 1, highlight_ : None] := Module[{lanes, data, mids, lo, hi},
    lanes = Which[
        MatchQ[patsOrTrack, _Track], patsOrTrack["Voices"],
        MatchQ[patsOrTrack, _List], patsOrTrack,
        True, {patsOrTrack}
    ];
    data = MapIndexed[Function[{lane, i}, {First[i], #} & /@ rollData[lane, nCycles]], lanes];
    mids = Cases[Flatten[data, 1][[All, 2, 2]], _Integer];
    If[mids === {}, Return[Graphics[{}, ImageSize -> 360]]];
    lo = Min[mids] - 2; hi = Max[mids] + 2;
    Graphics[{
        EdgeForm[{GrayLevel[0.1]}],
        (* each block is its mini-notation token, drawn as a labeled rectangle *)
        MapThread[Function[{laneData, hue},
            Function[{li, wrt}, {
                Hue[hue, 0.55, 0.95], Rectangle[{wrt[[1, 1]], wrt[[2]] - 0.42}, {wrt[[1, 2]], wrt[[2]] + 0.42}],
                GrayLevel[0.1], Text[Style[wrt[[3]], 9, FontFamily -> "Source Code Pro", FontWeight -> Bold], {Mean[wrt[[1]]], wrt[[2]]}]
            }] @@@ laneData
        ], {data, If[Length[lanes] == 1, {0.58}, Range[0, Length[lanes] - 1]/Length[lanes]]}],
        If[highlight === None, {},
            {GrayLevel[1, 0.85], Thickness[0.006], Line[{{Mod[highlight, nCycles], lo}, {Mod[highlight, nCycles], hi}}]}]
    },
        PlotRange -> {{0, nCycles}, {lo, hi}}, AspectRatio -> 1/3, Background -> GrayLevel[0.13],
        GridLines -> {Range[0, nCycles], None}, GridLinesStyle -> GrayLevel[0.28],
        Frame -> True, FrameStyle -> GrayLevel[0.4], FrameTicks -> {{None, None}, {Range[0, nCycles], None}},
        ImageSize -> 480
    ]
]

CyclicPattern[q_, ___]["PianoRoll", nCycles_ : 1] := pianoRoll[CyclicPattern[q], nCycles]
Track[voices_List]["PianoRoll", nCycles_ : 1] := pianoRoll[Track[voices], nCycles]

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
CyclicPattern[q_, m___]["Play", nCycles_ : 2] := livePlayer[CyclicPattern[q, m], nCycles, True]
Track[voices_List]["Play", nCycles_ : 2] := livePlayer[Track[voices], nCycles, True]

(* ["Scope"] plays the loop and shows a live oscilloscope of the audio stream's current
   buffer; same click mechanics as ["Play"] (left = play/pause, right = reset). *)
scopeFrame[snippet_] := With[{wave = Quiet @ Check[Flatten @ AudioData[snippet], {0.}]},
    ListLinePlot[wave, PlotRange -> {All, {-1.05, 1.05}}, AspectRatio -> 1/3, Axes -> False,
        Frame -> True, FrameTicks -> None, FrameStyle -> GrayLevel[0.3], Background -> GrayLevel[0.08],
        PlotStyle -> Directive[RGBColor[0.25, 1, 0.55], Thickness[0.004]],
        GridLines -> {None, {0}}, GridLinesStyle -> GrayLevel[0.25], ImageSize -> 480, ImagePadding -> 4]]

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
CyclicPattern[q_, ___]["Scope", nCycles_ : 2] := scopePlay[CyclicPattern[q], nCycles]
Track[voices_List]["Scope", nCycles_ : 2] := scopePlay[Track[voices], nCycles]


(* ::Subsection:: The "Visual" property + the unified live player *)

(* A pattern's Visual is what it shows as its live display: the labeled "PianoRoll" (default),
   a progress "Bar", or the "Oscilloscope".  PianoRoll[p] / Oscilloscope[p] return p with it
   set; p["Visual"] reads it.  $DefaultVisual sets the global default for unset patterns. *)
visualOf[CyclicPattern[_, m_Association]] := Lookup[m, "Visual", $DefaultVisual]
visualOf[_Track] := "PianoRoll"
visualOf[_] := $DefaultVisual
setVisual[CyclicPattern[q_, m_Association], v_] := CyclicPattern[q, <|m, "Visual" -> v|>]
setVisual[CyclicPattern[q_], v_] := CyclicPattern[q, <|"Visual" -> v|>]

PianoRoll[p_CyclicPattern] := setVisual[p, "PianoRoll"]
Oscilloscope[p_CyclicPattern] := setVisual[p, "Oscilloscope"]
CyclicPattern[_, m_Association]["Visual"] := Lookup[m, "Visual", "Bar"]
CyclicPattern[_]["Visual"] := "Bar"

(* the default Visual: a simple clickable progress bar with a playhead *)
visualBar[phase_, n_] := With[{x = Mod[phase, n]},
    Graphics[{
        GrayLevel[0.25], Rectangle[{0, 0}, {n, 1}],
        Hue[0.57, 0.45, 0.6], Rectangle[{0, 0}, {x, 1}],
        Hue[0.54, 0.85, 1], Rectangle[{x - 0.007 n, 0}, {x + 0.007 n, 1}]
    }, PlotRange -> {{0, n}, {0, 1}}, AspectRatio -> 1/24, ImageSize -> 480, Background -> GrayLevel[0.13],
        ImagePadding -> 1, Frame -> True, FrameTicks -> None, FrameStyle -> GrayLevel[0.3]]]

(* render the chosen Visual at the current playhead phase; the scope reads the stream's
   live buffer.  Shared (PackageScoped) so MiniNotation's TraditionalForm shows the same. *)
renderVisual["PianoRoll", pat_, n_, phase_, stream_] := pianoRoll[pat, n, phase]
renderVisual["Oscilloscope", pat_, n_, phase_, stream_] := scopeFrame[stream["CurrentAudio"]]
renderVisual[_, pat_, n_, phase_, stream_] := visualBar[phase, n]

(* safe playhead read: a not-yet-ready / replaced stream can return a non-Quantity, which
   used to throw inside the refresh and break the whole visualization -- guard it. *)
streamPhase[stream_] := With[{pos = Quiet @ stream["Position"]},
    If[QuantityQ[pos], (QuantityMagnitude[pos] - $AudioLatency) $CyclesPerSecond, $Failed]]

(* the unified live player behind StandardForm and ["Play"]: loop the audio, scrub the
   playhead, click the visual to play/pause (right-click resets).  Paused unless autoplay. *)
livePlayer[patOrTrack_, n_ : 2, autoplay_ : False] := With[{aud = renderAudio[patOrTrack, n], vis = visualOf[patOrTrack]},
    DynamicModule[{stream = AudioStream[aud, Looping -> True], playing = autoplay, phase = 0.},
        EventHandler[
            Dynamic @ Refresh[
                If[playing, With[{ph = streamPhase[stream]}, If[NumericQ[ph], phase = ph]]];
                renderVisual[vis, patOrTrack, n, phase, stream],
                TrackedSymbols :> {}, UpdateInterval -> 0.03],
            {
                {"MouseDown", 1} :> If[playing, (Quiet @ AudioPause[stream]; playing = False), (Quiet @ AudioResume[stream]; playing = True)],
                {"MouseDown", 2} :> (Quiet @ AudioStop[stream]; phase = 0.; playing = False)
            }],
        (* AudioPlay once, on first appearance -- not on every body re-eval *)
        Initialization :> If[autoplay, Quiet @ AudioPlay[stream]],
        Deinitialization :> Quiet[AudioStop[stream]; RemoveAudioStream[stream]],
        SaveDefinitions -> True
    ]
]


(* ::Subsection:: Visualizations -- waveform and spectrogram of a pattern / track / audio *)

scopeStatic[a_] := AudioPlot[a, AspectRatio -> 1/3, Background -> GrayLevel[0.08],
    PlotStyle -> RGBColor[0.25, 1, 0.55], Frame -> True, FrameTicks -> None,
    FrameStyle -> GrayLevel[0.3], ImageSize -> 480]
Oscilloscope[x_, nCycles_ : 2] := scopeStatic @ If[MatchQ[x, _Audio], x, renderAudio[x, nCycles]]

CyclicPattern /: Spectrogram[p_CyclicPattern, nCycles_ : 2, opts : OptionsPattern[]] := Spectrogram[renderAudio[p, nCycles], opts, ImageSize -> 480]
Track /: Spectrogram[t_Track, nCycles_ : 2, opts : OptionsPattern[]] := Spectrogram[renderAudio[t, nCycles], opts, ImageSize -> 480]


Fastcat[ps__] := fastcatList[{ps}]

(* heads LiveCode treats as atoms (single-token leaves).  The optional Strudel` context
   (WolfAnim/Strudel.wl) registers its own s/note/n/sound here when loaded; the lowercase
   Strudel-style shortcuts now live there, NOT in this paclet context. *)
$LiveAtomHeads = {CyclicPattern}


(* ::Subsection:: LiveCode -- a symbolic pattern shown as its own InputForm boxes, with each
   atom's box highlighting (Strudel-REPL style) the instant its events sound.  Write the
   pattern symbolically (no mini-notation string) from s/note/n/sound atoms + combinators:
       LiveCode[ stack[ s["bd*4"], note["<c4 e4 g4>"] // fast[2] ] ]
   Left-click = play/pause, right-click = reset. *)

(* tag an atom's events with a source id so we can map events back to the box they came from;
   combinators preserve the extra "Source" key (mapEventTime/reverseCycle now merge it). *)
tagPat[id_][CyclicPattern[q_, ___]] := CyclicPattern[Function[span, (Append[#, "Source" -> id] &) /@ q[span]]]

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
CyclicPattern /: MakeBoxes[p : CyclicPattern[_Function | _Symbol, ___],StandardForm] :=
    With[{boxes = ToBoxes[livePlayer[p, 2, True]]}, InterpretationBox[boxes, p]]
Track /: MakeBoxes[t : Track[_List], StandardForm] :=
    With[{boxes = ToBoxes[livePlayer[t, 2, True]]}, InterpretationBox[boxes, t]]

(* TraditionalForm is the editable mini-notation code with per-onset highlighting (defined in
   MiniNotation.wl, for source-bearing patterns).  A pattern with no source string -- a
   combinator result -- has no code to show, so it falls back to the static roll here.
   Switch forms with Cell > Convert To. *)
CyclicPattern /: MakeBoxes[p : CyclicPattern[_Function | _Symbol, ___] /; p["Source"] === None, TraditionalForm] :=
    With[{boxes = ToBoxes[pianoRoll[p, 2], StandardForm]}, InterpretationBox[boxes, p]]
Track /: MakeBoxes[t : Track[_List], TraditionalForm] :=
    With[{boxes = ToBoxes[pianoRoll[t, 2], StandardForm]}, InterpretationBox[boxes, t]]
