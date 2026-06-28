(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Brace}]





Options[Brace] = {"Direction" -> Down, "WidthMultiplier" -> 2, "Buffer" -> 0.2}

Brace[obj_AnimatedObject, Optional[dir : _ ? directiveQ | Automatic, $AnimatedObjectDefaultDirective],
    Optional[text_AnimatedObject, AnimatedObject[""]],
    opts : OptionsPattern[]] := Module[{
    direction, angle, corners, left, right, width, numQuads, brace, tip
},
    direction = OptionValue["Direction"] /. {Left -> {-1, 0}, Right -> {1, 0}, Down | Bottom -> {0, -1}, Up | Top -> {0, 1}};
    angle = ArcTan @@ Reverse[direction] - Pi;
    corners = obj["TransformPrimitives", RotationTransform[angle]]["Corners"];
    {left, right} = Values@corners[[{Key[{-1, -1}], Key[{1, -1}]}]];
    width = First[right] - First[left];
    numQuads = Clip[width OptionValue["WidthMultiplier"], {2, 15}];
    brace = AnimatedObject[StringTemplate["\\underbrace{``}"][StringJoin @ Table["\\qquad", numQuads]], dir /. Automatic -> obj["Directive"]]["Apply", "Stretch", width];
    tip = RotationTransform[- angle][left + {width / 2, -  (OptionValue["Buffer"] + 3 brace["Height"])}];
    AnimatedObject[{
        text["Apply", "Translate", tip],
        brace["Apply", "Translate", left - brace["Corners"][{-1, 1}] + {0, - OptionValue["Buffer"]}]["TransformPrimitives", RotationTransform[- angle]]
    }]
]
