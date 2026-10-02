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
   or a function of the point.  It is shaded smoothly, each corner lit by the normal of the surface there and
   the faces a hair larger than they are, so no seam of the grid shows; "Mesh" -> colour draws the grid
   lines faintly instead, "Smooth" -> False shades each face flat. *)
Options[CanvasSurface3D] = {Opacity -> 1, "Light" -> {-0.4, -0.6, 0.7}, "Ambient" -> 0.35, "Mesh" -> None, "Smooth" -> True};
CanvasSurface3D[cam_Association, grid_List, c_, opts : OptionsPattern[]] := Module[{m = Length[grid], n = Length[First[grid]], g = N[grid], flat, p, xy, dep, faces, lt, amb, col, nrm, vcol, shadeOf},
    flat = Flatten[g, 1];
    p = cameraProject[cam, flat]; xy = p["XY"]; dep = p["Depth"];
    lt = Normalize[OptionValue["Light"]]; amb = OptionValue["Ambient"];
    col[i_, j_] := Which[ColorQ[c], c, Head[c] === Function || Head[c] === Symbol, c[g[[i, j]]], True, c[[i, j]]];
    shadeOf[nv_, base_] := Blend[{Black, base}, amb + (1 - amb) Abs[nv . lt]];
    faces = ReverseSortBy[Flatten[Table[{Mean[dep[[{(i - 1) n + j, (i - 1) n + j + 1, i n + j + 1, i n + j}]]], i, j}, {i, m - 1}, {j, n - 1}], 1], First];
    If[TrueQ[OptionValue["Smooth"]] && OptionValue["Mesh"] === None,
        (* the normal at each point from its neighbours along the two grid directions *)
        nrm = Table[Normalize[Cross[g[[Min[i + 1, m], j]] - g[[Max[i - 1, 1], j]], g[[i, Min[j + 1, n]]] - g[[i, Max[j - 1, 1]]]]], {i, m}, {j, n}];
        vcol = Table[shadeOf[nrm[[i, j]], col[i, j]], {i, m}, {j, n}];
        Table[With[{i = f[[2]], j = f[[3]]}, With[{ks = {(i - 1) n + j, (i - 1) n + j + 1, i n + j + 1, i n + j}}, With[{q = xy[[ks]], ctr = Mean[xy[[ks]]]},
            CanvasPolygon[ctr + (# - ctr) (1 + 0.9 / Max[1., Norm[# - ctr]]) & /@ q, White, Opacity -> OptionValue[Opacity],
                "VertexColors" -> {vcol[[i, j]], vcol[[i, j + 1]], vcol[[i + 1, j + 1]], vcol[[i + 1, j]]}]]]], {f, faces}],
        Table[With[{i = f[[2]], j = f[[3]]}, With[{ks = {(i - 1) n + j, (i - 1) n + j + 1, i n + j + 1, i n + j}, q = flat[[{(i - 1) n + j, (i - 1) n + j + 1, i n + j + 1, i n + j}]]},
            With[{sh = shadeOf[Normalize[Cross[q[[2]] - q[[1]], q[[4]] - q[[1]]]], col[i, j]]},
                CanvasPolygon[xy[[ks]], sh, Opacity -> OptionValue[Opacity], "Edge" -> Replace[OptionValue["Mesh"], None -> sh]]]]], {f, faces}]]];

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
