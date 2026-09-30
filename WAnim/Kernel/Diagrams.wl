(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{TreeDiagram, TileGrid, WordScroll}]


(* ::Section:: *)
(*TreeDiagram*)

Options[TreeDiagram] = elementOptions[{Position -> {1330, 250}, "Width" -> 500, "LevelHeight" -> 130, "Interval" -> {1/4, 1/20},
    FontFamily -> "Source Code Pro", FontSize -> 38, FontWeight -> 400, FontColor -> RGBColor["#0E0F11"], "HeadColor" -> RGBColor["#DD1100"],
    "EnterTime" -> 0.15, "ExitTime" -> 0.15}];

(* TreeDiagram[expr, {t0, t1}] grows the expression's tree from the top: heads (in "HeadColor") above
   their arguments, one level per "Interval" (or {level, node}: nodes of a level a node interval
   apart), each node popping in as its edge is drawn down to it.  Position is the root; the leaves spread over "Width".  Hold the expression to keep it
   unevaluated: TreeDiagram[Hold[{x -> 1, f[y]}], {t0, t1}]. *)
TreeDiagram[expr_, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, TreeDiagram]},
    With[{nodes = treeLayout[Replace[expr, {h_Hold :> nested @@ h, e_ :> nested[e]}], o, t0]},
        makeElement["TreeDiagram", {t0, t1}, Function[t, treeDraw[nodes, t, {t0, t1}, drawOptions[{opts}, TreeDiagram, t]]]]]];

(* an unevaluated expression as {"head", {child, ...}} with leaves {"atom", None} *)
SetAttributes[nested, HoldAll];
nested[h_[args___]] := {ToString[Unevaluated[h], InputForm], List @@ (nested /@ Hold[args])};
nested[a_] := {ToString[Unevaluated[a], InputForm], None};

(* nodes <|"Text", "Head", "Point", "Parent", "At"|>: a leaf takes the next slot across "Width", a
   parent sits over the middle of its children; nodes arrive level by level *)
treeLayout[tree_, o_, t0_] := Module[{nodes = {}, slot = 0, nLeaves, perLevel = <||>, walk, p = layerPoint[ov[o, Position]], w = ov[o, "Width"]},
    nLeaves = Max[1, Count[tree, {_String, None}, Infinity] + Boole[MatchQ[tree, {_, None}]]];
    walk[{s_, kids_}, depth_, parent_] := Module[{id = Length[nodes] + 1, k = Lookup[perLevel, depth, 0], ids, x},
        perLevel[depth] = k + 1;
        AppendTo[nodes, <|"Text" -> s, "Head" -> kids =!= None, "Parent" -> parent, "At" -> t0 + depth First[Flatten[{ov[o, "Interval"]}]] + k Last[Flatten[{ov[o, "Interval"], 0}]]|>];
        ids = If[kids === None, {}, walk[#, depth + 1, id] & /@ kids];
        x = If[ids === {}, p[[1]] - w / 2 + w (slot++ + 1/2) / nLeaves, Mean[nodes[[ids, "Point", 1]]]];
        nodes[[id, "Point"]] = {x, p[[2]] + depth ov[o, "LevelHeight"]};
        id];
    walk[tree, 0, None];
    nodes];

treeDraw[nodes_, t_, {t0_, t1_}, o_] := Module[{f = layerFont[o, "Mono"], hf, env = envelope[t, {t0, t1}, Join[{"Enter" -> "Cut"}, o]], et = ov[o, "EnterTime"]},
    hf = <|f, "Weight" -> 600, "Size" -> 1.05 f["Size"]|>;
    CanvasOpacity[env["Alpha"], Table[With[{u = Easing["OutBack", 2][localU[t, n["At"], n["At"] + et]], e = Easing["OutCubic"][localU[t, n["At"] - 0.05, n["At"] + 0.1]]},
        If[t < n["At"] - 0.05, {}, {
            If[n["Parent"] === None, {}, With[{a = nodes[[n["Parent"], "Point"]] + {0, 18}, b = n["Point"] - {0, 34}},
                CanvasLine[{a, a + e (b - a)}, ov[o, FontColor], "Thickness" -> 2, Opacity -> 0.5]]],
            If[u <= 0, {}, CanvasTransform[CanvasTranslate[n["Point"]] . CanvasScale[u],
                CanvasText[n["Text"], {0, 0}, If[n["Head"], hf, f], If[n["Head"], ov[o, "HeadColor"], ov[o, FontColor]], Alignment -> Center]]]}]],
        {n, nodes}]]];


(* ::Section:: *)
(*TileGrid*)

Options[TileGrid] = elementOptions[{Position -> {96, 250}, "Columns" -> 4, "TileSize" -> {400, 330}, "Gap" -> {36, 60}, "Interval" -> 1/4, "Pulse" -> None,
    "Frames" -> Automatic, "Period" -> 2, FontFamily -> "Source Code Pro", FontSize -> 24, FontColor -> RGBColor["#0E0F11"], "NoteColor" -> RGBColor["#DD1100"],
    "Enter" -> "Pop", "EnterTime" -> 0.12, "Exit" -> "Fade"}];

(* TileGrid[{{label, content, note}, ...}, {t0, t1}] deals out white cards, one per "Interval", in rows
   of "Columns" from Position (the top-left corner), a label under each and a note at its right.
   content is anything the front end can show (a plot, an image) or a function u |-> expr, which
   plays as a loop over "Period" -- a surface turning.  "Pulse" -> track punches the newest card on
   the track's onsets. *)
TileGrid[tiles_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, TileGrid]},
    With[{pics = tilePictures[#[[2]], o] & /@ tiles},
        makeElement["TileGrid", {t0, t1}, Function[t, tileGridDraw[tiles, pics, t, {t0, t1}, drawOptions[{opts}, TileGrid, t]]]]]];

(* each tile's content as a list of frames, rasterized once at the card's size *)
tilePictures[f_Function, o_] := Table[tilePicture[f[u], o], {u, Most[Subdivide[0., 1., Replace[ov[o, "Frames"], Automatic :> Ceiling[40 ov[o, "Period"]]]]]}];
tilePictures[e_, o_] := {tilePicture[e, o]};
tilePicture[img_Image, o_] := img;
tilePicture[e_, o_] := Rasterize[Show[e, ImageSize -> ov[o, "TileSize"] - 20], "Image", ImageResolution -> 72, Background -> White] /; MatchQ[e, _Graphics | _Graphics3D];
tilePicture[e_, o_] := Rasterize[e, "Image", ImageResolution -> 72, Background -> White];

tileGridDraw[tiles_, pics_, t_, {t0_, t1_}, o_] := Module[{p = layerPoint[ov[o, Position]], ts = ov[o, "TileSize"], gap = ov[o, "Gap"], cols = ov[o, "Columns"],
    f = layerFont[o, "Mono"], env = envelope[t, {t0, t1}, Join[{"Enter" -> "Cut"}, o]], newest = Floor[(t - t0) / ov[o, "Interval"]]},
    CanvasOpacity[env["Alpha"], Table[With[{at = t0 + (i - 1) ov[o, "Interval"], xy = p + {Mod[i - 1, cols] (ts[[1]] + gap[[1]]), Quotient[i - 1, cols] (ts[[2]] + gap[[2]])}},
        With[{u = If[ov[o, "Enter"] === "Pop", Easing["OutBack", 1.6][localU[t, at, at + ov[o, "EnterTime"]]], If[t >= at, 1, 0]],
              k = If[i - 1 == newest && ov[o, "Pulse"] =!= None, 1 + 0.03 TrackPulse[ov[o, "Pulse"], 20][t], 1],
              fr = pics[[i]][[1 + Mod[Floor[(t - at) / ov[o, "Period"] Length[pics[[i]]]], Length[pics[[i]]]]]], c = xy + ts / 2},
            If[u <= 0, {}, {
                CanvasTransform[CanvasScale[u k, c], {
                    Table[CanvasRectangle[Join[xy, ts] + {-s, 8 - s / 2, 2 s, s}, Black, "Radius" -> 8 + s, Opacity -> 0.035], {s, {3, 8, 14, 22}}],
                    CanvasRectangle[Join[xy, ts], White, "Radius" -> 8],
                    CanvasImage[fr, Join[xy + 10, ts - 20], "Fit" -> "Contain"]}],
                CanvasText[tiles[[i, 1]], xy + {4, ts[[2]] + 34}, <|f, "Weight" -> 600|>, ov[o, FontColor], Opacity -> Clip[u, {0, 1}]],
                If[Length[tiles[[i]]] > 2, CanvasText[tiles[[i, 3]], xy + {ts[[1]] - 4, ts[[2]] + 34}, <|f, "Size" -> 0.83 f["Size"]|>, ov[o, "NoteColor"],
                    Alignment -> Right, Opacity -> Clip[u, {0, 1}]], {}]}]]],
        {i, Length[tiles]}]]];


(* ::Section:: *)
(*WordScroll*)

Options[WordScroll] = elementOptions[{"Columns" -> {60, 400, 740, 1080, 1420, 1760}, "Speed" -> 260, "LineHeight" -> 30, "Start" -> 1150,
    FontFamily -> "Source Code Pro", FontSize -> 17, FontWeight -> 400, FontColor -> RGBColor["#0E0F11"], Opacity -> {0.1, 0.16}}];

(* WordScroll[{word, ...}, {t0, t1}] rolls words up the frame in columns like credits, faintly: a
   backdrop of a whole family of names.  "Speed" is pixels per unit; each word's faintness is fixed
   by its name within the Opacity range. *)
WordScroll[words_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, WordScroll]},
    makeElement["WordScroll", {t0, t1}, Function[t, wordScrollDraw[words, t, {t0, t1}, drawOptions[{opts}, WordScroll, t]]]]];
wordScrollDraw[words_, t_, {t0_, t1_}, o_] := Module[{cols = ov[o, "Columns"], f = layerFont[o, "Mono"], scroll = (t - t0) ov[o, "Speed"], env = envelope[t, {t0, t1}, o], op = ov[o, Opacity]},
    CanvasOpacity[env["Alpha"], MapIndexed[With[{y = ov[o, "Start"] + Quotient[#2[[1]] - 1, Length[cols]] ov[o, "LineHeight"] - scroll},
        If[-20 < y < $canvasSize[[2]] + 20, CanvasText[#1, {cols[[Mod[#2[[1]] - 1, Length[cols]] + 1]], y}, f, ov[o, FontColor],
            Opacity -> op[[1]] + (op[[2]] - op[[1]]) Mod[Hash[#1], 1000] / 1000.], {}]] &, words]]];
