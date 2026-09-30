(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{BraceLabel}]





(* BraceLabel[g] is Manim's Brace: a curly brace under g, typeset in TeX and stretched across its
   width; BraceLabel[g, dir, label] draws it in dir with label (an AnimatedGraphics) at its tip, and
   "Direction" turns it to another side *)
Options[BraceLabel] = {"Direction" -> Down, "WidthMultiplier" -> 2, "Buffer" -> 0.2, "Height" -> 0.22}

BraceLabel[obj_AnimatedGraphics, Optional[dir : _ ? directiveQ | Automatic, Automatic],
    Optional[text_AnimatedGraphics, AnimatedGraphics[{}]],
    opts : OptionsPattern[]] := Module[{
    direction, angle, corners, left, right, width, numQuads, brace, tip
},
    direction = OptionValue["Direction"] /. {Left -> {-1, 0}, Right -> {1, 0}, Down | Bottom -> {0, -1}, Up | Top -> {0, 1}};
    angle = ArcTan @@ Reverse[direction] - Pi;
    corners = obj["TransformPrimitives", RotationTransform[angle]]["Corners"];
    {left, right} = Values@corners[[{Key[{-1, -1}], Key[{1, -1}]}]];
    width = First[right] - First[left];
    numQuads = Clip[width OptionValue["WidthMultiplier"], {2, 15}];
    brace = AnimatedGraphics[StringTemplate["\\underbrace{``}"][StringJoin @ Table["\\qquad", numQuads]], dir /. Automatic -> obj["Directive"]]["Apply", "Stretch", width, OptionValue["Height"]];   (* stretched across only, like Manim's: a long brace keeps its weight *)
    tip = RotationTransform[- angle][left + {width / 2, -  (OptionValue["Buffer"] + 3 brace["Height"])}];
    AnimatedGraphics[{
        text["Apply", "Translate", tip],
        brace["Apply", "Translate", left - brace["Corners"][{-1, 1}] + {0, - OptionValue["Buffer"]}]["TransformPrimitives", RotationTransform[- angle]]
    }]
]
