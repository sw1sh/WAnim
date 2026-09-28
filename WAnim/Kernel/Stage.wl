(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Stage, StageAxes, StageBrace, Tween, Morph, PartialPath}]


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
Stage[f_, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Stage]]},
    makeLayer["Stage", {t0, t1}, Function[t, stageDraw[f, t, atTime[o, t]]]]];

stageDraw[f_, t_, o_] := Module[{r = Replace[ov[o, "Screen"], {Automatic -> {0, 0, $CanvasSize[[1]], $CanvasSize[[2]]}, c : Except[_List] :> c[t]}], p0, p1, w, g = f[t], pr = Replace[ov[o, PlotRange], c : Except[_List] :> c[t]]},
    p0 = cxf[{r[[1]], r[[2]] + r[[4]]}]; p1 = cxf[{r[[1]] + r[[3]], r[[2]]}]; w = r[[3]] cscaleX[];
    Inset[If[Head[g] === Graphics3D,
            Show[g, AspectRatio -> r[[4]] / r[[3]], ImagePadding -> None, Background -> Replace[ov[o, Background], None -> Lookup[Options[g], Background, None]]],
            Graphics[{ov[o, FontColor], Thickness[ov[o, "Thickness"] / w], stagePrims[g, w]}, PlotRange -> pr, AspectRatio -> (pr[[2, 2]] - pr[[2, 1]]) / (pr[[1, 2]] - pr[[1, 1]]),
                PlotRangePadding -> None, ImagePadding -> None, PlotRangeClipping -> True, Background -> ov[o, Background],
                BaseStyle -> {FontFamily -> ov[o, FontFamily], FontSize -> Scaled[ov[o, FontSize] / w], FontColor -> ov[o, FontColor]}]],
        p0, {Left, Bottom}, p1[[1]] - p0[[1]]]];
(* pixel sizes -> fractions of the stage width, so a frame keeps its proportions at any size *)
stagePrims[g_, w_] := g /. {
    (FontSize -> n_ ? NumericQ) :> (FontSize -> Scaled[n / w]),
    Style[x_, n_ ? NumericQ, rest___] :> Style[x, FontSize -> Scaled[n / w], rest],
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


(* ::Section:: *)
(*StageAxes: a coordinate system on the stage*)

Options[StageAxes] = {"Size" -> {12, 6}, "Center" -> {0, 0}, "Color" -> White, "Tips" -> True, "Numbers" -> {{}, {}}, "LongTicks" -> {{}, {}},
    "Thickness" -> 2, "TickLength" -> 0.1, "NumberSize" -> 36};

(* ax = StageAxes[{x0, x1, dx}, {y0, y1, dy}] is a pair of axes on a Stage, "Size" stage units big
   around "Center" (Manim's Axes): ax["Primitives"] draws them, with ticks every step, the numbers
   in "Numbers" -> {{x, ...}, {y, ...}} and arrow tips; ax[{x, y}] is where a data point sits on the
   stage; ax["Graph", f, {a, b}] is the curve of f; ax["Area", f, g, {a, b}] the region between two
   functions (g may be a constant); ax["Riemann", f, {a, b}, dx] rectangles under f;
   ax["VerticalLine", {x, y}] a line down to the x axis; ax["Labels", xlabel, ylabel] the axis names. *)
StageAxes[{x0_, x1_, dx_ : 1}, {y0_, y1_, dy_ : 1}, opts : OptionsPattern[]] := StageAxes[<|"X" -> {x0, x1, dx}, "Y" -> {y0, y1, dy},
    "Options" -> Join[{opts}, Options[StageAxes]]|>];
axesQ[a_] := AssociationQ[a] && KeyExistsQ[a, "X"] && KeyExistsQ[a, "Options"];
axOpt[a_, name_] := ov[a["Options"], name];
StageAxes[a_ ? axesQ][{x_ ? NumericQ, y_ ? NumericQ}] := With[{sz = axOpt[a, "Size"], c = axOpt[a, "Center"], X = a["X"], Y = a["Y"]},
    c + {sz[[1]] ((x - X[[1]]) / (X[[2]] - X[[1]]) - 1/2), sz[[2]] ((y - Y[[1]]) / (Y[[2]] - Y[[1]]) - 1/2)}];
StageAxes[a_ ? axesQ][pts_ ? MatrixQ] := StageAxes[a] /@ pts;
StageAxes[a_ ? axesQ]["Primitives"] := Module[{ax = StageAxes[a], X = a["X"], Y = a["Y"], ox, oy, tl = axOpt[a, "TickLength"], col = axOpt[a, "Color"], nums = axOpt[a, "Numbers"], long = axOpt[a, "LongTicks"]},
    ox = Clip[0, X[[;; 2]]]; oy = Clip[0, Y[[;; 2]]];
    {col, AbsoluteThickness[axOpt[a, "Thickness"]], If[TrueQ[axOpt[a, "Tips"]], Arrowheads[0.012], Arrowheads[0]],
     Arrow[ax[{{X[[1]], oy}, {X[[2]], oy}}]], Arrow[ax[{{ox, Y[[1]]}, {ox, Y[[2]]}}]],
     Table[With[{p = ax[{x, oy}], k = If[MemberQ[long[[1]], x], 2, 1]}, Line[{p - {0, k tl}, p + {0, k tl}}]], {x, Select[Range[X[[1]], X[[2]], X[[3]]], # != ox &]}],
     Table[With[{p = ax[{ox, y}], k = If[MemberQ[long[[2]], y], 2, 1]}, Line[{p - {k tl, 0}, p + {k tl, 0}}]], {y, Select[Range[Y[[1]], Y[[2]], Y[[3]]], # != oy &]}],
     Text[Style[#, axOpt[a, "NumberSize"]], ax[{#, oy}] - {0, 0.35}] & /@ nums[[1]],
     Text[Style[#, axOpt[a, "NumberSize"]], ax[{ox, #}] - {0.35, 0}, {1, 0}] & /@ nums[[2]]}];
StageAxes[a_ ? axesQ]["Graph", f_, {xa_, xb_}, n_Integer : 200] := Line[StageAxes[a][Table[{x, f[x]}, {x, Subdivide[N[xa], xb, n]}]]];
StageAxes[a_ ? axesQ]["Graph", f_] := StageAxes[a]["Graph", f, a["X"][[;; 2]]];
StageAxes[a_ ? axesQ]["Area", f_, g_, {xa_, xb_}, n_Integer : 100] := With[{gg = If[NumericQ[g], g &, g]},
    Polygon[StageAxes[a][Join[Table[{x, f[x]}, {x, Subdivide[N[xa], xb, n]}], Table[{x, gg[x]}, {x, Subdivide[N[xb], xa, n]}]]]]];
StageAxes[a_ ? axesQ]["Riemann", f_, {xa_, xb_}, dx_] := Table[Polygon[StageAxes[a][{{x, 0}, {x + dx, 0}, {x + dx, f[x]}, {x, f[x]}}]], {x, xa, xb - dx / 2, dx}];
StageAxes[a_ ? axesQ]["VerticalLine", {x_, y_}] := Line[StageAxes[a][{{x, Clip[0, a["Y"][[;; 2]]]}, {x, y}}]];
StageAxes[a_ ? axesQ]["Labels", xl_ : "x", yl_ : "y"] := With[{ax = StageAxes[a], X = a["X"], Y = a["Y"]},
    {Text[xl, ax[{X[[2]], Clip[0, Y[[;; 2]]]}] + {0.1, 0.25}, {-1, -1}], Text[yl, ax[{Clip[0, X[[;; 2]]], Y[[2]]}] + {0.25, 0}, {-1, 0}]}];


(* ::Section:: *)
(*StageBrace*)

(* StageBrace[{a, b}] is a curly brace spanning a to b on their right-hand side (below, for a left-to-
   right span), "Depth" deep, its tip pointing away; StageBrace[{a, b}, "Tip"] is where a label goes. *)
Options[StageBrace] = {"Depth" -> 0.3, "Buffer" -> 0.15};
StageBrace[{a_, b_}, opts : OptionsPattern[]] := With[{u = Normalize[b - a], L = Norm[b - a], d = OptionValue["Depth"], buf = OptionValue["Buffer"]},
    With[{n = {u[[2]], -u[[1]]}, half = Table[{L s, -d braceProfile[s]}, {s, Subdivide[0., 0.5, 40]}]},
        Line[a + buf n + #[[1]] u - #[[2]] n & /@ Join[half, Reverse[{L - #[[1]], #[[2]]} & /@ Most[half]]]]]];
StageBrace[{a_, b_}, "Tip", opts : OptionsPattern[]] := With[{u = Normalize[b - a]}, (a + b) / 2 + (OptionValue[StageBrace, {opts}, "Buffer"] + OptionValue[StageBrace, {opts}, "Depth"] + 0.35) {u[[2]], -u[[1]]}];
(* half a brace, 0 at the end to 1 at the tip: a quick turn at the end, a long flat run, a sharp tip *)
braceProfile[s_] := Which[s < 0.06, 0.45 Sin[Pi / 2 s / 0.06], s < 0.44, 0.45, True, 0.45 + 0.55 Sin[Pi / 2 (s - 0.44) / 0.06]];
