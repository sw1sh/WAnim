Package["WolfAnim`"]

PackageExport["AnimatedObject"]

PackageScope["primitiveQ"]
PackageScope["directiveQ"]
PackageScope["$AnimatedObjectDefaultDirective"]


(* AnimatedObject accepts any Graphics / Graphics3D option directly (e.g. Background, PlotRange,
   ImageSize); they are stored and threaded into every rendering. *)
Options[AnimatedObject] = Normal @ Merge[
    {{Background -> Black, PlotRangePadding -> Scaled[0.1]}, Options[Graphics], Options[Graphics3D]},
    First
]

$AnimatedObjectProperties = {"Primitives", "Directive", "Effects", "GraphicsOptions"}

$AnimatedObjectDefaultDirective = {LightBlue}


graphicsDirectiveQ[x_] := ResourceFunction["GraphicsDirectiveQ"][x] || MatchQ[x, _LinearGradientFilling | _RadialGradientFilling | _ConicGradientFilling] ||
    VectorQ[x, graphicsDirectiveQ] && ! MatchQ[x, {}]

graphicsPrimitiveQ[x_] := ResourceFunction["GraphicsPrimitiveQ"][x] || VectorQ[x, graphicsPrimitiveQ] && ! MatchQ[x, {}]

directiveQ[x_] := graphicsDirectiveQ[x]

primitiveQ[x_] := ResourceFunction["GraphicsPrimitiveQ"][x] || RegionQ[x] || MatchQ[x, _AnimatedObject] || graphicsDirectiveQ[x] || VectorQ[x, primitiveQ] && ! MatchQ[x, {}]


animatedObjectDataQ[data_] :=
    AllTrue[$AnimatedObjectProperties, KeyExistsQ[data, #] &] &&
    primitiveQ[data["Primitives"]] &&
    directiveQ[data["Directive"]]


AnimatedObject[g_ ? primitiveQ, Optional[dir : _ ? directiveQ, $AnimatedObjectDefaultDirective], opts : OptionsPattern[]] :=
    AnimatedObject[<|"Primitives" -> g, "Directive" -> dir, "Effects" -> {}, "GraphicsOptions" -> {
        opts, PlotRangePadding -> Scaled[0.1], Background -> Black}|>
    ]

(* A CyclicPattern / Track / Synth|Gain voice / Audio dropped into the object becomes its
   soundtrack: it plays under ["Dynamic"] and is muxed into ["Video"].  Detected by name so
   no symbol has to be shared across the package files. *)
audioObjectQ[x_] := MatchQ[x, _Audio] || MemberQ[{"CyclicPattern", "Track", "SynthVoice", "GainVoice"}, SymbolName[Head[x]]]

AnimatedObject[g_ ? primitiveQ, dir : _ ? directiveQ, audio_ ? audioObjectQ, opts : OptionsPattern[]] := AnimatedObject[g, dir, opts]["SetAudio", audio]
AnimatedObject[g_ ? primitiveQ, audio_ ? audioObjectQ, opts : OptionsPattern[]] := AnimatedObject[g, opts]["SetAudio", audio]

AnimatedObject["" | {}, ___] := AnimatedObject[EmptyRegion[2], Transparent]

(* Extract MaTeX glyphs while keeping each run's fill color (e.g. \color{red}{...}).
   MaTeX wraps each colored run as Style[primitives, FaceForm[color]]; runs with no
   explicit color inherit the object's directive. *)

maTeXColor[FaceForm[c_, ___]] := c
maTeXColor[c : _RGBColor | _GrayLevel | _Hue | _CMYKColor] := c

maTeXColorQ[x_] := MatchQ[x, _FaceForm | _RGBColor | _GrayLevel | _Hue | _CMYKColor]

maTeXStyleColor[s_Style, default_] := FirstCase[s, FaceForm[c_] :> c,
    FirstCase[Rest[List @@ s], _RGBColor | _GrayLevel | _Hue | _CMYKColor, default, Infinity], Infinity]

decodeMaTeXCurve[curve_FilledCurve] := GeometricFunctions`DecodeFilledCurve[curve]
decodeMaTeXCurve[curve_JoinedCurve] := GeometricFunctions`DecodeJoinedCurve[curve]
decodeMaTeXCurve[p_] := p

maTeXColoredPairs[expr_, color_] := Which[
    MatchQ[expr, _Style], maTeXColoredPairs[First[expr], maTeXStyleColor[expr, color]],
    ListQ[expr],
    Module[{c = color, acc = {}},
        Scan[If[maTeXColorQ[#], c = maTeXColor[#], acc = Join[acc, maTeXColoredPairs[#, c]]] &, expr];
        acc
    ],
    ResourceFunction["GraphicsPrimitiveQ"][expr] || RegionQ[expr], {{color, expr}},
    True, {}
]

(* flat primitive list, with a color directive emitted before each run whose color changes *)
(* prev starts at the default so default-colored runs emit NO directive and inherit the
   object's directive (keeps it overridable, e.g. by the "Gradient" creation method); only
   explicitly colored runs embed their color. *)
maTeXPrimitives[graphics_, default_] := Module[{prev = default, out = {}},
    Do[
        If[pair[[1]] =!= prev, out = Join[out, Flatten[{pair[[1]]}]]; prev = pair[[1]]];
        AppendTo[out, decodeMaTeXCurve[pair[[2]]]],
        {pair, maTeXColoredPairs[First[graphics], default]}
    ];
    out
]

AnimatedObject[s_String, Optional[dir : _ ? directiveQ, $AnimatedObjectDefaultDirective], opts : OptionsPattern[]] :=
    AnimatedObject[maTeXPrimitives[MaTeX`MaTeX[s], dir], dir, opts]["Apply", "Stretch", Automatic, 1]["Centralize"]

AnimatedObject[g_Graphics, dir_ : Nothing, opts : OptionsPattern[]] :=
    AnimatedObject[Cases[g, _ ? graphicsPrimitiveQ, {1, 2}], Append[Cases[g, _ ? graphicsDirectiveQ, {1, 2}], dir], opts]


AnimatedObject[data_]["Primitives"] := data["Primitives"]

AnimatedObject[data_]["Directive"] := Replace[data["Directive"], {ds__} :> Directive[ds]]

AnimatedObject[data_]["Effects"] := data["Effects"]

AnimatedObject[data_]["GraphicsOptions"] := data["GraphicsOptions"]

AnimatedObject[data_]["Audio"] := Lookup[data, "Audio", None]
AnimatedObject[data_]["AudioCycles"] := Lookup[data, "AudioCycles", 4]
(obj : AnimatedObject[data_])["SetAudio", audio_, nCycles_ : 4] := AnimatedObject[Join[data, <|"Audio" -> audio, "AudioCycles" -> nCycles|>]]

(* the attached soundtrack rendered to an Audio (CyclicPattern/Track are rendered; an Audio is used as-is) *)
obj_AnimatedObject["AudioObject"] := With[{spec = obj["Audio"]},
    Which[spec === None, None, MatchQ[spec, _Audio], spec, True, Audio[spec, obj["AudioCycles"]]]]


obj_AnimatedObject["Graphics"] := {obj["Directive"], obj["Primitives"] /. o_AnimatedObject :> o["Graphics"]}

(* Nested objects are all updated at the same absolute time T in "Update", so they play
   in parallel (Max), concurrently with this object's own sequential effect queue (Total). *)
obj_AnimatedObject["Duration"] := Max[
    Total[#["Duration"] & /@ obj["Effects"]],
    Cases[obj["Primitives"], o_AnimatedObject :> o["Duration"], All],
    0
]


obj_AnimatedObject[eff_AnimationEffect, t_ : 0, T_ : 0] := eff["Function"] @ <|
    "Object" -> obj,
    "T" -> T,
    "t" -> If[eff["Reverse"], Max[eff["Duration"] - t, 0], Min[t, eff["Duration"]]]
|>

(obj : AnimatedObject[data_])["Update", T_ : 0] := First @ FoldWhile[{
        #1[[1]][#2, T - #1[[2]], T],
        #1[[2]] + #2["Duration"]} &,
    {obj["MapPrimitives", ReplaceAll[o_AnimatedObject :> o["Update", T]]], 0},
    data["Effects"],
    #[[2]] <= T &
]


obj_AnimatedObject["Render", opts : OptionsPattern[Graphics] | OptionsPattern[Graphics3D]] := With[{
    dim = obj["EmbeddingDimension"]
},
    Which[
        dim < 3, Graphics,
        dim == 3, Graphics3D,
        True,
        Failure["UnsupportedDimension", "Only dimensions less or equal to 3 are supported."]
    ][obj["Graphics"], obj["GraphicsOptions"], opts]
]


regionPrimitive[withDirectives_][x_] := Which[
    graphicsDirectiveQ[x], Nothing,
    ListQ[x], regionPrimitive[withDirectives] /@ x,
    RegionQ @ x, x,
    MatchQ[x, _AnimatedObject],
    If[withDirectives, Prepend[x["Directive"]], Identity] @ x["RegionPrimitives"],
    True, DiscretizeGraphics @ x
]

obj_AnimatedObject["RegionPrimitives", withDirectives_ : False, flatten_ : True] :=
    If[flatten, Flatten, Identity] @
    If[ ListQ @ obj["Primitives"],
        regionPrimitive[withDirectives] /@ obj["Primitives"],
        {regionPrimitive[withDirectives] @ obj["Primitives"]}
    ]

obj_AnimatedObject["Region"] := With[{regions = obj["RegionPrimitives"]}, If[ListQ @ regions, RegionUnion @@ Flatten[regions], regions]]

obj_AnimatedObject["EmbeddingDimension"] := Max[RegionEmbeddingDimension /@ obj["RegionPrimitives"]]

obj_AnimatedObject["Dimension"] :=  Max[RegionDimension /@ obj["RegionPrimitives"]]

obj_AnimatedObject["Center"] := Mean /@ obj["Bounds"] // Chop

$pointBasedPrimitiveQ[x_] := MatchQ[x, _FilledCurve | _JoinedCurve | _Line | _Polygon | _Point]

primitiveBounds[x_] := Which[
    MatchQ[x, _AnimatedObject], x["Bounds"],
    graphicsDirectiveQ[x], Nothing,
    $pointBasedPrimitiveQ[x], CoordinateBounds[Cases[x, {Repeated[_ ? NumericQ, {2, 3}]}, Infinity]],
    RegionQ[x], RegionBounds[x],
    True, RegionBounds[DiscretizeGraphics[x]]
]

combineBounds[boundsList_] := Transpose[{
    Min /@ Transpose[boundsList[[All, All, 1]]],
    Max /@ Transpose[boundsList[[All, All, 2]]]
}]

(* Bounding box of a union = union of the per-primitive bounding boxes. For point-based
   primitives (e.g. LaTeX FilledCurves) the box is read straight from the coordinates,
   avoiding the very expensive RegionUnion/discretization of the old Region-based path. *)
obj_AnimatedObject["Bounds"] := Chop @ combineBounds[primitiveBounds /@ Flatten[{obj["Primitives"]}]]

obj_AnimatedObject["Corners"] := Module[{xmin, xmax, ymin, ymax},
    {{xmin, xmax}, {ymin, ymax}} = obj["Bounds"];
    <|{-1, -1} -> {xmin, ymin}, {1, -1} -> {xmax, ymin}, {1, 1} -> {xmax, ymax}, {-1, 1} -> {xmin, ymax}|>
]

obj_AnimatedObject["Width"] := ReverseApplied[Subtract] @@ obj["Bounds"][[1]]

obj_AnimatedObject["Height"] := ReverseApplied[Subtract] @@ obj["Bounds"][[2]]


(* Form-specific display, switchable with Cell > Convert To (or the keyboard shortcuts):
     StandardForm    -> a summary box (info + a live preview)
     TraditionalForm -> the object rendered as its live ["Dynamic"] animation
     InputForm       -> falls through to the raw AnimatedObject[<|...|>] expression *)
AnimatedObject /: MakeBoxes[obj : AnimatedObject[data_ ? animatedObjectDataQ], StandardForm] := Module[{
    above, below
},
    above = {
        {BoxForm`SummaryItem[{"Dimension", ":", obj["Dimension"]}]},
        {BoxForm`SummaryItem[{"Duration", ":", Quantity[obj["Duration"], "Seconds"]}]}
    };
    below = {
        {BoxForm`SummaryItem[{"EmbeddingDimension", ":", obj["EmbeddingDimension"]}]},
        {BoxForm`SummaryItem[{"Center", ":", obj["Center"]}]},
        {BoxForm`SummaryItem[{"Bounds", ":", obj["Bounds"]}]}
    };
    BoxForm`ArrangeSummaryBox[
        AnimatedObject,
        obj, obj["Dynamic"],
        above, below,
        StandardForm,
        "Interpretable" -> Automatic
    ]
]

AnimatedObject /: MakeBoxes[obj : AnimatedObject[data_ ? animatedObjectDataQ], TraditionalForm] := With[{
    boxes = ToBoxes[obj["Dynamic"]]
},
    InterpretationBox[boxes, obj]
]

obj_AnimatedObject["MapData", f_] := MapAt[f, obj, {1}]

obj_AnimatedObject["SetPrimitives", g_] := obj["MapData", Append["Primitives" -> g]]

obj_AnimatedObject["MapPrimitives", f_] := obj["MapData", MapAt[f, Key["Primitives"]]]

obj_AnimatedObject["TransformPrimitives", f_] := obj["MapPrimitives", ReplaceAll @ {
    o_AnimatedObject :> o["TransformPrimitives", f],
    r_ /; RegionQ[r] :> TransformedRegion[r, f],
    g_ /; 
      ResourceFunction["GraphicsPrimitiveQ"][g] :> (g /. 
       points : {{__Real} ..} :> f[points])
    }
]

obj_AnimatedObject["SetDirective", d_] := obj["MapData", Append["Directive" -> d]]

obj_AnimatedObject["MapDirective", f_] := obj["MapData", MapAt[f, Key["Directive"]]]

obj_AnimatedObject["Boundary"] := obj["MapPrimitives", Map[Replace[{
    r_ ? RegionQ :> RegionBoundary[r],
    FilledCurve[a__] :> JoinedCurve[a]}], #, {0, 1}] &
]

obj_AnimatedObject["Centralize"] := obj["TransformPrimitives", TranslationTransform[- obj["Center"]]]


obj_AnimatedObject["MeshRegion", n_ : 100] := With[{reg = obj["Region"]},
    DiscretizeRegion[reg, MaxCellMeasure -> {RegionDimension[reg] -> RegionMeasure[reg] / n}]
]


Options[partialMeshRegion] = {"SortBy" -> None};

partialMeshRegion[reg_MeshRegion, start_ : 0, end_ : 1, OptionsPattern[]] /; 0 <= start <= end <= 1 := Module[{
    dim, primitives, size, from, to
},
    dim = RegionDimension @ reg;
    primitives = MeshPrimitives[reg, dim];
    If[ OptionValue["SortBy"] =!= None,
        primitives = primitives[[
            OrderingBy[AnnotationValue[{reg, dim}, MeshCellCentroid], OptionValue["SortBy"]]
        ]]
    ];
    size = Length @ primitives;
    from = start (size - 1);
    to = end (size - 1);
    primitives[[Ceiling[from] + 1 ;; Floor[to] + 1]]
]

obj_AnimatedObject["Partial", start_ : 0, end_ : 1, sortBy_ : None] /; 0 <= start <= end <= 1 :=
    If[end - start == 1, obj, obj["SetPrimitives", partialMeshRegion[obj["MeshRegion"], start, end, "SortBy" -> sortBy]]]

obj_AnimatedObject["Play", f_AnimationEffect] := obj["MapData", MapAt[Append[f], "Effects"]]

obj_AnimatedObject["Play", name_String, args___] := obj["Play", AnimationEffect[name, args]]

obj_AnimatedObject["Apply", name_String, args___] := With[{eff = AnimationEffect[name, args]},
    eff["Function"][<|"Object" -> obj, "t" -> eff["Duration"], "T" -> obj["Duration"] + eff["Duration"]|>]
]

obj_AnimatedObject["Wait", args___] := obj["Play", "Wait", args]


Options[dynamicGraphics] = Join[
    {"StartTime" -> 0, "FinalTime" -> 1, "Frozen" -> False, "Looping" -> False},
    Normal @ Merge[{Options[Graphics], Options[Graphics3D]}, First],
    Options[DynamicModule]
]

(* Replay control. "StartTime"/"FinalTime" are fractions of the Duration:
     "StartTime" -> where playback begins (default 0)
     "FinalTime" -> where playback ends   (default 1 = the whole animation)
     "Frozen"    -> True starts paused (otherwise it auto-plays)
     "Looping"   -> True loops instead of stopping at FinalTime
   Left-click toggles play/pause; right-click resets to StartTime. *)
dynamicGraphics[obj_AnimatedObject, opts : OptionsPattern[]] := With[{
    start = OptionValue["StartTime"] obj["Duration"],
    final = OptionValue["FinalTime"] obj["Duration"],
    frozen = TrueQ @ OptionValue["Frozen"],
    looping = TrueQ @ OptionValue["Looping"],
    bounds = obj["Bounds"],
    gOpts = obj["GraphicsOptions"],
    render = If[obj["EmbeddingDimension"] < 3, Graphics, Graphics3D],
    graphicsOpts = FilterRules[{opts}, Join[Options[Graphics], Options[Graphics3D]]],
    dynamicModuleOpts = FilterRules[{opts}, Options[DynamicModule]]
},
    DynamicModule[{t = start, begin = AbsoluteTime[], playing = ! frozen},
        Dynamic[
            Refresh[
                If[ playing,
                    With[{elapsed = AbsoluteTime[] - begin},
                        If[ start + elapsed < final,
                            t = start + elapsed,
                            If[looping, (begin = AbsoluteTime[]; t = start), (t = final; playing = False)]
                        ]
                    ]
                ];
                EventHandler[
                    render[obj["Update", t]["Graphics"], gOpts, graphicsOpts, PlotRange -> bounds],
                    {
                        (* left-click: play / pause (resume from where it was; restart if at the end) *)
                        {"MouseDown", 1} :> If[ playing, playing = False,
                            (If[t >= final, t = start]; begin = AbsoluteTime[] - (t - start); playing = True)],
                        (* right-click: reset to StartTime, paused *)
                        {"MouseDown", 2} :> (t = start; playing = False)
                    }
                ],
                TrackedSymbols :> {t, playing}, UpdateInterval -> Infinity
            ]
        ],
        dynamicModuleOpts,
        SaveDefinitions -> True
    ]
]

(* when the object carries a soundtrack, drive the animation from the audio stream's true
   Position (the master clock) and loop both together; clicking toggles play/pause, plus
   transport buttons.  Otherwise use the self-driven visual-only Dynamic above. *)
audioDynamic[obj_AnimatedObject, opts : OptionsPattern[dynamicGraphics]] := With[{
    aud = obj["AudioObject"],
    dur = obj["Duration"],
    bounds = obj["Bounds"],
    gOpts = obj["GraphicsOptions"],
    render = If[obj["EmbeddingDimension"] < 3, Graphics, Graphics3D],
    graphicsOpts = FilterRules[{opts}, Join[Options[Graphics], Options[Graphics3D]]]
},
    DynamicModule[{stream = Null, playing = True, t = 0.},
        stream = AudioStream[aud, Looping -> True];
        AudioPlay[stream];
        Deploy @ Column[{
            Dynamic @ Refresh[
                If[playing && stream =!= Null, t = If[dur > 0, Mod[QuantityMagnitude @ stream["Position"], dur], 0.]];
                EventHandler[
                    render[obj["Update", t]["Graphics"], gOpts, graphicsOpts, PlotRange -> bounds],
                    {
                        {"MouseDown", 1} :> If[playing, (AudioStop[stream]; playing = False), (AudioPlay[stream]; playing = True)],
                        {"MouseDown", 2} :> (AudioStop[stream]; AudioPlay[stream]; playing = True)
                    }
                ],
                TrackedSymbols :> {t, playing}, UpdateInterval -> 0.03
            ],
            Row[{
                Button["\:25b6 play", (AudioPlay[stream]; playing = True)],
                Button["\:23f8 stop", (AudioStop[stream]; playing = False)],
                Button["\:2715 remove", (AudioStop[stream]; RemoveAudioStream[stream]; stream = Null)]
            }, Spacer[8]]
        }],
        SaveDefinitions -> True
    ]
]

obj_AnimatedObject["Dynamic", opts : OptionsPattern[dynamicGraphics]] :=
    If[obj["Audio"] === None, dynamicGraphics[obj, opts], audioDynamic[obj, opts]]


obj_AnimatedObject["Image", opts : OptionsPattern[AnimatedImage]] := With[{
    dur = obj["Duration"],
    bounds = obj["Bounds"],
    gOpts = obj["GraphicsOptions"],
    render = If[obj["EmbeddingDimension"] < 3, Graphics, Graphics3D],
    fps = Replace[OptionValue[AnimatedImage, {opts}, FrameRate], Automatic -> 20],
    imgSize = Replace[OptionValue[AnimatedImage, {opts}, ImageSize], Automatic -> 360]
},
    With[{n = Max[Round[dur * fps], 1]},
        AnimatedImage[
            Table[
                Rasterize[
                    render[obj["Update", t]["Graphics"], gOpts, ImageSize -> imgSize, PlotRange -> bounds],
                    "Image"
                ],
                {t, If[dur > 0, Subdivide[0, dur, n], {0}]}
            ],
            FilterRules[{opts}, Options[AnimatedImage]],
            FrameRate -> fps,
            AnimationRepetitions -> 1
        ]
    ]
]


(* loop/trim a soundtrack to exactly the video's duration so the mux lines up *)
fitAudioToVideo[aud_, durSec_] := With[{d = QuantityMagnitude @ Duration[aud]},
    AudioTrim[
        If[d >= durSec, aud, AudioJoin @@ ConstantArray[aud, Ceiling[durSec / Max[d, 0.001]]]],
        Quantity[{0, durSec}, "Seconds"]]]

obj_AnimatedObject["Video", opts : OptionsPattern[VideoGenerator]] := With[{
    bounds = obj["Bounds"],
    gOpts = obj["GraphicsOptions"],
    render = If[obj["EmbeddingDimension"] < 3, Graphics, Graphics3D],
    aud = obj["AudioObject"],
    dur = obj["Duration"]
},
    With[{vid = Video[
        VideoGenerator[render[obj["Update", #]["Graphics"], gOpts, PlotRange -> bounds] &, dur, opts],
        Appearance -> "Minimal"]},
        If[aud === None, vid, VideoCombine[{vid, fitAudioToVideo[aud, dur]}]]
    ]
]
