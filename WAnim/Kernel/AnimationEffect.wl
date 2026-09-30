(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{AnimationEffect}]






(* "Easing" is the curve an effect runs along: an Easing name ("Smooth", Manim's rate, by default), a
   name with its parameter {"OutBack", 2}, or any function on [0, 1] *)
Options[AnimationEffect] = {"Duration" -> 1, "Reverse" -> False, "Easing" -> "Smooth"}

$AnimationEffectProperties = {"Function", "Duration", "Reverse", "Easing"};


animationEffectDataQ[data_] :=
    AllTrue[$AnimationEffectProperties, KeyExistsQ[data, #] &] &&
    NumericQ[data["Duration"]]

AnimationEffect[f_Function, OptionsPattern[]] :=
    AnimationEffect[<|"Function" -> f, "Duration" -> OptionValue["Duration"], "Reverse" -> OptionValue["Reverse"], "Easing" -> OptionValue["Easing"]|>]

AnimationEffect[data_ ? animationEffectDataQ][prop_ /; MemberQ[$AnimationEffectProperties, prop]] := data[prop]


eff_AnimationEffect[obj_AnimatedGraphics] := obj["Play", eff]


easingOf[e_String] := Easing[e]
easingOf[{e_String, args__}] := Easing[e, args]
easingOf[f_] := f


(* AnimationEffect[] -> a catalog of every effect, the Creation methods and their suboptions *)
AnimationEffect[] := Dataset[{
    <|"Effect" -> "Scale", "Method" -> "", "Arguments" -> "factor, point", "Options" -> "Duration (1), Easing (Smooth), Reverse (False)", "Description" -> "scale by factor about a point (default: the center)"|>,
    <|"Effect" -> "Rotate", "Method" -> "", "Arguments" -> "angle, point", "Options" -> "Duration, Easing, Reverse", "Description" -> "rotate by an angle about a point"|>,
    <|"Effect" -> "Translate", "Method" -> "", "Arguments" -> "vector", "Options" -> "Duration, Easing, Reverse", "Description" -> "translate by a vector (or Left/Right/Up/Down)"|>,
    <|"Effect" -> "Stretch", "Method" -> "", "Arguments" -> "width, height", "Options" -> "Duration, Easing, Reverse", "Description" -> "stretch to a width and/or height"|>,
    <|"Effect" -> "Wait", "Method" -> "", "Arguments" -> "", "Options" -> "Duration, Reverse", "Description" -> "hold without changing"|>,
    <|"Effect" -> "Transform", "Method" -> "", "Arguments" -> "target", "Options" -> "Duration, Easing, Reverse", "Description" -> "turn into another object's shape (Transform)"|>,
    <|"Effect" -> "Creation", "Method" -> "Write", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay (0), LagRatio (0), BorderFraction (0.5)", "Description" -> "trace the outline then fade the fill in (aka Partial, DrawBorderThenFill)"|>,
    <|"Effect" -> "Creation", "Method" -> "Create", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay, LagRatio", "Description" -> "reveal the partial filled path (aka ShowCreation)"|>,
    <|"Effect" -> "Creation", "Method" -> "FadeIn", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay, LagRatio", "Description" -> "fade in"|>,
    <|"Effect" -> "Creation", "Method" -> "GrowFromCenter", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay, ScaleFactor (0)", "Description" -> "scale up from the center"|>,
    <|"Effect" -> "Creation", "Method" -> "GrowFromPoint", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay, Point (center), ScaleFactor (0)", "Description" -> "scale up from a point"|>,
    <|"Effect" -> "Creation", "Method" -> "SpiralIn", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay, ScaleFactor (2), FadeFraction (0.3), Angle (2 Pi)", "Description" -> "spiral inward while fading in"|>,
    <|"Effect" -> "Creation", "Method" -> "ShowIncreasingSubsets", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay, LagRatio (1)", "Description" -> "reveal primitives one at a time"|>,
    <|"Effect" -> "Creation", "Method" -> "Gradient", "Arguments" -> "", "Options" -> "Duration, Easing, Reverse, Delay, Direction (0), Softness (0.15)", "Description" -> "gradient wipe reveal"|>
}]


(* Manim-style creation (VMobject.pointwise_become_partial / DrawBorderThenFill): trace each
   primitive's OUTLINE as a stroke along its ordered path from 0 to alpha, fading the fill in
   so it reaches the exact original shape at alpha = 1. Curve primitives carry their points in
   draw order, so this is a prefix of the path — no discretization needed. *)

componentsOf[c_] := If[MatchQ[c, {_List, ___}], c, {c}]

pathLength[pts_] := If[Length[pts] < 2, 0, Total[EuclideanDistance @@@ Partition[pts, 2, 1]]]

(* arc-length partial of an ordered polyline *)
partialPolyline[pts_, alpha_] := If[Length[pts] < 2, pts,
    Module[{lengths, cumulative, total, target, i, r},
        lengths = EuclideanDistance @@@ Partition[pts, 2, 1];
        cumulative = Prepend[Accumulate[lengths], 0];
        total = Last[cumulative];
        target = alpha total;
        i = LengthWhile[cumulative, # <= target &];
        Which[
            total == 0, pts,
            i >= Length[pts], pts,
            i < 1, Take[pts, 1],
            True,
            r = (target - cumulative[[i]]) / (cumulative[[i + 1]] - cumulative[[i]]);
            Append[Take[pts, i], pts[[i]] + r * (pts[[i + 1]] - pts[[i]])]
        ]
    ]
]

(* decode a connected curve component (ordered BezierCurve/Line segments) into ordered points *)
decodeComponent[segs_, n_ : 10] := Module[{current = None, points = {}, pts},
    Do[
        Switch[Head[seg],
            Line,
            pts = First[seg];
            If[current === None, current = First[pts]; AppendTo[points, current]; pts = Rest[pts]];
            Scan[(current = #; AppendTo[points, #]) &, pts],
            BezierCurve,
            With[{cps = If[current === None, First[seg], Prepend[First[seg], current]]},
                If[current === None, current = First[cps]; AppendTo[points, current]];
                With[{sampled = BezierFunction[cps] /@ Rest[Subdivide[0, 1, n]]},
                    current = Last[sampled]; points = Join[points, sampled]
                ]
            ]
        ],
        {seg, segs}
    ];
    points
]

(* split a point path at pen-up jumps (gaps large relative to the path's extent) *)
splitSubpaths[pts_] := If[Length[pts] < 2, {},
    Module[{gaps, threshold, cuts},
        gaps = EuclideanDistance @@@ Partition[pts, 2, 1];
        threshold = 0.2 Max[1.*^-6, Max[(#[[2]] - #[[1]]) & /@ CoordinateBounds[pts]]];
        cuts = Flatten @ Position[gaps, _ ? (# > threshold &)];
        Select[Internal`PartitionRagged[pts, Differences[Join[{0}, cuts, {Length[pts]}]]], Length[#] >= 2 &]
    ]
]

outlineSubpaths[c_] := Join @@ (splitSubpaths[decodeComponent[#]] & /@ componentsOf[c])

(* reveal subpaths up to fraction alpha of total arc length *)
revealSubpaths[subpaths_, alpha_] := Module[{lengths = pathLength /@ subpaths, total, target, acc = 0, revealed = {}, l},
    total = Total[lengths];
    target = alpha total;
    If[total == 0, subpaths,
        Do[
            l = lengths[[i]];
            Which[
                acc + l <= target, AppendTo[revealed, subpaths[[i]]],
                acc >= target, Null,
                True, AppendTo[revealed, partialPolyline[subpaths[[i]], (target - acc) / l]]
            ];
            acc += l,
            {i, Length[subpaths]}
        ];
        revealed
    ]
]

partialSegments[segs_, alpha_] := Take[segs, Clip[Round[alpha Length[segs]], {0, Length[segs]}]]

(* "Write" (DrawBorderThenFill): trace the outline as a stroke, fading the fill in. bf is the
   fraction of the run spent drawing the border before the fill begins to appear. *)
writeDrawer[FilledCurve[c_, o___], bf_] := With[{subs = outlineSubpaths[c], filled = FilledCurve[c, o]},
    Function[alpha, With[{
        stroke = If[bf <= 0, 1, Min[alpha / bf, 1]],
        fill = If[bf >= 1, Boole[alpha >= 1], Ramp[(alpha - bf) / (1 - bf)]]},
        Join[{Opacity[fill], filled, Opacity[1 - fill]}, Line /@ revealSubpaths[subs, stroke]]
    ]]]

writeDrawer[JoinedCurve[c_, ___], _] := With[{subs = outlineSubpaths[c]},
    Function[alpha, Line /@ revealSubpaths[subs, alpha]]]

writeDrawer[Line[pts_], _] := Function[alpha, Line[partialPolyline[pts, alpha]]]

writeDrawer[(head : BezierCurve | BSplineCurve)[pts_, ___], _] := With[{
    sampled = (If[head === BezierCurve, BezierFunction, BSplineFunction][pts]) /@ Subdivide[0, 1, Max[16, 4 Length[pts]]]},
    Function[alpha, Line[partialPolyline[sampled, alpha]]]]

writeDrawer[p_, _] := If[ RegionQ[p] || ResourceFunction["GraphicsPrimitiveQ"][p],
    Function[alpha, {Opacity[alpha], p}],   (* filled region / shape: fade in *)
    Function[alpha, p]
]

(* "Create" (ShowCreation): reveal the partial filled path, keeping the fill on it *)
createDrawer[FilledCurve[c_, o___]] := With[{comps = componentsOf[c]},
    Function[alpha, FilledCurve[DeleteCases[partialSegments[#, alpha] & /@ comps, {}], o]]]

createDrawer[JoinedCurve[c_, o___]] := With[{comps = componentsOf[c]},
    Function[alpha, JoinedCurve[DeleteCases[partialSegments[#, alpha] & /@ comps, {}], o]]]

createDrawer[Line[pts_]] := Function[alpha, Line[partialPolyline[pts, alpha]]]

createDrawer[p_] := writeDrawer[p, 0.5]

(* per-primitive drawer for a creation method; directives and nested objects pass through *)
creationPrimitiveDrawer[method_, args_][prim_] := Which[
    directiveQ[prim] || MatchQ[prim, _AnimatedGraphics], Function[alpha, prim],
    method === "FadeIn", Function[alpha, {Opacity[alpha], prim}],
    method === "ShowIncreasingSubsets", Function[alpha, If[alpha > 0, prim, Nothing]],
    method === "Create" || method === "ShowCreation", createDrawer[prim],
    True, writeDrawer[prim, Lookup[args, "BorderFraction", 0.5]]
]


Options[creationEffect] = {Method -> "Write", "Delay" -> 0, "LagRatio" -> 0, "Reverse" -> False};

(* Manim-style creation animations. Method is a name or {name, subopt -> val, ...}:
     "Write" | "Partial" | "DrawBorderThenFill"  border-then-fill (subopt "BorderFraction")
     "Create" | "ShowCreation"                   reveal the partial filled path
     "FadeIn"                                     fade in
     "ShowIncreasingSubsets"                      reveal primitives one at a time
     "GrowFromCenter" | "GrowFromPoint"           grow from a point (subopts "Point", "ScaleFactor")
     "SpiralIn"                                   spiral + fade in (subopts "ScaleFactor", "FadeFraction", "Angle")
     "Gradient"                                   gradient wipe (subopt "Direction")
   Shared subopts/options: "Delay", "LagRatio" (stagger across primitives, e.g. letters),
   "Reverse" (play backwards = Uncreate / Unwrite / FadeOut). *)
creationEffect[duration_, rate_, opts : OptionsPattern[]] := Module[{method, args, delay, lag, reverse, result},
    {method, args} = If[ ListQ[OptionValue[Method]],
        {First @ OptionValue[Method], Association @ Rest @ OptionValue[Method]},
        {OptionValue[Method], <||>}
    ];
    delay = Lookup[args, "Delay", OptionValue["Delay"]];
    lag = Lookup[args, "LagRatio", OptionValue["LagRatio"]];
    reverse = TrueQ @ Lookup[args, "Reverse", OptionValue["Reverse"]];
    result = Switch[method,
        "Write" | "Partial" | "DrawBorderThenFill" | "Create" | "ShowCreation" | "FadeIn" | "ShowIncreasingSubsets",
            perPrimitiveCreation[duration, delay, rate, lag, method, args],
        "GrowFromCenter",
            growCreation[duration, delay, rate, Automatic, Lookup[args, "ScaleFactor", 0]],
        "GrowFromPoint",
            growCreation[duration, delay, rate, Lookup[args, "Point", Automatic], Lookup[args, "ScaleFactor", 0]],
        "SpiralIn",
            spiralCreation[duration, delay, rate, Lookup[args, "ScaleFactor", 2], Lookup[args, "FadeFraction", 0.3], Lookup[args, "Angle", 2 Pi]],
        "Gradient",
            gradientCreation[duration, delay, rate, Lookup[args, "Direction", 0], Lookup[args, "Softness", 0.15]],
        _,
            perPrimitiveCreation[duration, delay, rate, lag, "Write", args]
    ];
    If[reverse, AnimationEffect[Append[First[result], "Reverse" -> True]], result]
]

(* an object's primitives with its nested objects spliced in, each after its own directive *)
flatPrimitives[obj_] := Flatten[{obj["Primitives"]} /. o_AnimatedGraphics :> Flatten[{o["Directive"], flatPrimitives[o]}]]

(* methods that reveal each primitive with its own drawer, optionally staggered by LagRatio *)
perPrimitiveCreation[duration_, delay_, rate_, lag0_, method_, args_] :=
    Module[{cachedObj = None, drawers = {}, staggerIdx = {}, maxEnd = 1, lag},
        lag = If[method === "ShowIncreasingSubsets" && lag0 == 0, 1, lag0];
        AnimationEffect[
            Function @ Module[{obj = #Object, frac},
                frac = rate[Clip[(#t - delay) / duration, {0, 1}]];
                If[ frac >= 1,
                    obj,
                    If[ cachedObj =!= obj,
                        cachedObj = obj;
                        (* nested objects (the parts of a formula) are drawn glyph by glyph too *)
                        With[{prims = flatPrimitives[obj]},
                            drawers = creationPrimitiveDrawer[method, args] /@ prims;
                            With[{drawable = Boole[! directiveQ[#] && ! MatchQ[#, _AnimatedGraphics]] & /@ prims},
                                staggerIdx = Accumulate[drawable] - drawable;
                                maxEnd = 1 + Max[Total[drawable] - 1, 0] lag
                            ]
                        ]
                    ];
                    obj["SetPrimitives", MapThread[#1[Clip[frac maxEnd - #2 lag, {0, 1}]] &, {drawers, staggerIdx}]]
                ]
            ],
            "Duration" -> duration + delay
        ]
    ]

growCreation[duration_, delay_, rate_, point_, fromScale_] :=
    AnimationEffect[
        Function @ With[{
            alpha = rate[Clip[(#t - delay) / duration, {0, 1}]],
            pt = point /. Automatic :> #Object["Center"]},
            #Object["TransformPrimitives", ScalingTransform[ConstantArray[Max[fromScale + alpha * (1 - fromScale), 1.*^-3], Length[pt]], pt]]
        ],
        "Duration" -> duration + delay
    ]

spiralCreation[duration_, delay_, rate_, scaleFactor_, fadeFraction_, angle_] :=
    AnimationEffect[
        Function @ Module[{alpha, c, transformed},
            alpha = rate[Clip[(#t - delay) / duration, {0, 1}]];
            c = #Object["Center"];
            transformed = #Object["TransformPrimitives", Composition[
                ScalingTransform[ConstantArray[1 + (1 - alpha) (scaleFactor - 1), Length[c]], c],
                RotationTransform[(1 - alpha) angle, c]]];
            transformed["SetPrimitives", Join[
                {Opacity[If[fadeFraction <= 0, 1, Min[alpha / fadeFraction, 1]]]},
                Flatten[{transformed["Primitives"]}]]]
        ],
        "Duration" -> duration + delay
    ]

(* normalized position of each primitive along the sweep direction (angle in radians) *)
sweepPositions[prims_, dirAngle_] := Module[{dv = {Cos[dirAngle], Sin[dirAngle]}, projs, valid, lo, hi},
    projs = Map[With[{c = Cases[#, {Repeated[_ ? NumericQ, {2, 3}]}, Infinity]},
        If[c === {}, Missing[], Mean[Take[#, 2] & /@ c] . dv]] &, prims];
    valid = Cases[projs, _ ? NumericQ];
    If[ valid === {} || Max[valid] == Min[valid],
        ConstantArray[0., Length[prims]],
        lo = Min[valid]; hi = Max[valid];
        projs /. {p_ ? NumericQ :> (p - lo) / (hi - lo), Missing[] -> 0.}
    ]
]

(* "Gradient": a soft edge sweeps across the object by primitive position, revealing each
   primitive in FULL solid color. "Direction" is the sweep angle (radians), "Softness" the
   soft-edge width. (Done with per-primitive opacity, not a fill gradient, which would apply
   to every glyph's own bounding box and just wash the whole thing out.) *)
gradientCreation[duration_, delay_, rate_, direction_, softness_] :=
    Module[{cachedObj = None, prims = {}, pos = {}},
        AnimationEffect[
            Function @ Module[{obj = #Object, frac, edge},
                frac = rate[Clip[(#t - delay) / duration, {0, 1}]];
                If[ frac >= 1,
                    obj,   (* end on the crisp, solid object *)
                    If[ cachedObj =!= obj,
                        cachedObj = obj;
                        prims = Flatten[{obj["Primitives"]}];
                        pos = sweepPositions[prims, direction]
                    ];
                    edge = frac * (1 + softness);   (* sweep from 0 past 1 so it ends fully solid *)
                    obj["SetPrimitives", MapThread[
                        If[ directiveQ[#1] || MatchQ[#1, _AnimatedGraphics],
                            #1,
                            {Opacity[Clip[(edge - #2) / softness, {0, 1}]], #1}
                        ] &,
                        {prims, pos}]]
                ]
            ],
            "Duration" -> duration + delay
        ]
    ]


AnimationEffect["Scale", factor_, opts : OptionsPattern[]] := AnimationEffect["Scale", factor, Automatic, opts];
AnimationEffect["Scale", factor_, p : _List | Automatic, opts : OptionsPattern[]] := With[{
    duration = OptionValue["Duration"], rate = easingOf @ OptionValue["Easing"]
},
    AnimationEffect[
        Function @ With[{scale = If[ListQ @ factor, factor, Table[factor, Length[#Object["Center"]]]]},
            #Object["TransformPrimitives", ScalingTransform[(1 + rate[#t / duration] (scale - 1)), p /. Automatic -> #Object["Center"]]]
        ],
    opts
    ]
]

AnimationEffect["Rotate", angle_, opts : OptionsPattern[]] := AnimationEffect["Rotate", angle, Automatic, opts];
AnimationEffect["Rotate", angle_, p : _List | Automatic, opts : OptionsPattern[]] := With[{
    duration = OptionValue["Duration"], rate = easingOf @ OptionValue["Easing"]
},
    AnimationEffect[#Object["TransformPrimitives",
        RotationTransform[rate[#t / duration] angle, p /. Automatic -> #Object["Center"]]] &,
        opts
    ]
]

AnimationEffect["Translate", v_, opts : OptionsPattern[]] := With[{
    duration = OptionValue["Duration"], rate = easingOf @ OptionValue["Easing"]
},
    AnimationEffect[#Object["TransformPrimitives",
        TranslationTransform[rate[#t / duration] (v /. {Left -> {-1, 0}, Right -> {1, 0}, Down -> {0, -1}, Up -> {0, 1}})]] &,
        opts
    ]
]

AnimationEffect["Stretch", width_, opts : OptionsPattern[]] := AnimationEffect["Stretch", width, Automatic, opts];
AnimationEffect["Stretch", width_, height : Except[_Rule | _RuleDelayed], opts : OptionsPattern[]] := Enclose @ AnimationEffect[
    Function @ Module[{w, h},
        If[ width =!= Automatic,
            w = width / #Object["Width"];
            h = (height /. Automatic -> w #Object["Height"]) / #Object["Height"],
            ConfirmAssert[height =!= Automatic];
            h = height / #Object["Height"];
            w = (width /. Automatic -> h #Object["Width"]) / #Object["Width"]
        ];
        AnimationEffect["Scale", {w, h}, opts]["Function"][#]
    ],
    opts
]

AnimationEffect["Creation", opts : OptionsPattern[Join[Options[AnimationEffect], Options[creationEffect]]]] :=
    creationEffect[OptionValue["Duration"], easingOf @ OptionValue["Easing"], FilterRules[{opts}, Options[creationEffect]]]

AnimationEffect["Wait", opts : OptionsPattern[]] := AnimationEffect[#Object &, opts]

(* the object's shape turning into target's (Manim's Transform / ReplacementTransform): the outlines
   are blended with Morph and, when it is done, the object is the target *)
AnimationEffect["Transform", target_AnimatedGraphics, opts : OptionsPattern[]] := With[{
    duration = OptionValue["Duration"], rate = easingOf @ OptionValue["Easing"]
},
    AnimationEffect[Function @ With[{u = rate[#t / duration]},
        If[u >= 1, #Object["SetPrimitives", target["Primitives"]]["SetDirective", target["Directive"]],
            #Object["SetPrimitives", morphPrimitive[#Object["Primitives"], target["Primitives"], u]]]], opts]]
firstShape[p_] := FirstCase[{p}, _Line | _Polygon | _Rectangle | _Disk | _Circle | _Triangle | _RegularPolygon, None, Infinity]
morphPrimitive[a_, b_, u_] := With[{sa = firstShape[a], sb = firstShape[b]},
    If[sa === None || sb === None, If[u < 0.5, a, b],
        With[{m = Morph[sa, sb][u]}, If[MatchQ[sa, _Line | _Circle], Line[Append[First[m], First[First[m]]]], m]]]]


AnimationEffect[effects : {__AnimationEffect}] := AnimationEffect[
    Fold[<|"Object" -> #1["Object"][#2, #1["t"], #1["T"]], "t" -> #1["t"], "T" -> #1["T"]|> &, #, effects]["Object"] &,
    "Duration" -> Max[#["Duration"] & /@ effects]
]



(* the summary box shows the effect played on a triangle *)
AnimationEffect /: MakeBoxes[eff : AnimationEffect[data_ ? animationEffectDataQ], StandardForm] := BoxForm`ArrangeSummaryBox[
    AnimationEffect, eff,
    Quiet @ Check[With[{g = AnimatedGraphics[RegularPolygon[3], LightBlue, PlotRange -> {{-1.6, 1.6}, {-1.6, 1.6}}]["Play", eff]}, summaryIcon[g, {0, eff["Duration"]}]], ""],
    {{BoxForm`SummaryItem[{"Duration: ", eff["Duration"]}]}, {BoxForm`SummaryItem[{"Easing: ", eff["Easing"]}]}}, {},
    StandardForm, "Interpretable" -> Automatic]
