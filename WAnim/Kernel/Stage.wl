(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Stage, Tween, Morph, PartialPath}]


(* ::Section:: *)
(*Stage: ordinary graphics in math coordinates*)

Options[Stage] = Join[{PlotRange -> {{-64/9, 64/9}, {-4, 4}}, "Screen" -> Automatic, Background -> None,
    FontFamily -> "Source Sans 3", FontSize -> 72, FontColor -> White, "Thickness" -> 4, "Enter" -> "Cut", "Exit" -> "Cut"}, $LayerOptions];

(* Stage[f, {t0, t1}] draws f[t] -- ordinary graphics primitives in math coordinates, origin at the
   centre of a 14.2 x 8 frame by default, as a Manim scene has them -- over the canvas ("Screen" ->
   {x, y, w, h} puts it in a canvas rectangle).  f[t] may also be a Graphics3D, filling the stage.
   PlotRange may be a function of time: a camera that pans and zooms; so may "Screen": a display
   that moves and grows.
   Sizes are in pixels of a 1080p frame and scale with it (Manim's font size 48 reads as about 72): FontSize -> n, Style[s, n],
   AbsoluteThickness[n], AbsolutePointSize[n]; text is FontColor on FontFamily at FontSize, lines
   "Thickness" pixels wide, unless the primitives say otherwise. *)
Stage[f_, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Stage]], g = If[Head[f] === Function, f, Function[t, f]]},
    makeLayer["Stage", {t0, t1}, Function[t, stageDraw[g, t, t0, atTime[o, t]]]]];

stageDraw[f_, t_, t0_, o_] := Module[{r = Replace[ov[o, "Screen"], {Automatic -> {0, 0, $CanvasSize[[1]], $CanvasSize[[2]]}, c : Except[_List] :> c[t]}], p0, p1, w, g = f[t] /. obj_AnimatedObject :> obj["Update", t - t0]["Graphics"], pr = Replace[ov[o, PlotRange], c : Except[_List] :> c[t]]},
    p0 = cxf[{r[[1]], r[[2]] + r[[4]]}]; p1 = cxf[{r[[1]] + r[[3]], r[[2]]}]; w = r[[3]] cscaleX[];
    Inset[If[Head[g] === Graphics3D,
            Show[g, AspectRatio -> r[[4]] / r[[3]], ImagePadding -> None, Background -> Replace[ov[o, Background], None -> Lookup[Options[g], Background, None]]],
            Graphics[{ov[o, FontColor], Thickness[ov[o, "Thickness"] / w], stagePrims[g, w, pr[[1, 2]] - pr[[1, 1]]]}, PlotRange -> pr, AspectRatio -> (pr[[2, 2]] - pr[[2, 1]]) / (pr[[1, 2]] - pr[[1, 1]]),
                PlotRangePadding -> None, ImagePadding -> None, PlotRangeClipping -> True, Background -> ov[o, Background],
                BaseStyle -> {FontFamily -> ov[o, FontFamily], FontSize -> Scaled[ov[o, FontSize] / w], FontColor -> ov[o, FontColor]}]],
        p0, {Left, Bottom}, p1[[1]] - p0[[1]]]];
(* pixel sizes -> fractions of the stage width, so a frame keeps its proportions at any size; an
   inset Graphics (a Plot, AxisObject axes) gets the same treatment relative to its own width, with a
   default text size for its tick labels *)
stagePrims[g_, w_, prw_] := g /. Join[{
    Inset[gr_Graphics, pos_, opos_, size : (_ ? NumericQ | {_ ? NumericQ, _}), rest___] :>
        With[{px = w First[Flatten[{size}]] / prw}, Inset[Show[gr /. sizeRules[px], BaseStyle -> Join[{FontSize -> Scaled[36 / px]}, Flatten[{Lookup[Options[gr /. sizeRules[px]], BaseStyle, {}]}]]], pos, opos, size, rest]]},
    sizeRules[w]];
sizeRules[w_] := {
    (FontSize -> n_ ? NumericQ) :> (FontSize -> Scaled[n / w]),
    Style[x_, a___, n_ ? NumericQ, b___] :> Style[x, a, FontSize -> Scaled[n / w], b],
    Directive[a___, n_ ? NumericQ, b___] :> Directive[a, FontSize -> Scaled[n / w], b],
    AbsoluteThickness[n_ ? NumericQ] :> Thickness[n / w],
    AbsolutePointSize[n_ ? NumericQ] :> PointSize[n / w]};


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
