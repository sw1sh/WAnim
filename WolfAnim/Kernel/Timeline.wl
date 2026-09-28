(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Timeline, RasterScreen, CanvasScreen, Easing, EventTrack, TrackPulse}]


(* ::Section:: *)
(*A timeline of layers: pictures as pure functions of time*)

(* A Timeline is the film-scale sibling of AnimatedObject: an ordered stack of layers, each a pure
   function of (absolute) time over a span, composited into one fixed-size canvas.  Like a Track it
   is data you QUERY: tl["Graphics", t] is the frame at time t, and the same structure renders live
   (["Dynamic"], clocked by its soundtrack when it has one), to a still (["Image", t]) or to a video
   (["Video", file], frames rendered in parallel).

     Timeline[{layer, ...}, opts]
       layer = f                       (always on; f[t] -> graphics primitives)
             | {t0, t1} -> f           (on for t0 <= t < t1)
             | {t0, t1} -> obj         (an AnimatedObject, played from t0)

   Time is in the timeline's own unit (e.g. bars); "SecondsPerUnit" converts to seconds for audio
   and video.  The canvas is "Size" -> {w, h} in pixels with the origin bottom-left, so one unit of
   PlotRange is one output pixel and FontSize is in pixels. *)

Options[Timeline] = {
    "Duration" -> Automatic, "Size" -> {1920, 1080}, Background -> Black,
    "SecondsPerUnit" -> 1, "FrameRate" -> 60, "Soundtrack" -> None
}

Timeline[layers_List, opts : OptionsPattern[]] := Timeline[<|
    "Layers" -> normalizeLayer /@ layers,
    "Duration" -> Replace[OptionValue["Duration"], Automatic :> Max[0, Cases[normalizeLayer /@ layers, <|___, "Span" -> {_, e_ ? NumericQ}, ___|> :> e]]],
    "Size" -> OptionValue["Size"], "Background" -> OptionValue[Background],
    "SecondsPerUnit" -> OptionValue["SecondsPerUnit"], "FrameRate" -> OptionValue["FrameRate"],
    "Soundtrack" -> OptionValue["Soundtrack"]
|>]

normalizeLayer[(Rule | RuleDelayed)[{a_, b_}, obj_AnimatedObject]] := <|"Span" -> {a, b}, "Draw" -> Function[t, obj["Update", t - a]["Graphics"]]|>
normalizeLayer[(Rule | RuleDelayed)[{a_, b_}, f_]] := <|"Span" -> {a, b}, "Draw" -> f|>
normalizeLayer[f_] := <|"Span" -> {-Infinity, Infinity}, "Draw" -> f|>

timelineQ[data_] := AssociationQ[data] && KeyExistsQ[data, "Layers"]

Timeline[data_ ? timelineQ][key : "Layers" | "Duration" | "Size" | "Background" | "SecondsPerUnit" | "FrameRate" | "Soundtrack"] := data[key]
tl_Timeline["Seconds"] := tl["Duration"] tl["SecondsPerUnit"]

(* the frame at time t: every layer whose span covers t, in order, each drawn on a fresh canvas of
   the timeline's size (so the Canvas* kit's y-down pixel coordinates just work) *)
Timeline[data_ ? timelineQ]["Primitives", t_] := Table[
    If[l["Span"][[1]] <= t < l["Span"][[2]], CanvasBlock[data["Size"], l["Draw"][t]], Nothing],
    {l, data["Layers"]}
]

tl_Timeline["Graphics", t_, opts : OptionsPattern[Graphics]] := With[{w = tl["Size"][[1]], h = tl["Size"][[2]]},
    Graphics[tl["Primitives", t], opts,
        PlotRange -> {{0, w}, {0, h}}, ImageSize -> w, AspectRatio -> h / w, Background -> tl["Background"],
        PlotRangePadding -> None, ImagePadding -> None, PlotRangeClipping -> True]
]

tl_Timeline["Image", t_, opts : OptionsPattern[Graphics]] := Rasterize[tl["Graphics", t, opts], "Image", ImageResolution -> 72]

(* the soundtrack as one Audio covering the whole timeline (a Track is rendered for as many
   cycles as the timeline lasts, at the current $CyclesPerSecond) *)
tl_Timeline["Audio"] := With[{s = tl["Soundtrack"]},
    Which[
        s === None, None,
        MatchQ[s, _Audio], s,
        True, Audio[s, Ceiling[tl["Seconds"] WolfAnim`$CyclesPerSecond]]
    ]
]


(* ::Section:: *)
(*Live player*)

(* A scrubbable player.  With a soundtrack the AUDIO is the master clock: the picture follows the
   stream's true Position, so it can never drift from what you hear.  Without one it runs on the
   wall clock.  Click the picture (or the button) to play/pause; drag the slider to scrub. *)
Options[timelinePlayer] = {ImageSize -> 960, "UpdateInterval" -> 1 / 30, "StartTime" -> 0}

tl_Timeline["Dynamic", opts : OptionsPattern[timelinePlayer]] := With[{
    dur = tl["Duration"], spu = tl["SecondsPerUnit"], aud = tl["Audio"],
    size = OptionValue[timelinePlayer, {opts}, ImageSize], dt = OptionValue[timelinePlayer, {opts}, "UpdateInterval"],
    t0 = OptionValue[timelinePlayer, {opts}, "StartTime"]
},
    DynamicModule[{t = t0, playing = False, stream = None, begin = 0.},
        Column[{
            EventHandler[
                Dynamic[
                    Refresh[
                        If[ playing,
                            t = If[ stream =!= None,
                                QuantityMagnitude[stream["Position"], "Seconds"] / spu,
                                (AbsoluteTime[] - begin) / spu
                            ];
                            If[t >= dur, t = dur; playing = False; If[stream =!= None, AudioStop[stream]]]
                        ];
                        Show[tl["Graphics", Min[t, dur - 10^-6]], ImageSize -> size],
                        TrackedSymbols :> {t, playing}, UpdateInterval -> If[playing, dt, Infinity]
                    ]
                ],
                {"MouseClicked" :> togglePlay[Hold[t, playing, stream, begin], aud, spu, dur]}
            ],
            Row[{
                Button[Dynamic[If[playing, "\[DoubleVerticalBar]", "\[RightTriangle]"]], togglePlay[Hold[t, playing, stream, begin], aud, spu, dur], Appearance -> "Frameless", ImageSize -> 28],
                Slider[Dynamic[t, (t = #; If[playing, seekTo[Hold[t, playing, stream, begin], aud, spu, #]]) &], {0, dur}, ImageSize -> size - 120],
                Dynamic[Row[{NumberForm[t, {4, 2}], " / ", dur}]]
            }, Spacer[6]]
        }],
        Deinitialization :> If[stream =!= None, Quiet[AudioStop[stream]; RemoveAudioStream[stream]]]
    ]
]

SetAttributes[{togglePlay, seekTo}, HoldFirst]
togglePlay[Hold[t_, playing_, stream_, begin_], aud_, spu_, dur_] := If[ playing,
    playing = False; If[stream =!= None, AudioStop[stream]],
    If[t >= dur, t = 0];
    If[ aud =!= None,
        If[stream === None, stream = AudioStream[aud]];
        AudioPlay[stream]; stream["Position"] = Quantity[t spu, "Seconds"],   (* play, then seek: a seek before the stream rolls is ignored *)
        begin = AbsoluteTime[] - t spu
    ];
    playing = True
]
seekTo[Hold[t_, playing_, stream_, begin_], aud_, spu_, x_] := If[stream =!= None, stream["Position"] = Quantity[x spu, "Seconds"], begin = AbsoluteTime[] - x spu]


(* ::Section:: *)
(*Video*)

(* Frames are rasterized in parallel -- each subkernel loads WolfAnim, receives the definitions the
   layers use (DistributeDefinitions, so a notebook's own functions just work) and runs any extra
   "KernelInitialization" -- written as PNGs, then encoded with ffmpeg together with the soundtrack.
   "From"/"To" select a range in timeline units. *)
Options[timelineVideo] = {"From" -> 0, "To" -> Automatic, "FrameRate" -> Automatic, "KernelInitialization" :> Null,
    "Parallel" -> True, "FrameDirectory" -> Automatic, "CRF" -> 18}

tl_Timeline["Video", file_String, opts : OptionsPattern[timelineVideo]] := Module[{
    from = OptionValue[timelineVideo, {opts}, "From"],
    to = Replace[OptionValue[timelineVideo, {opts}, "To"], Automatic -> tl["Duration"]],
    fps = Replace[OptionValue[timelineVideo, {opts}, "FrameRate"], Automatic -> tl["FrameRate"]],
    spu = tl["SecondsPerUnit"], dir, n, times, aud, wav, ffmpeg, args, res
},
    dir = Replace[OptionValue[timelineVideo, {opts}, "FrameDirectory"], Automatic :> CreateDirectory[]];
    n = Round[(to - from) spu fps];
    times = from + Range[0, n - 1] / (spu fps);
    If[ TrueQ @ OptionValue[timelineVideo, {opts}, "Parallel"],
        If[$KernelCount == 0, LaunchKernels[]];
        With[{root = ParentDirectory[PacletObject["WolfAnim"]["Location"]], cps = WolfAnim`$CyclesPerSecond},
            ParallelEvaluate[PacletDirectoryLoad[root]; Needs["WolfAnim`"]; WolfAnim`$CyclesPerSecond = cps]];
        With[{init = Unevaluated @@ {OptionValue[timelineVideo, {opts}, "KernelInitialization"]}},
            ParallelEvaluate[ReleaseHold[Hold[init]]]
        ];
        (* locals of this package are never distributed, so hand the values over literally *)
        With[{times = times, dir = dir},
            ParallelDo[
                Export[FileNameJoin[{dir, "f" <> IntegerString[i, 10, 6] <> ".png"}], tl["Image", times[[i]]]],
                {i, Length[times]}, Method -> "FinestGrained"
            ]],
        Do[Export[FileNameJoin[{dir, "f" <> IntegerString[i, 10, 6] <> ".png"}], tl["Image", times[[i]]]], {i, n}]
    ];
    aud = tl["Audio"];
    wav = If[aud === None, None,
        Export[FileNameJoin[{dir, "soundtrack.wav"}], AudioTrim[aud, Quantity[{from, to} spu, "Seconds"]]]];
    ffmpeg = SelectFirst[{"/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"}, FileExistsQ, "ffmpeg"];
    args = Join[
        {ffmpeg, "-y", "-v", "error", "-framerate", ToString[fps], "-i", FileNameJoin[{dir, "f%06d.png"}]},
        If[wav === None, {}, {"-i", wav}],
        {"-c:v", "libx264", "-preset", "medium", "-crf", ToString @ OptionValue[timelineVideo, {opts}, "CRF"], "-pix_fmt", "yuv420p"},
        If[wav === None, {}, {"-c:a", "aac", "-b:a", "256k", "-shortest"}],
        {"-movflags", "+faststart", ExpandFileName[file]}
    ];
    res = RunProcess[args];
    If[res["ExitCode"] =!= 0, Return[Failure["FFmpeg", <|"MessageTemplate" -> res["StandardError"]|>]]];
    ExpandFileName[file]
]


(* ::Section:: *)
(*Summary box*)

Timeline /: MakeBoxes[tl : Timeline[data_ ? timelineQ], StandardForm] := BoxForm`ArrangeSummaryBox[
    Timeline, tl,
    Show[tl["Graphics", 0], ImageSize -> 96],
    {
        {BoxForm`SummaryItem[{"Duration: ", data["Duration"]}], BoxForm`SummaryItem[{"Layers: ", Length[data["Layers"]]}]},
        {BoxForm`SummaryItem[{"Size: ", data["Size"]}], BoxForm`SummaryItem[{"Soundtrack: ", If[data["Soundtrack"] === None, None, Head[data["Soundtrack"]]]}]}
    },
    {{BoxForm`SummaryItem[{"Seconds per unit: ", data["SecondsPerUnit"]}], BoxForm`SummaryItem[{"Frame rate: ", data["FrameRate"]}]}},
    StandardForm, "Interpretable" -> Automatic
]


(* ::Section:: *)
(*Era screens: draw at a low resolution, quantize, upscale nearest-neighbour*)

(* RasterScreen[prims, {{x0, y0}, {x1, y1}}] draws prims (in the screen's own LOGICAL pixel
   coordinates, origin bottom-left) into the target rectangle as an old display would:
     "Pixel" -> k       logical pixel = k output pixels
     "Depth" -> "Full"  vector, just magnified (crisp at any zoom)
              | "Bit"   1-bit: luminance threshold (default 160/255), pictures should arrive pre-dithered
              | "Gray4" four greys (NeXT MegaPixel levels 0, 104, 184, 255)
              | "Color" rasterized at the low resolution, colour kept
   Returns a primitive to place in a Graphics whose units are output pixels. *)
Options[RasterScreen] = {"Pixel" -> 2, "Depth" -> "Full", Background -> White, "Threshold" -> 160 / 255}

RasterScreen[prims_, {{x0_, y0_}, {x1_, y1_}}, opts : OptionsPattern[]] := With[{
    k = OptionValue["Pixel"], depth = OptionValue["Depth"], w = x1 - x0, h = y1 - y0
},
    With[{lw = Round[w / k], lh = Round[h / k]},
        If[ depth === "Full",
            Inset[
                Graphics[prims, PlotRange -> {{0, lw}, {0, lh}}, ImageSize -> {w, h}, AspectRatio -> h / w, Background -> OptionValue[Background],
                    PlotRangePadding -> None, ImagePadding -> None, PlotRangeClipping -> True],
                {x0, y0}, {Left, Bottom}, {w, h}],
            Inset[
                ImageResize[
                    quantize[
                        Rasterize[Graphics[prims, PlotRange -> {{0, lw}, {0, lh}}, ImageSize -> {lw, lh}, AspectRatio -> lh / lw,
                            Background -> OptionValue[Background], PlotRangePadding -> None, ImagePadding -> None], "Image", ImageResolution -> 72],
                        depth, OptionValue["Threshold"]],
                    {Round[w], Round[h]}, Resampling -> "Nearest"],
                {x0, y0}, {Left, Bottom}, {w, h}]
        ]
    ]
]

(* CanvasScreen[{x, y, w, h}, f, opts]: the same, placed by a CANVAS rectangle (current transform
   applied) and drawn by f[lw, lh] on the screen's own logical canvas (lw x lh = the rect / "Pixel") *)
CanvasScreen[{x_, y_, w_, h_}, f_, opts : OptionsPattern[RasterScreen]] := With[{k = OptionValue[RasterScreen, {opts}, "Pixel"]},
    With[{lw = Round[w / k], lh = Round[h / k]},
        RasterScreen[CanvasBlock[{lw, lh}, f[lw, lh]], {cxf[{x, y + h}], cxf[{x + w, y}]}, opts]]];

quantize[img_, "Bit", thr_] := ColorConvert[Binarize[ColorConvert[img, "Grayscale"], thr], "RGB"]
quantize[img_, "Gray4", _] := ColorConvert[ImageApply[Which[# < 52 / 255, 0, # < 144 / 255, 104 / 255, # < 220 / 255, 184 / 255, True, 1] &, ColorConvert[img, "Grayscale"]], "RGB"]
quantize[img_, _, _] := img


(* ::Section:: *)
(*Easing*)

(* The standard easing curves (Penner / easings.net), as pure functions on [0, 1] that clamp their
   argument.  Usable anywhere a rate is wanted: Easing["OutCubic"][u], or "Rate" -> "OutCubic"
   on an AnimationEffect.  Easing["OutBack", s] and Easing["OutElastic"] overshoot. *)
Easing["Linear"] = clampU[#] &;
Easing["InCubic"] = clampU[#]^3 &;
Easing["OutCubic"] = 1 - (1 - clampU[#])^3 &;
Easing["InOutCubic"] = With[{u = clampU[#]}, If[u < 0.5, 4 u^3, 1 - (-2 u + 2)^3 / 2]] &;
Easing["InExpo"] = With[{u = clampU[#]}, If[u <= 0, 0., 2.^(10 u - 10)]] &;
Easing["OutExpo"] = With[{u = clampU[#]}, If[u >= 1, 1., 1 - 2.^(-10 u)]] &;
Easing["InOutExpo"] = With[{u = clampU[#]}, Which[u <= 0, 0., u >= 1, 1., u < 0.5, 2.^(20 u - 10) / 2, True, (2 - 2.^(-20 u + 10)) / 2]] &;
Easing["OutBack", s_ : 1.7] := With[{u = clampU[#] - 1}, 1 + (s + 1) u^3 + s u^2] &;
Easing["OutElastic"] = With[{u = clampU[#]}, If[u == 0 || u == 1, u, 2.^(-10 u) Sin[(u 10 - 0.75) 2 Pi / 3] + 1]] &;
Easing["Smooth"] = With[{u = clampU[#]}, u^2 (3 - 2 u)] &;
Easing["Names"] = {"Linear", "InCubic", "OutCubic", "InOutCubic", "InExpo", "OutExpo", "InOutExpo", "OutBack", "OutElastic", "Smooth"}
clampU[u_] := Clip[u, {0, 1}]


(* ::Section:: *)
(*Picture locked to sound*)

(* TrackPulse[track, decay][t] is 1 at each onset of the track and decays exponentially (decay per
   second) until the next: the kick that makes a picture hop, read off the same Track that sounds it.
   t is in cycles. *)
TrackPulse[track_, decay_ : 9][t_] := With[{on = Quiet @ track["Onsets", t - 4, t + 10^-9]},
    If[! ListQ[on] || on === {}, 0., Exp[-decay (t - Max[#["Whole"][[1]] & /@ on]) / WolfAnim`$CyclesPerSecond]]];


(* ::Section:: *)
(*A Track from explicit events*)

(* EventTrack[{{onset, duration, value}, ...}] is a Track (in cycles) that plays exactly those
   events: linear time rather than a cycle, for scores written out note by note (a film score, a
   transcription).  Queries clip each event to the span, keeping its whole extent, so onsets,
   visuals and audio rendering all behave as for any other Track. *)
EventTrack[events_List] := With[{ev = SortBy[events, First]},
    WolfAnim`Track[Function[span, eventsIn[ev, span]], <|"Events" -> ev|>]
]
eventsIn[ev_, {b_, e_}] := Map[
    <|"Value" -> #[[3]], "Whole" -> {#[[1]], #[[1]] + #[[2]]}, "Part" -> {Max[b, #[[1]]], Min[e, #[[1]] + #[[2]]]}|> &,
    Select[ev, #[[1]] < e && #[[1]] + #[[2]] > b &]
]
