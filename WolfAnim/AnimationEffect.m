Package["WolfAnim`"]

PackageExport["AnimationEffect"]



Options[AnimationEffect] = {"Duration" -> 1, "Reverse" -> False, "Rate" -> "Linear"}

$AnimationEffectProperties = {"Function", "Duration", "Reverse", "Rate"};


animationEffectDataQ[data_] :=
    AllTrue[$AnimationEffectProperties, KeyExistsQ[data, #] &] &&
    NumericQ[data["Duration"]]

AnimationEffect[f_Function, OptionsPattern[]] :=
    AnimationEffect[<|"Function" -> f, "Duration" -> OptionValue["Duration"], "Reverse" -> OptionValue["Reverse"], "Rate" -> OptionValue["Rate"]|>]

AnimationEffect[data_ ? animationEffectDataQ][prop_ /; MemberQ[$AnimationEffectProperties, prop]] := data[prop]


eff_AnimationEffect[obj_AnimatedObject] := obj["Play", eff]


animationRateFunction[rate_String] := rate /. {"Linear" -> Function[#], "Quadratic" -> Function[# ^ 2], "Exponential" -> Function[Exp[#] / E]}

animationRateFunction[rate_Function] := rate


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
            Append[Take[pts, i], pts[[i]] + r (pts[[i + 1]] - pts[[i]])]
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

(* creationDrawer[primitive] -> a pure function alpha |-> the primitive being "created" *)
creationDrawer[FilledCurve[c_, o___]] := With[{subs = outlineSubpaths[c], filled = FilledCurve[c, o]},
    Function[alpha, With[{stroke = Min[2 alpha, 1], fill = Ramp[2 alpha - 1]},
        (* draw the border over the first half, then fade the fill in / stroke out over the
           second half so alpha = 1 is exactly the original filled shape (DrawBorderThenFill) *)
        Join[{Opacity[fill], filled, Opacity[1 - fill]}, Line /@ revealSubpaths[subs, stroke]]
    ]]]

creationDrawer[JoinedCurve[c_, ___]] := With[{subs = outlineSubpaths[c]},
    Function[alpha, Line /@ revealSubpaths[subs, alpha]]]

creationDrawer[Line[pts_]] := Function[alpha, Line[partialPolyline[pts, alpha]]]

creationDrawer[(head : BezierCurve | BSplineCurve)[pts_, ___]] := With[{
    sampled = (If[head === BezierCurve, BezierFunction, BSplineFunction][pts]) /@ Subdivide[0, 1, Max[16, 4 Length[pts]]]},
    Function[alpha, Line[partialPolyline[sampled, alpha]]]]

creationDrawer[o_AnimatedObject] := Function[alpha, o]

creationDrawer[p_] := If[ RegionQ[p] || ResourceFunction["GraphicsPrimitiveQ"][p],
    Function[alpha, {Opacity[alpha], p}],   (* filled region / shape: fade in *)
    Function[alpha, p]
]


Options[creationEffect] = {Method -> "Partial", "Delay" -> 0};

creationEffect[duration_, rate_, opts : OptionsPattern[]] := Module[{
    method, args, delay = OptionValue["Delay"]
},
    If[ ListQ[OptionValue[Method]],
        method = First @ OptionValue[Method];
        args = Association @ Rest @ OptionValue[Method],

        method = OptionValue[Method];
        args = <||>
    ];
    Switch[method,
        "Partial",
        Module[{cachedObj = None, drawers = {}},
            AnimationEffect[
                Function @ Module[{obj = #Object, frac},
                    frac = Min[Ramp[rate[#t / duration] - delay / duration], 1];
                    If[ frac >= 1,
                        obj,
                        If[ cachedObj =!= obj,
                            cachedObj = obj;
                            drawers = creationDrawer /@ Flatten[{obj["Primitives"]}]
                        ];
                        obj["SetPrimitives", #[frac] & /@ drawers]
                    ]
                ],
                "Duration" -> duration + delay
            ]
        ],
        "Gradient",
        AnimationEffect[#Object["MapDirective",
            dir |-> Map[
                Replace[c_ ? ColorQ :>
                    LinearGradientFilling[
                        {Ramp[2 (rate[#t / duration] - delay / duration) - 1], Min[Ramp[2 (rate[#t / duration] - delay / duration)], 1]} -> {c, Transparent}, Lookup[args, "Direction", 0]
                    ]
                ],
                dir,
                {0, 1}]
            ] &,
            "Duration" -> duration + delay
        ]
    ]
]


AnimationEffect["Scale", factor_, Optional[p_List, Automatic], opts : OptionsPattern[]] := With[{
    duration = OptionValue["Duration"], rate = animationRateFunction @ OptionValue["Rate"]
},
    AnimationEffect[
        Function @ With[{scale = If[ListQ @ factor, factor, Table[factor, #Object["EmbeddingDimension"]]]},
            #Object["TransformPrimitives", ScalingTransform[(1 + rate[#t / duration] (scale - 1)), p /. Automatic -> #Object["Center"]]]
        ],
    opts
    ]
]

AnimationEffect["Rotate", angle_, Optional[p_List, Automatic], opts : OptionsPattern[]] := With[{
    duration = OptionValue["Duration"], rate = animationRateFunction @ OptionValue["Rate"]
},
    AnimationEffect[#Object["TransformPrimitives",
        RotationTransform[rate[#t / duration] angle, p /. Automatic -> #Object["Center"]]] &,
        opts
    ]
]

AnimationEffect["Translate", v_, opts : OptionsPattern[]] := With[{
    duration = OptionValue["Duration"], rate = animationRateFunction @ OptionValue["Rate"]
},
    AnimationEffect[#Object["TransformPrimitives",
        TranslationTransform[rate[#t / duration] (v /. {Left -> {-1, 0}, Right -> {1, 0}, Down -> {0, -1}, Up -> {0, 1}})]] &,
        opts
    ]
]

AnimationEffect["Stretch", width_, height_ : Automatic, opts : OptionsPattern[]] := Enclose @ AnimationEffect[
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
    creationEffect[OptionValue["Duration"], animationRateFunction @ OptionValue["Rate"], FilterRules[{opts}, Options[creationEffect]]]

AnimationEffect["Wait", opts : OptionsPattern[]] := AnimationEffect[#Object &, opts]


AnimationEffect[effects : {__AnimationEffect}] := AnimationEffect[
    Fold[<|"Object" -> #1["Object"][#2, #1["t"], #1["T"]], "t" -> #1["t"], "T" -> #1["T"]|> &, #, effects]["Object"] &,
    "Duration" -> Max[#["Duration"] & /@ effects]
]



AnimationEffect /: MakeBoxes[eff : AnimationEffect[data_ ? animationEffectDataQ], form_] := Module[{
    above, below
},
    above = {{BoxForm`SummaryItem[{"Duration", ":", Quantity[eff["Duration"], "Seconds"]}]}};
    below = {};
    BoxForm`ArrangeSummaryBox[
        AnimationEffect,
        eff,
        AnimatedObject[RegularPolygon[3]]["Play", eff]["Dynamic"],
        above, below,
        form,
        "Interpretable" -> Automatic
    ]
]