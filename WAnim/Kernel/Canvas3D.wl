(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{CanvasCamera, CanvasCloud, CanvasCurve3D, CanvasSurface3D, CanvasSphere3D}]


(* ::Section:: *)
(*Camera*)

(* Three dimensions on the canvas: a camera projects points of a scene to canvas pixels, and the 3D tools
   below turn what it sees into ordinary canvas primitives -- disks, lines, polygons -- drawn far to near.
   Nothing is rasterized, so a scene costs no more than its primitives, and the camera can move every frame.

   CanvasCamera[opts] is a camera: it looks at "Target" from "Azimuth" (radians about the vertical z axis)
   and "Elevation" (above the horizon), "Distance" away (smaller is more perspective), and puts the target
   at canvas point "Center", "Scale" pixels to the unit. *)
Options[CanvasCamera] = {"Azimuth" -> 0.6, "Elevation" -> 0.35, "Distance" -> 8, "Target" -> {0, 0, 0}, "Center" -> {960, 540}, "Scale" -> 200};
CanvasCamera[opts : OptionsPattern[]] := Association[Options[CanvasCamera], {opts}];

(* points (n by 3) as canvas points (n by 2), their depth (larger is farther) and their perspective scale *)
cameraProject[cam_, pts_] := Module[{az = cam["Azimuth"], el = cam["Elevation"], d = cam["Distance"], q, x, y, z, k},
    q = (# - cam["Target"]) & /@ N[pts];
    (* turn the world about z so the camera looks along +y, then tip it down by the elevation *)
    x = Cos[az] q[[All, 1]] + Sin[az] q[[All, 2]]; y = -Sin[az] q[[All, 1]] + Cos[az] q[[All, 2]]; z = q[[All, 3]];
    {y, z} = {Cos[el] y + Sin[el] z, -Sin[el] y + Cos[el] z};
    k = d / Clip[d + y, {0.05 d, Infinity}];
    <|"XY" -> Transpose[{cam["Center"][[1]] + cam["Scale"] k x, cam["Center"][[2]] - cam["Scale"] k z}], "Depth" -> y, "K" -> k|>];

colourList[c_, n_] := If[ListQ[c] && Length[c] == n && ! ColorQ[c], c, ConstantArray[c, n]];


(* ::Section:: *)
(*Points, curves*)

(* CanvasCloud[camera, points, colour, r] is a cloud of glowing dots, r pixels at the target's distance,
   nearer ones larger; colour may be one colour or one per point.  "Glow" haloes each; "DepthFade" dims the
   far ones (0: none, 1: the farthest vanish). *)
Options[CanvasCloud] = {Opacity -> 1, "Glow" -> 0, "DepthFade" -> 0.5};
CanvasCloud[cam_Association, pts_List, c_, r_, opts : OptionsPattern[]] := Module[{p = cameraProject[cam, pts], cs = colourList[c, Length[pts]], order, dmin, dmax, f},
    order = Ordering[p["Depth"], All, Greater];
    {dmin, dmax} = MinMax[p["Depth"]]; f = OptionValue["DepthFade"];
    Table[With[{a = OptionValue[Opacity] (1 - f (p["Depth"][[i]] - dmin) / Max[10^-9, dmax - dmin])},
        CanvasDisk[p["XY"][[i]], r p["K"][[i]], cs[[i]], Opacity -> a, "Glow" -> OptionValue["Glow"] p["K"][[i]]]], {i, order}]];

(* CanvasCurve3D[camera, points, colour, thickness] is a path through space; colour may be one colour or one
   per point (each segment takes its first point's), thickness in pixels at the target, scaled by perspective *)
Options[CanvasCurve3D] = {Opacity -> 1, "Glow" -> 0};
CanvasCurve3D[cam_Association, pts_List, c_, w_, opts : OptionsPattern[]] := Module[{p = cameraProject[cam, pts], cs = colourList[c, Length[pts]]},
    If[! ListQ[c] || ColorQ[c],
        CanvasLine[p["XY"], c, "Thickness" -> w Mean[p["K"]], Opacity -> OptionValue[Opacity], "Glow" -> OptionValue["Glow"]],
        Table[CanvasLine[p["XY"][[i ;; i + 1]], cs[[i]], "Thickness" -> w p["K"][[i]], Opacity -> OptionValue[Opacity], "Glow" -> OptionValue["Glow"]], {i, Length[pts] - 1}]]];


(* ::Section:: *)
(*Surfaces, spheres*)

(* CanvasSurface3D[camera, grid, colours] is a surface from a grid of points (m by n by 3), shaded by a light
   from "Light" (a direction), its faces drawn far to near; colours is one colour, a grid of colours (m by n),
   or a function of the point.  "Mesh" -> colour draws the grid lines faintly. *)
Options[CanvasSurface3D] = {Opacity -> 1, "Light" -> {-0.4, -0.6, 0.7}, "Ambient" -> 0.35, "Mesh" -> None};
CanvasSurface3D[cam_Association, grid_List, c_, opts : OptionsPattern[]] := Module[{m = Length[grid], n = Length[First[grid]], flat = Flatten[N[grid], 1], p, xy, dep, faces, lt, amb, col},
    p = cameraProject[cam, flat]; xy = p["XY"]; dep = p["Depth"];
    lt = Normalize[OptionValue["Light"]]; amb = OptionValue["Ambient"];
    col[i_, j_] := Which[ColorQ[c], c, Head[c] === Function || Head[c] === Symbol, c[grid[[i, j]]], True, c[[i, j]]];
    faces = Flatten[Table[With[{ks = {(i - 1) n + j, (i - 1) n + j + 1, i n + j + 1, i n + j}},
        {Mean[dep[[ks]]], ks, i, j}], {i, m - 1}, {j, n - 1}], 1];
    faces = ReverseSortBy[faces, First];
    Table[With[{ks = f[[2]], q = flat[[f[[2]]]]}, With[{nrm = Normalize[Cross[q[[2]] - q[[1]], q[[4]] - q[[1]]]]},
        With[{shade = amb + (1 - amb) Abs[nrm . lt], base = col[f[[3]], f[[4]]]},
            CanvasPolygon[xy[[ks]], Blend[{Black, base}, shade], Opacity -> OptionValue[Opacity],
                "Edge" -> If[OptionValue["Mesh"] === None, Blend[{Black, base}, shade], OptionValue["Mesh"]]]]]], {f, faces}]];

(* CanvasSphere3D[camera, centre, r, colour] is a sphere: a softly lit disk with its meridians and parallels
   ("Wire" -> {meridians, parallels}), the near half of the wire bright, the far half faint *)
Options[CanvasSphere3D] = {Opacity -> 1, "Wire" -> {12, 7}, "WireColour" -> Automatic, "Fill" -> 0.18};
CanvasSphere3D[cam_Association, c3_, r_, c_, opts : OptionsPattern[]] := Module[{p = cameraProject[cam, {c3}], ctr, rad, wc, nm, np, circles},
    ctr = p["XY"][[1]]; rad = r cam["Scale"] p["K"][[1]];
    wc = Replace[OptionValue["WireColour"], Automatic -> c]; {nm, np} = OptionValue["Wire"];
    circles = Join[
        Table[Table[c3 + r {Cos[ph] Sin[th], Sin[ph] Sin[th], Cos[th]}, {th, 0, 2 Pi, Pi / 40}], {ph, 0, Pi - Pi / nm, Pi / nm}],
        Table[Table[c3 + r {Sin[th] Cos[ph], Sin[th] Sin[ph], Cos[th]}, {ph, 0, 2 Pi, Pi / 40}], {th, Pi / (np + 1), Pi - Pi / (np + 1), Pi / (np + 1)}]];
    {CanvasGradient[{ctr[[1]] - rad, ctr[[2]] - rad, 2 rad, 2 rad}, "Radial", c, {{0, 1.6 OptionValue["Fill"]}, {0.85, OptionValue["Fill"]}, {1, 0.6 OptionValue["Fill"]}}, "Steps" -> 16],
     CanvasDisk[ctr, rad, wc, "Stroke" -> 2, Opacity -> 0.5 OptionValue[Opacity]],
     Table[With[{q = cameraProject[cam, w]}, With[{front = Thread[q["Depth"] < p["Depth"][[1]]]},
        Table[CanvasLine[q["XY"][[i ;; i + 1]], wc, "Thickness" -> 1.4, Opacity -> OptionValue[Opacity] If[front[[i]], 0.55, 0.12]], {i, Length[w] - 1}]]], {w, circles}]}];
