(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{TrackView, TrackPlay, TrackPause, TrackSeek, $AudioLatency}]

(* shared with MiniNotation.wl, whose editable TraditionalForm shows the same live views *)
PackageScoped[{renderVisuals, visualsOf, clockPhase, visPhase, seekStream, registerStream, unregisterStream, enabledQ, soloStream, soloFlagQ,
    frameIfDisabled, pianoRoll, $Playing, $Streams}]


(* ::Section:: *)
(*Playing live*)

(* Every Track shows itself as a live player: its audio loops through an AudioStream on one shared
   transport while a view -- a piano roll, a scrolling punch card, an oscilloscope or a progress bar --
   follows the sound. *)

(* seconds every VISUAL (playhead / punchcard line / highlight) is shifted back from the audio
   transport, to compensate output-buffer latency (what you HEAR lags the transport).  Tune it to
   YOUR system: RAISE if the visual runs ahead of the sound, LOWER (toward 0) if it lags behind. *)
$AudioLatency = 0.05

(* the view a playing track shows unless it is given one *)
defaultVisual = "PianoRoll";

(* ONE global transport: a shared clock + a registry of every live stream.  TrackPlay /
   TrackPause / TrackSeek[cyclePos] act on ALL patterns at once, and a newly-created
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

(* DRIFT KILLER -- the AUDIO is the master clock.  Two measured facts (see git log): (a) AudioPlay
   starts the device asynchronously, so every pause/resume leaks a ~0.1-0.2s startup gap; (b) even
   while playing steadily, the stream's position falls behind the AbsoluteTime-based transport.
   Net: all visuals + the highlight creep AHEAD of the sound, worse with each pause.  So a
   watchdog SLEWS THE TRANSPORT to the first stream's actual position (visuals follow instantly;
   the sound is never yanked, so no audible skip) and hard-seeks any OTHER stream that strays.
   All kernel-side scheduled tasks -- never polled from the FE Dynamic (that used to freeze the FE). *)
$ResyncTask = None
(* transport-minus-stream, in seconds, wrapped circularly into (-total/2, total/2]; 0. if unreadable *)
signedDrift[{stream_, n_}] := With[{pos = Quiet @ stream["Position"], total = n / $CyclesPerSecond},
    If[! QuantityQ[pos], 0.,
        With[{raw = Mod[clockPhase[n], n] / $CyclesPerSecond - QuantityMagnitude[pos]},
            raw - total Round[raw / total]]]]
streamDrift[sn_] := Abs[signedDrift[sn]]
(* snap=True (right after a resume, where a jump is expected) corrects the full drift at once;
   the steady-state watchdog instead SLEWS in <=35ms steps -- Position readback is noisy, and
   full-drift corrections every second made all the visuals visibly jump. *)
resyncCheck[snap_ : False] := If[$Playing && Length[$Streams] > 0,
    With[{d = signedDrift[First @ Values @ $Streams]},
        Which[
            snap && Abs[d] > 0.02, $ClockAccum -= d,                   (* clock follows the audio *)
            Abs[d] > 0.045, $ClockAccum -= Clip[d, {-0.035, 0.035}]]];
    Scan[Function[sn, If[streamDrift[sn] > 0.06, seekStream[sn]]], Rest @ Values @ $Streams]]
resyncSoon[] := Quiet @ SessionSubmit[ScheduledTask[resyncCheck[True], {0.4}]]
ensureResyncTask[] := If[$ResyncTask === None, $ResyncTask = Quiet @ SessionSubmit[ScheduledTask[resyncCheck[], 1.]]]

(* a just-created AudioStream may ignore a Position set before it is ready and then play from 0 --
   desynced from the transport, e.g. when a StandardForm<->TraditionalForm switch spawns a fresh
   stream.  Play FIRST, then seek, then re-seek once it is really rolling (resyncSoon). *)
registerStream[id_, stream_, n_] := ($Streams[id] = {stream, n}; If[$Playing, Quiet @ AudioPlay[stream]; seekStream[{stream, n}]; resyncSoon[]])
unregisterStream[id_] := ($Streams = KeyDrop[$Streams, id]; If[$SoloMaster === id, soloRestore[]];)
(* user-facing global transport (exported): act on every registered stream at once.
   TrackPlay[]/TrackPause[] run/halt the shared clock; TrackSeek[cyclePos] jumps the whole
   transport to a cycle position (seeking every stream there). *)
TrackPlay[]  := (If[$ClockStart === None, $ClockStart = AbsoluteTime[]]; $Playing = True; Scan[Function[sn, Quiet @ AudioPlay[First @ sn]; seekStream[sn]], Values @ $Streams]; resyncSoon[]; ensureResyncTask[])
TrackPause[] := (If[$ClockStart =!= None, $ClockAccum += AbsoluteTime[] - $ClockStart; $ClockStart = None]; $Playing = False; Scan[Function[sn, Quiet @ AudioPause[First @ sn]], Values @ $Streams])
TrackSeek[pos_] := ($ClockAccum = pos / $CyclesPerSecond; $ClockStart = If[$Playing, AbsoluteTime[], None]; Scan[Function[sn, seekStream[sn]; If[$Playing, Quiet @ AudioPlay[First @ sn]]], Values @ $Streams])

(* a track is "enabled" iff it is in the registry; right-click toggles that.  Solo is a TOGGLE:
   the first double-click freezes every OTHER currently-active track (saving their registry entries
   in $SoloSaved) and plays only this one.  Double-clicking the SAME track again restores exactly
   those it froze -- tracks already frozen beforehand are untouched, since they were never in
   $Streams to be saved.  Switching the solo to another track first un-solos the previous one.
   All of it propagates across players through the shared $Streams. *)
enabledQ[id_] := KeyExistsQ[$Streams, id]
soloRestore[] := (
    Scan[Function[k, $Streams[k] = $SoloSaved[k];
        If[$Playing, Quiet @ AudioPlay[First @ $SoloSaved[k]]; seekStream[$SoloSaved[k]]]], Keys @ $SoloSaved];
    $SoloSaved = <||>; $SoloMaster = None; resyncSoon[])
soloStream[id_, stream_, n_] := If[$SoloMaster === id,
    soloRestore[],   (* 2nd double-click on the soloing track -> un-solo, thaw only its victims *)
    (If[$SoloMaster =!= None, soloRestore[]];     (* switching solo -> undo the previous one first *)
     $Streams[id] = {stream, n};
     With[{victims = DeleteCases[Keys @ $Streams, id]},
        $SoloSaved = KeyTake[$Streams, victims];
        Scan[Function[k, Quiet @ AudioStop[First @ $Streams[k]]], victims]];
     $Streams = <|id -> {stream, n}|>; $SoloMaster = id;
     If[$ClockStart === None, $ClockStart = AbsoluteTime[]]; $Playing = True;
     Quiet @ AudioPlay[stream]; seekStream[{stream, n}]; resyncSoon[])]
(* disabled tracks are wrapped in a thick red frame so they read as muted at a glance *)
frameIfDisabled[id_, viz_] := If[enabledQ[id], viz,
    Framed[viz, FrameStyle -> Directive[RGBColor[1, 0.25, 0.25], AbsoluteThickness[3]], FrameMargins -> 5, RoundingRadius -> 7, Background -> None]]


(* ::Subsection:: *)
(*Still views*)

(* one block per sounding pitch (a chord draws a block per note); drums get a row of their own *)
rollData[v_, nCycles_] := With[{evs = Select[v["Query", 0, nCycles], hasOnset[#] && ! restQ[#["Value"]] &]},
    Flatten[Function[ev, With[{ps = valuePitches[ev["Value"]]},
        If[ps === {},
            {{ev["Whole"], 36 + Mod[Hash[ev["Value"]], 8], labelOf[ev["Value"]]}},
            {ev["Whole"], #, If[StringQ[ev["Value"]], ev["Value"], midiName[#]]} & /@ ps]]] /@ evs, 1]];

(* all colors are LightDarkSwitched[light, dark] so the roll adapts to the FE appearance;
   every default is overridable via the options below (FontSize, Background, BlockColor,
   LabelColor, PlayheadColor, GridColor, FrameStyle, AspectRatio, ImageSize), and any extra
   Graphics options pass through. *)
(* "LiveCycles" -> n makes the playhead an inner Dynamic line over the ONCE-built blocks, so the
   FE re-rasterizes only the line each frame instead of re-typesetting the whole roll (fps). *)
Options[pianoRoll] = {
    FontSize -> 9, Background -> Automatic, "BlockColor" -> Automatic, "LabelColor" -> Automatic,
    "PlayheadColor" -> Automatic, "GridColor" -> Automatic, FrameStyle -> Automatic,
    AspectRatio -> 1/3, ImageSize -> 480, "LiveCycles" -> None
};
blockColor[Automatic, hue_] := LightDarkSwitched[Hue[hue, 0.7, 0.7], Hue[hue, 0.55, 0.95]]
blockColor[c_, _] := c
pianoRoll[patsOrTrack_, nCycles_ : 1, highlight_ : None, opts : OptionsPattern[]] := Module[
    {lanes, data, mids, lo, hi, bg, blk, labelCol, playCol, gridCol, frameCol, fs, lab},
    lanes = voicesOf[patsOrTrack];
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
        Which[
            OptionValue["LiveCycles"] =!= None,
            With[{nn = OptionValue["LiveCycles"], pc = playCol, l = lo, h = hi},
                Dynamic[{pc, Thickness[0.006], Line[{{visPhase[nn], l}, {visPhase[nn], h}}]},
                    TrackedSymbols :> {}, UpdateInterval -> 0.03]],
            highlight === None, {},
            True, {playCol, Thickness[0.006], Line[{{Mod[highlight, nCycles], lo}, {Mod[highlight, nCycles], hi}}]}]
    },
        PlotRange -> {{0, nCycles}, {lo, hi}}, AspectRatio -> OptionValue[AspectRatio], Background -> bg,
        GridLines -> {Range[0, nCycles], None}, GridLinesStyle -> gridCol,
        Frame -> True, FrameStyle -> frameCol, FrameTicks -> {{None, None}, {Range[0, nCycles], None}},
        ImageSize -> OptionValue[ImageSize], FilterRules[{opts}, Options[Graphics]]
    ]
]

(* Punchcard: a SCROLLING view (unlike the piano roll's moving playhead over fixed blocks).  Each
   event is a full-band-height rectangle; the strip scrolls RIGHT -> LEFT past a FIXED "now" line,
   so a bar sounds as its left edge crosses the line.  One horizontal band per voice; bar colour is
   per-token, opacity rides the voice's gain (a quiet voice has dim bars).  `phase` is the CONTINUOUS
   (unwrapped) clock position so the scroll never jumps at the cycle boundary. *)
valueHue[v_] := Mod[Hash[v], 997]/997.   (* integer mod FIRST -- Hash is ~10^18, so scaling it as a float loses all fractional precision *)
punchColor[Automatic, v_] := LightDarkSwitched[Hue[valueHue[v], 0.55, 0.78], Hue[valueHue[v], 0.5, 0.95]]
punchColor[c_, _] := c
(* "LiveCycles" -> n: bars are built ONCE (in absolute-time coords, one pattern period padded on
   both sides) and an inner Dynamic merely TRANSLATES them each frame -- the FE re-rasterizes one
   transformed layer instead of re-querying + re-typesetting the whole card (fps).  Since the
   pattern repeats every n cycles, translating by the WRAPPED phase is seamless at the loop. *)
Options[punchcard] = {FontSize -> 9, Background -> Automatic, "BlockColor" -> Automatic, "LabelColor" -> Automatic,
    "PlayheadColor" -> Automatic, "GridColor" -> Automatic, FrameStyle -> Automatic, AspectRatio -> 1/4,
    ImageSize -> 480, "Window" -> Automatic, "LiveCycles" -> None};
punchcard[patsOrTrack_, nCycles_ : 1, phase_ : None, opts : OptionsPattern[]] := Module[
    {live, ph, w, x0, lanes, nl, bg, blk, labCol, lineCol, gridCol, frameCol, fs, bar, span, prims, moving},
    live = OptionValue["LiveCycles"] =!= None;
    ph = If[phase === None, 0., N @ phase];
    w = OptionValue["Window"] /. Automatic -> nCycles;
    x0 = 0.5 w;   (* the fixed now-line down the MIDDLE: past scrolls off left, future enters right *)
    lanes = voicesOf[patsOrTrack];
    nl = Length[lanes];
    fs = OptionValue[FontSize];  blk = OptionValue["BlockColor"];
    bg       = OptionValue[Background]      /. Automatic -> LightDarkSwitched[GrayLevel[0.96], GrayLevel[0.12]];
    labCol   = OptionValue["LabelColor"]    /. Automatic -> LightDarkSwitched[GrayLevel[0.1], GrayLevel[0.97]];
    lineCol  = OptionValue["PlayheadColor"] /. Automatic -> LightDarkSwitched[RGBColor[0.85, 0.2, 0.2], RGBColor[1, 0.9, 0.35]];
    gridCol  = OptionValue["GridColor"]     /. Automatic -> LightDarkSwitched[GrayLevel[0.82], GrayLevel[0.25]];
    frameCol = OptionValue[FrameStyle]      /. Automatic -> LightDarkSwitched[GrayLevel[0.6], GrayLevel[0.4]];
    (* bars in ABSOLUTE time coords; a translation puts `now` on the line (screen x = t - now + x0) *)
    bar[gn_, band_][ev_] := With[{x1 = ev["Whole"][[1]], x2 = ev["Whole"][[2]], val = ev["Value"]},
        {Opacity[Clip[0.3 + 0.7 gn, {0.12, 1}]], punchColor[blk, val],
         Rectangle[{x1, band[[1]] + 0.05}, {x2, band[[2]] - 0.05}],
         Text[Style[labelOf[val], fs, FontFamily -> "Source Code Pro", FontWeight -> Bold, FontColor -> labCol], {Mean[{x1, x2}], Mean[band]}]}];
    span = If[live, {-(nCycles + 1), w + nCycles + 1}, {ph - x0 - 1, ph + w - x0}];
    prims = MapIndexed[Function[{lane, i}, bar[Lookup[Lookup[metaOf[lane], "Instrument", <||>], "Gain", 1], {nl - First[i], nl - First[i] + 1}] /@
        Select[lane["Query", span[[1]], span[[2]]], hasOnset[#] && ! restQ[#["Value"]] &]], lanes];
    moving = If[live,
        With[{nn = OptionValue["LiveCycles"], xx0 = x0, pr = prims},
            Dynamic[GeometricTransformation[pr, TranslationTransform[{xx0 - visPhase[nn], 0}]],
                TrackedSymbols :> {}, UpdateInterval -> 0.03]],
        GeometricTransformation[prims, TranslationTransform[{x0 - ph, 0}]]];
    Graphics[{
        EdgeForm[LightDarkSwitched[GrayLevel[0.7, 0.5], GrayLevel[0.05, 0.5]]],
        moving,
        {lineCol, Thickness[0.011], Line[{{x0, 0}, {x0, Max[nl, 1]}}]}
    },
        PlotRange -> {{0, w}, {0, Max[nl, 1]}}, PlotRangeClipping -> True,
        AspectRatio -> OptionValue[AspectRatio], Background -> bg,
        GridLines -> {None, Range[0, nl]}, GridLinesStyle -> gridCol,
        Frame -> True, FrameStyle -> frameCol, FrameTicks -> None,
        ImageSize -> OptionValue[ImageSize], FilterRules[{opts}, Options[Graphics]]
    ]
]

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

visualBarShell[cursor_, n_] := Graphics[{
        GrayLevel[0.25], Rectangle[{0, 0}, {n, 1}], cursor
    }, PlotRange -> {{0, n}, {0, 1}}, AspectRatio -> 1/24, ImageSize -> 480, Background -> GrayLevel[0.13],
        ImagePadding -> 1, Frame -> True, FrameTicks -> None, FrameStyle -> GrayLevel[0.3]]
barCursor[x_, n_] := {Hue[0.57, 0.45, 0.6], Rectangle[{0, 0}, {x, 1}],
    Hue[0.54, 0.85, 1], Rectangle[{x - 0.007 n, 0}, {x + 0.007 n, 1}]}
visualBarLive[n_] := visualBarShell[Dynamic[barCursor[visPhase[n], n], TrackedSymbols :> {}, UpdateInterval -> 0.03], n]

(* ::Subsection:: *)
(*Views*)

(* TrackView[view, ..., opts][track] sets what the track shows while it plays: "PianoRoll" (the default),
   "Punchcard", "Oscilloscope" or "Bar", several stacked in a column, each styled by the options
   (FontSize, Background, ImageSize, AspectRatio, "BlockColor", "PlayheadColor", ...).  Its own options:
     "Cycles"   how many cycles it shows and loops (by default its voices' longest, else 2)
     "Solo"     True silences every other playing track when it appears
     "Buttons"  True adds play, pause, disable and solo buttons *)
$views = "PianoRoll" | "Punchcard" | "Oscilloscope" | "Bar";
TrackView[views : $views ..., opts : (_Rule | _RuleDelayed) ...][t_Track] := Module[{m = metaOf[t], o = Association[opts], style},
    style = Normal @ KeyDrop[o, {"Cycles", "Solo", "Buttons"}];
    If[{views} =!= {}, m["Visuals"] = {#, style} & /@ {views}];
    Scan[If[KeyExistsQ[o, #], m[#] = o[#]] &, {"Cycles", "Solo", "Buttons"}];
    Track[First[t], m]];
visualsOf[t_Track] := Lookup[metaOf[t], "Visuals", {{defaultVisual, {}}}];
buttonsQ[t_Track] := TrueQ @ Lookup[metaOf[t], "Buttons", False];
soloFlagQ[t_Track] := TrueQ @ Lookup[metaOf[t], "Solo", False];

(* stills: track["PianoRoll", n] and track["Punchcard", n] *)
(t_Track)["PianoRoll", n_ : Automatic, opts : OptionsPattern[pianoRoll]] := pianoRoll[t, Replace[n, Automatic :> cyclesOf[t]], None, opts];
(t_Track)["Punchcard", n_ : Automatic, opts : OptionsPattern[punchcard]] := punchcard[t, Replace[n, Automatic :> cyclesOf[t]], None, opts];

(* render one visual (name + its options) as a shell built ONCE with only its MOVING part on an
   inner Dynamic -- the playhead line (roll), the translated bar strip (punchcard), the wave Line
   (scope), the progress cursor (bar).  The FE re-rasterizes just that primitive each frame instead
   of re-typesetting the whole graphic: this is the fps.  renderVisuals stacks a list of specs into
   a Column.  Shared (PackageScoped) so TraditionalForm matches. *)
renderVisual["PianoRoll", pat_, n_, stream_, opts_] := pianoRoll[pat, n, None, "LiveCycles" -> n, Sequence @@ FilterRules[opts, Options[pianoRoll]]]
renderVisual["Punchcard", pat_, n_, stream_, opts_] := punchcard[pat, n, None, "LiveCycles" -> n, Sequence @@ FilterRules[opts, Options[punchcard]]]
renderVisual["Oscilloscope", pat_, n_, stream_, opts_] := scopeWidget[stream, Sequence @@ FilterRules[opts, Options[scopeFrame]]]
renderVisual[_, pat_, n_, stream_, opts_] := visualBarLive[n]
renderVisuals[specs_, pat_, n_, stream_] := With[{ss = If[specs === {}, {{defaultVisual, {}}}, specs]},
    If[Length[ss] == 1,
        renderVisual[ss[[1, 1]], pat, n, stream, ss[[1, 2]]],
        Column[Function[s, renderVisual[s[[1]], pat, n, stream, s[[2]]]] /@ ss, Spacings -> 0.3, Alignment -> Left]]]

(* the unified live player behind StandardForm and ["Play"]: loop the audio, scrub the playhead,
   click the visual to play/pause; right-click disables this track, double-click solos it (the
   rest go red-framed/disabled).  Paused unless autoplay.
   Playhead is WALL-CLOCK (t0), not stream Position -- polling the stream was what broke the
   player for combinator-derived patterns (Fast/Reverse/...) shown as StandardForm. *)
livePlayer[patOrTrack_, n_ : 2, autoplay_ : False] := With[
    {aud = renderAudio[patOrTrack, n, True], viss = visualsOf[patOrTrack], buttons = buttonsQ[patOrTrack], solo = soloFlagQ[patOrTrack]},
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
        Initialization :> (Needs["WolframInstitute`WAnim`"]; registerStream[id, stream, n]; If[solo, soloStream[id, stream, n]]; If[autoplay && ! $Playing, TrackPlay[]]),
        Deinitialization :> (unregisterStream[id]; Quiet[AudioStop[stream]; RemoveAudioStream[stream]]),
        (* the package's contexts are internal ones, so saving definitions never snapshots the SHARED
           $Streams registry (which would clobber live disable/solo state on every display) *)
        SaveDefinitions -> True
    ]
]


(* ::Subsection:: *)
(*Formatting*)

(* StandardForm is the live player; TraditionalForm is the editable, highlighting mini-notation
   (MiniNotation.wl) for a track with a source, and the still piano roll for one without *)
Track /: MakeBoxes[t_Track, StandardForm] := With[{boxes = ToBoxes[livePlayer[t, cyclesOf[t], True]]}, InterpretationBox[boxes, t]];
Track /: MakeBoxes[t_Track /; t["Source"] === None, TraditionalForm] := With[{boxes = ToBoxes[pianoRoll[t, cyclesOf[t]], StandardForm]}, InterpretationBox[boxes, t]];
