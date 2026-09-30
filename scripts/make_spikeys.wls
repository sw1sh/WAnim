#!/usr/bin/env wolframscript
(* wolframscript -f scripts/make_spikeys.wls
   The Spikeys, as Mathematica drew them, for WAnim's Spikey: each version's Graphics3D from
   MathematicaSpikey.wl (~/src/wolfram/Spikeys), normalized -- centred, of radius 1, and turned so that a
   five-fold symmetry axis is vertical, so a spin repeats every 72 degrees -- and written to the paclet's
   "Spikeys" asset as <version>.wxf: <|"Graphics" -> primitives, "Options" -> options, "Period" -> degrees|>,
   their coordinates packed (see pack). *)

Get[FileNameJoin[{$HomeDirectory, "src", "wolfram", "Spikeys", "MathematicaSpikey.wl"}]];
out = FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "WAnim", "Assets", "Spikeys"}];
Quiet @ CreateDirectory[out];

(* every point drawn, the symmetry copies (GeometricTransformation by the group's rotations) included *)
points[g_Graphics3D] := pts[First[g]];
pts[l_List] := Join @@ (pts /@ l);
pts[GeometricTransformation[p_, t_]] := With[{q = pts[p]}, Join @@ (Function[f, f /@ q] /@ Replace[Flatten[{t}], m_ ? MatrixQ :> AffineTransform[m], {1}])];
pts[GraphicsComplex[c_, ___]] := N[c];
pts[(Polygon | Line | Point)[l_, ___]] := Cases[{N[l]}, {_ ? NumericQ, _ ? NumericQ, _ ? NumericQ}, Infinity];
pts[(Style | Annotation)[p_, ___]] := pts[p];
pts[_] := {};
rot[u_, a_] := RotationMatrix[a, u];
(* the spike tips: the farthest points, one per direction *)
tips[pts_] := With[{r = Quantile[Norm /@ pts, 0.999]}, DeleteDuplicates[Normalize /@ Select[pts, Norm[#] > 0.9 r &], Norm[#1 - #2] < 0.4 &]];
(* how far a 72 degree turn about u is from mapping the tips onto themselves *)
symmetryError[ts_, u_] := With[{nf = Nearest[ts]}, Mean[Norm[# - First[nf[#]]] & /@ (ts . Transpose[rot[u, 2 Pi / 5]])]];

(* coordinates as Integer16 in units of 1/10000 of the radius: a quarter of the size, lossless at any size drawn *)
pack[prims_] := prims /. {(h : Polygon | Line)[l_ ? (ArrayQ[#, _, NumericQ] &), rest___] :> h[NumericArray[Round[10000 l], "Integer16"], rest],
    (h : Polygon | Line)[l : {__List}, rest___] :> h[If[ArrayQ[#, _, NumericQ], NumericArray[Round[10000 #], "Integer16"], #] & /@ l, rest]};

Do[With[{g = N[MathematicaSpikey[v]]}, If[Head[g] === Graphics3D, Module[{pts, c, r, ts, cands, u, e, align, prims},
    pts = points[g];
    c = Mean[CoordinateBounds[pts] // Transpose];
    r = Max[Norm[# - c] & /@ pts];
    ts = tips[(# - c) & /@ pts];
    cands = Select[Join[ts, Normalize /@ Flatten[Table[ts[[i]] + ts[[j]], {i, Length[ts]}, {j, i + 1, Length[ts]}], 1], SpherePoints[400]], Norm[#] > 0.5 &];
    u = First[MinimalBy[cands, symmetryError[ts, #] &]];
    e = symmetryError[ts, u];
    align = RotationMatrix[{u, {0, 1, 0}}];
    prims = GeometricTransformation[GeometricTransformation[First[g], TranslationTransform[-c]], ScalingTransform[{1, 1, 1} / r]];
    prims = pack[Normal[GeometricTransformation[prims, align]] /. (VertexNormals -> _) :> Sequence[]];
    Export[FileNameJoin[{out, ToString[v] <> ".wxf"}],
        <|"Graphics" -> prims, "Options" -> Normal[KeyTake[Association[Options[g]], {Lighting}]], "Period" -> If[e < 0.06, 72, 360]|>, "WXF", PerformanceGoal -> "Size"];
    Print[v, ": ", Length[ts], " tips, symmetry error ", Round[e, 0.001], ", ", Round[FileByteCount[FileNameJoin[{out, ToString[v] <> ".wxf"}]] / 1024.], " KB"]]]],
  {v, MathematicaSpikey[]}];
