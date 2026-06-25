Package["WolfAnim`"]

(* ::Section:: A cyclic-time Pattern algebra (one structure, two renderers) *)

(* A CyclicPattern is a pure function of cyclic, exact-rational time: given a query
   timespan it returns the timed events that fall in it.  This is the TidalCycles /
   Strudel "Pattern = query : TimeSpan -> [Event]" abstraction, transplanted to WL with
   native Rational time.  The SAME pattern is rendered two ways: to sound (MusicScore ->
   Audio) and to vision (a piano roll / AnimatedObject effects).  See
   docs/wolfanim-music-design.md. *)

PackageExport["CyclicPattern"]
PackageExport["Steady"]
PackageExport["Silence"]
PackageExport["Fast"]
PackageExport["Slow"]
PackageExport["Layer"]
PackageExport["Alternate"]
PackageExport["Every"]
PackageExport["Euclidean"]
PackageExport["Degrade"]
PackageExport["Track"]
PackageExport["$CyclesPerSecond"]
PackageExport["LoadSamples"]
PackageExport["Synth"]
PackageExport["Gain"]
PackageExport["Late"]
PackageExport["Early"]
PackageExport["Stagger"]
PackageExport["Superimpose"]
PackageExport["$SampleBank"]
PackageExport["Oscilloscope"]
PackageExport["Fastcat"]
PackageExport["LiveCode"]
PackageExport["$LiveAtomHeads"]

(* cycles per second; 0.5625 cps = 135 BPM at 4 beats/cycle = TidalCycles' classic feel *)
$CyclesPerSecond = 0.5625

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
CyclicPattern[q_]["Query", b_, e_] := q[{b, e}]
CyclicPattern[q_]["Cycle", c_ : 0] := q[{c, c + 1}]
CyclicPattern[q_]["Onsets", b_ : 0, e_ : 1] := Select[q[{b, e}], hasOnset]

(* Steady[v] -- TidalCycles "pure": one event per cycle carrying value v *)
Steady[v_] := CyclicPattern[Function[span,
    Function[piece, <|"Value" -> v, "Whole" -> {sam[piece[[1]]], nextSam[piece[[1]]]}, "Part" -> piece|>] /@ spanCycles[span]
]]

Silence = CyclicPattern[Function[span, {}]]

(* mini-notation string -> pattern *)
CyclicPattern[s_String] := parseSequence[StringTrim[s]]


(* ::Subsection:: The combinator algebra (query rewriters) *)

(* Fast[r] compresses time by r; Slow[r] stretches it. Operator forms: Fast[2] @ p. *)
Fast[r_][CyclicPattern[q_]] := CyclicPattern[Function[span,
    mapEventTime[#/r &] /@ q[r # & /@ span]
]]
Fast[_][Silence] := Silence
Slow[r_][p_] := Fast[1/r][p]

(* Reverse a pattern within each cycle (overloads System`Reverse on the new type) *)
CyclicPattern /: Reverse[CyclicPattern[q_]] := CyclicPattern[Function[span,
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
Every[n_, f_][CyclicPattern[q_]] := CyclicPattern[Function[span,
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
Degrade[fraction_][CyclicPattern[q_]] := CyclicPattern[Function[span,
    Select[q[span], stableHash[#] >= fraction &]
]]
stableHash[ev_] := Mod[Hash[{ev["Whole"], ev["Value"]}], 1000]/1000.

(* time shift, and layering combinators *)
Late[t_][CyclicPattern[q_]] := CyclicPattern[Function[span, mapEventTime[# + t &] /@ q[# - t & /@ span]]]
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

(* sample events placed at their onsets *)
sampleLayer[events_] := mix[AudioPad[$SampleBank[#["Value"]], {at[#["Whole"][[1]]], 0}] & /@ Select[events, sampleQ[#["Value"]] &]]
(* pitched events -> MusicScore -> Audio (acoustic-ish) *)
musicLayer[events_, nCycles_] := With[{pe = Select[events, ! sampleQ[#["Value"]] && NumericQ[valueMidi[#["Value"]]] &]},
    If[pe === {}, Nothing, Audio[MusicScore[{eventsToVoice[pe, nCycles]}, MusicTimeSignature[4, 4], MusicTempo -> patternTempo[]]]]]
(* pitched events -> oscillator synth -> Audio *)
oscLayer[events_, wave_] := mix[Function[ev,
    AudioPad[oscNote[wave, midiToFreq[valueMidi[ev["Value"]]], eventDuration[ev] cycleSeconds[]], {at[ev["Whole"][[1]]], 0}]] /@
    Select[events, NumericQ[valueMidi[#["Value"]]] &]]

voiceAudio[GainVoice[g_, v_], nCycles_] := AudioAmplify[voiceAudio[v, nCycles], g]
voiceAudio[SynthVoice[wave_, p_], nCycles_] := fitTo[oscLayer[Select[p["Query", 0, nCycles], hasOnset], wave], nCycles]
voiceAudio[p_CyclicPattern, nCycles_] := With[{ev = Select[p["Query", 0, nCycles], hasOnset]},
    fitTo[mix[{sampleLayer[ev], musicLayer[ev, nCycles]}], nCycles]]

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

rollData[v_, nCycles_] := With[{evs = Select[patternOf[v]["Query", 0, nCycles], hasOnset]},
    {#["Whole"], valueMidi[#["Value"]]} & /@ DeleteCases[evs, _?(MissingQ[valueMidi[#["Value"]]] &)]
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
        MapThread[Function[{laneData, hue},
            {Hue[hue, 0.55, 0.95],
             {#1, Rectangle[{#2[[1, 1]], #2[[2]] - 0.42}, {#2[[1, 2]], #2[[2]] + 0.42}]}[[2]] & @@@ laneData}
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

CyclicPattern[q_]["PianoRoll", nCycles_ : 1] := pianoRoll[CyclicPattern[q], nCycles]
Track[voices_List]["PianoRoll", nCycles_ : 1] := pianoRoll[Track[voices], nCycles]

(* live: loop the rendered bar through an AudioStream and scrub the playhead across the
   piano roll from the stream's true position (the master clock).  Returns a Dynamic. *)
patternPlay[patsOrTrack_, nCycles_ : 1] := With[{aud = renderAudio[patsOrTrack, nCycles]},
    DynamicModule[{stream = AudioStream[aud, Looping -> True], playing = True, head = 0.},
        AudioPlay[stream];
        Dynamic[
            Refresh[
                If[playing, head = QuantityMagnitude[stream["Position"]] $CyclesPerSecond];
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
        SaveDefinitions -> True
    ]
]
CyclicPattern[q_]["Play", nCycles_ : 1] := patternPlay[CyclicPattern[q], nCycles]
Track[voices_List]["Play", nCycles_ : 1] := patternPlay[Track[voices], nCycles]

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
CyclicPattern[q_]["Scope", nCycles_ : 2] := scopePlay[CyclicPattern[q], nCycles]
Track[voices_List]["Scope", nCycles_ : 2] := scopePlay[Track[voices], nCycles]


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
tagPat[id_][CyclicPattern[q_]] := CyclicPattern[Function[span, (Append[#, "Source" -> id] &) /@ q[span]]]

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
LiveCode[expr_, nCycles_ : 2] := Module[{held = Hold[expr], j = 0, k = 0, pat, events, byId, boxExpr, boxes},
    pat = ReleaseHold[held /. a : $liveAtom :> With[{id = ++j}, tagPat[id][a]]];
    events = Select[pat["Query", 0, nCycles], hasOnset];
    byId = GroupBy[events, #["Source"] &, Function[es, #["Whole"] & /@ es]];
    boxExpr = held /. a : $liveAtom :> With[{id = ++k}, hlAtom[Lookup[byId, id, {}], a]];
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


(* ::Subsection:: Formatting -- a pattern shows itself as its piano roll *)

CyclicPattern /: MakeBoxes[p : CyclicPattern[_Function | _Symbol], StandardForm] :=
    With[{boxes = ToBoxes[pianoRoll[p, 1], StandardForm]}, InterpretationBox[boxes, p]]
Track /: MakeBoxes[t : Track[_List], StandardForm] :=
    With[{boxes = ToBoxes[pianoRoll[t, 1], StandardForm]}, InterpretationBox[boxes, t]]

(* TraditionalForm renders the pattern as its live ["Play"] piano roll: left-click
   play/pause, right-click reset, playhead scrubbing the loop.  Switch with Cell > Convert To. *)
CyclicPattern /: MakeBoxes[p : CyclicPattern[_Function | _Symbol], TraditionalForm] :=
    With[{boxes = ToBoxes[patternPlay[p, 2]]}, InterpretationBox[boxes, p]]
Track /: MakeBoxes[t : Track[_List], TraditionalForm] :=
    With[{boxes = ToBoxes[patternPlay[t, 2]]}, InterpretationBox[boxes, t]]
