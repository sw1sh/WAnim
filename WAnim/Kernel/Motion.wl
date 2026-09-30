(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Easing, Tween, Morph, PartialPath}]


(* ::Section:: *)
(*Easing*)

(* The standard easing curves (Penner / easings.net), as pure functions on [0, 1] that clamp their
   argument.  Usable anywhere a curve is wanted: Easing["OutCubic"][u], Tween[{a, b}, "OutCubic"], or
   "Easing" -> "OutCubic" on an AnimationEffect.  Easing["OutBack", s] and Easing["OutElastic"] overshoot. *)
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
(*Tween: values over time*)

(* Tween[{a, b}] is a function of time going 0 -> 1 from a to b along an Easing curve (default
   "Smooth", Manim's rate), held before and after; Tween[{a, b}, {x, y}] goes from x to y (numbers,
   points or colours); Tween[{{t1, v1}, {t2, v2}, ...}] moves through keyframes, each move eased,
   holding between them -- a Manim ValueTracker and its .animate calls as one value. *)
Tween[{a_ ? NumericQ, b_ ? NumericQ}, e : (_String | {_String, __}) : "Smooth"] := With[{ease = easeOf[e]}, Function[t, ease[Clip[(t - a) / (b - a), {0, 1}]]]];
Tween[{a_ ? NumericQ, b_ ? NumericQ}, {x_, y_}, e : (_String | {_String, __}) : "Smooth"] := With[{u = Tween[{a, b}, e]}, Function[t, mixValues[x, y, u[t]]]];
Tween[keys : {{_ ? NumericQ, _} ..}, e : (_String | {_String, __}) : "Smooth"] /; Length[keys] >= 2 := With[{ks = SortBy[keys, First], ease = easeOf[e]},
    Function[t, Which[t <= ks[[1, 1]], ks[[1, 2]], t >= ks[[-1, 1]], ks[[-1, 2]],
        True, With[{i = LengthWhile[ks, #[[1]] <= t &]}, mixValues[ks[[i, 2]], ks[[i + 1, 2]], ease[(t - ks[[i, 1]]) / (ks[[i + 1, 1]] - ks[[i, 1]])]]]]]];
easeOf[e_String] := Easing[e];
easeOf[{e_String, args__}] := Easing[e, args];
mixValues[x_ ? ColorQ, y_ ? ColorQ, u_] := Blend[{x, y}, u];
mixValues[x_, y_, u_] := x + (y - x) u;


(* ::Section:: *)
(*Morph and PartialPath: shapes as outlines*)

(* Morph[a, b][u] is shape a at u = 0 turning into shape b at u = 1 (Manim's Transform): both
   outlines are sampled at the same n points by arc length, starting due east of their centres and
   running counterclockwise, and the points are blended.  Shapes: Disk, Circle, Rectangle, Polygon,
   Triangle, Line (closed), RegularPolygon or any 2D region. *)
Morph[a_, b_, n_Integer : 120] := With[{pa = outline[a, n], pb = outline[b, n]}, Function[u, Polygon[(1 - u) pa + u pb]]];
Morph[a_, b_, u_ ? NumericQ] := Morph[a, b][u];

(* PartialPath[shape, u] is the first u of shape's outline as a Line (Manim's Create); a Line or
   BSplineCurve is drawn from its first point. *)
PartialPath[Line[pts_ ? MatrixQ], u_] := Line[pathPrefix[pts, u]];
PartialPath[BSplineCurve[pts_, ___], u_] := Line[pathPrefix[BSplineFunction[pts] /@ Subdivide[0., 1., 200], u]];
PartialPath[shape_, u_] := Line[pathPrefix[Append[#, First[#]] &[outline[shape, 240]], u]];
PartialPath[shapes_List, u_] := PartialPath[#, u] & /@ shapes;

pathPrefix[pts_, u_] := Module[{d = Accumulate[Prepend[Norm /@ Differences[N[pts]], 0.]], L, k, s},
    L = u Last[d];
    If[u <= 0, Return[{pts[[1]], pts[[1]]}]]; If[u >= 1, Return[pts]];
    k = LengthWhile[d, # <= L &];
    s = (L - d[[k]]) / (d[[k + 1]] - d[[k]]);
    Append[Take[pts, k], pts[[k]] + s (pts[[k + 1]] - pts[[k]])]];

(* n points around a shape's outline, evenly by arc length, counterclockwise from due east *)
outline[shape_, n_] := Module[{pts = N[ring[shape]], c, d, L, i0},
    If[signedArea[pts] < 0, pts = Reverse[pts]];
    c = Mean[pts];
    i0 = First[Ordering[Abs[ArcTan @@@ (# - c & /@ pts)] + 10 Boole[(# - c)[[1]] < 0] & /@ pts, 1]];
    pts = RotateLeft[pts, i0 - 1];
    pts = Append[pts, First[pts]];
    d = Accumulate[Prepend[Norm /@ Differences[pts], 0.]]; L = Last[d];
    Table[With[{k = Min[Length[pts] - 1, LengthWhile[d, # <= s &]]}, pts[[k]] + (s - d[[k]]) / Max[d[[k + 1]] - d[[k]], 10^-12] (pts[[k + 1]] - pts[[k]])], {s, Most[Subdivide[0., L, n]]}]];
signedArea[pts_] := Total[MapThread[#1[[1]] #2[[2]] - #2[[1]] #1[[2]] &, {pts, RotateLeft[pts]}]] / 2;
ring[(Disk | Circle)[c_ : {0, 0}, r_ : 1, ___]] := Table[c + {1, 1} r {Cos[a], Sin[a]}, {a, 0., 2 Pi - 2 Pi / 360, 2 Pi / 360}];
ring[Rectangle[{x0_, y0_}, {x1_, y1_}, ___]] := {{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}};
ring[Rectangle[{x0_, y0_}]] := ring[Rectangle[{x0, y0}, {x0, y0} + 1]];
ring[(Polygon | Triangle | Line)[pts_ ? MatrixQ, ___]] := If[First[pts] == Last[pts], Most[pts], pts];
ring[r_ ? RegionQ] := First[BoundaryDiscretizeRegion[r]["BoundaryPolygons"]][[1]];
