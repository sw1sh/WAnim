(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Terminal, NotebookSession, $NotebookEras}]


(* ::Section:: *)
(*Screens: a terminal and a notebook, each of its era*)

(* ::Subsection:: *)
(*Terminal*)

Options[Terminal] = Join[{FontFamily -> "VT323", FontSize -> 46, FontColor -> RGBColor["#6BFF8E"], "Screen" -> Automatic,
    "Bezel" -> RGBColor["#0B0C0B"], "Background" -> RGBColor["#081309"], "Glow" -> True, "Scanlines" -> True,
    "LineHeight" -> 52, "OutputGap" -> 10, "TypeTime" -> 0.4, "PrintInterval" -> 0.05, "PrintSize" -> 27,
    "CaptionSizes" -> {44, 58, 58}, "CaptionColor" -> RGBColor["#E6FFEC"], "CaptionTime" -> 0.35,
    "Enter" -> "PowerOn", "Exit" -> "PowerOff", "EnterTime" -> 0.18, "ExitTime" -> 0.28}, $LayerOptions];

(* Terminal[{line, ...}, {t0, t1}] is a green-phosphor terminal that powers on at t0 (a line opening to
   the full screen) and off at t1 (collapsing to a line, then a dot).  Each line is {t, content, kind}:
     "Input"    typed from t over "TypeTime"          (the default kind)
     "Output"   appears whole at t, slightly paler
     "Print"    a list of rows printed one per "PrintInterval" in a smaller size ("PrintSize")
     "Caption"  typed at the bottom of the screen in large type, captions stacking upward
   Glow and scanlines can be switched off; "Screen" -> {x, y, w, h} places the glass. *)
Terminal[lines_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Terminal]]},
    makeLayer["Terminal", {t0, t1}, Function[t, terminalDraw[lines, t, {t0, t1}, o]]]];

glowText[s_, {x_, y_}, f_, c_, glow_] := {If[glow, CanvasOpacity[0.18, Table[CanvasText[s, {x, y} + d, f, RGBColor["#39FF6A"]], {d, {{-2, 0}, {2, 0}, {0, -2}, {0, 2}}}]], {}],
    CanvasText[s, {x, y}, f, c]};

terminalDraw[lines_, t_, {t0_, t1_}, o_] := Module[{W = $CanvasSize[[1]], H = $CanvasSize[[2]], sx, sy, sw, sh, x0, y, f = layerFont[o, "Terminal"],
    ph = ov[o, FontColor], glow = TrueQ[ov[o, "Glow"]], on, off1, off2, caps, capY},
    {sx, sy, sw, sh} = Replace[ov[o, "Screen"], Automatic -> {150, 70, W - 300, H - 190}];
    x0 = sx + 90; y = sy + 90;
    on = If[ov[o, "Enter"] === "PowerOn", Easing["OutExpo"][localU[t, t0, t0 + ov[o, "EnterTime"]]], 1];
    {off1, off2} = If[ov[o, "Exit"] === "PowerOff", {Easing["InCubic"][localU[t, t1 - ov[o, "ExitTime"], t1 - 0.1]], Easing["InCubic"][localU[t, t1 - 0.1, t1]]}, {0, 0}];
    caps = Select[lines, Length[#] >= 3 && #[[3]] === "Caption" &];
    {CanvasRectangle[{0, 0, W, H}, ov[o, "Bezel"]],
     CanvasTransform[CanvasTranslate[{W / 2, sy + sh / 2}] . CanvasScale[{1 - 0.998 off2, Max[0.002, on (1 - 0.995 off1)]}] . CanvasTranslate[{-W / 2, -sy - sh / 2}], {
        CanvasRectangle[{sx, sy, sw, sh}, ov[o, "Background"], "Radius" -> 38],
        Table[If[t < l[[1]], Nothing, Switch[If[Length[l] >= 3, l[[3]], "Input"],
            "Input", {glowText[TypedText[l[[2]], localU[t, l[[1]], l[[1]] + ov[o, "TypeTime"]]], {x0, y}, f, ph, glow], y += ov[o, "LineHeight"]}[[1]],
            "Output", {glowText[l[[2]], {x0, y}, f, Blend[{ph, White}, 0.3], glow], y += ov[o, "LineHeight"] + ov[o, "OutputGap"]}[[1]],
            "Print", With[{ps = ov[o, "PrintSize"]}, {MapIndexed[If[t < l[[1]] + (#2[[1]] - 1) ov[o, "PrintInterval"], Nothing,
                CanvasText[#1, {x0 + 40, y + (#2[[1]] - 1) 0.78 ps}, CanvasFont[f["Family"], ps, 400], Blend[{ph, White}, 0.25]]] &, l[[2]]],
                y += Length[l[[2]]] 0.78 ps + 20}[[1]]],
            _, Nothing]], {l, lines}],
        (* captions sit at the bottom of the glass, the first smallest *)
        capY = sy + sh - 150;
        MapIndexed[With[{size = ov[o, "CaptionSizes"][[Min[#2[[1]], Length[ov[o, "CaptionSizes"]]]]]},
            {If[t < #1[[1]], {}, glowText[TypedText[#1[[2]], localU[t, #1[[1]], #1[[1]] + ov[o, "CaptionTime"]]], {x0, capY}, CanvasFont[f["Family"], size, 400], ov[o, "CaptionColor"], glow]],
             capY += If[#2[[1]] == 1, 52, 58]}[[1]]] &, caps],
        If[EvenQ[Floor[4 t]] && caps === {} || (caps =!= {} && t < caps[[1, 1]]), CanvasRectangle[{x0, y - 40, 26, 46}, ph], {}],
        If[TrueQ[ov[o, "Scanlines"]], Table[CanvasRectangle[{sx + 20, yy, sw - 40, 2}, Black, Opacity -> 0.16], {yy, sy + 8, sy + sh - 10, 4}], {}],
        CanvasRectangle[{sx, sy, sw, sh}, RGBColor["#9CFFB4"], "Radius" -> 38, Opacity -> 0.05 + 0.03 Mod[Floor[60 t] 0.618034, 1]]}],
     If[off2 > 0.5, CanvasDisk[{W / 2, sy + sh / 2}, 6, RGBColor["#DFFFE6"], Opacity -> 1 - localU[t, t1 - 0.05, t1]], {}]}];


(* ::Subsection:: *)
(*Notebook eras*)

(* An era is how a notebook looked: its window chrome (drawn in logical pixels), the rectangle the
   cells go in, the cell style, and the display ("Pixel" logical-pixel size, "Depth" as RasterScreen).
   Register more eras by adding to $NotebookEras. *)
$NotebookEras = <||>;

checkerImg[w_, h_] := checkerImg[w, h] = ColorConvert[Image[Table[Boole[EvenQ[i + j]], {i, h}, {j, w}], "Bit"], "RGB"];
checker[{x_, y_, w_, h_}] := CanvasImage[checkerImg[Round[w], Round[h]], {x, y, w, h}];
box[r_, fill_, stroke_ : None] := {CanvasRectangle[r, fill], If[stroke === None, {}, CanvasRectangle[r + {0.5, 0.5, -1, -1}, stroke, "Stroke" -> 1]]};
tri[{x_, y_}, s_, dir_] := CanvasPolygon[Switch[dir, "up", {{x, y - s}, {x + s, y + 0.6 s}, {x - s, y + 0.6 s}},
    "down", {{x, y + s}, {x + s, y - 0.6 s}, {x - s, y - 0.6 s}}, "left", {{x - s, y}, {x + 0.6 s, y - s}, {x + 0.6 s, y + s}},
    _, {{x + s, y}, {x - 0.6 s, y - s}, {x - 0.6 s, y + s}}], Black, "Stroke" -> 1];

(* Mathematica 1.0 on a Macintosh, 1988: System 6 chrome, the 1.0 menus, labels above cells in italics,
   bold Courier, thin black brackets; half resolution, one bit *)
mac1988Chrome[lw_, lh_, title_] := Module[{x = 14, wx = 12, wy = 30, ww = lw - 26, wh = lh - 40, sbx, sby, sbh, hby, tw, mf = CanvasFont["Arimo", 12, 700]},
    sbx = wx + ww - 16; sby = wy + 18; sbh = wh - 33; hby = wy + wh - 16; tw = CanvasTextWidth[title, mf];
    {checker[{0, 0, lw, lh}], box[{0, 0, lw, 19}, White], box[{0, 19, lw, 1}, Black],
     Table[{CanvasText[m, {x, 14}, mf, Black], x += CanvasTextWidth[m, mf] + 14}[[1]], {m, {"File", "Edit", "Cells", "Search", "Action", "Styles", "Windows"}}],
     box[{wx + 1, wy + 1, ww, wh}, Black], box[{wx, wy, ww, wh}, White, Black], Table[box[{wx + 2, yy, ww - 4, 1}, Black], {yy, wy + 4, wy + 14, 2}],
     box[{wx, wy + 18, ww, 1}, Black], box[{wx + 8, wy + 4, 11, 11}, White, Black], box[{wx + ww - 20, wy + 4, 11, 11}, White, Black],
     box[{wx + ww - 20, wy + 4, 7, 7}, White, Black], box[{wx + ww / 2 - tw / 2 - 7, wy + 2, tw + 14, 15}, White],
     CanvasText[title, {wx + ww / 2, wy + 14}, mf, Black, Alignment -> Center],
     box[{sbx, sby, 16, sbh}, White, Black], checker[{sbx + 1, sby + 16, 14, sbh - 32}], box[{sbx, sby, 16, 16}, White, Black], tri[{sbx + 8, sby + 8}, 4, "up"],
     box[{sbx, sby + sbh - 16, 16, 16}, White, Black], tri[{sbx + 8, sby + sbh - 8}, 4, "down"], box[{sbx, sby + sbh - 34, 16, 16}, White, Black],
     box[{wx, hby, ww - 15, 16}, White, Black], checker[{wx + 17, hby + 1, ww - 49, 14}], box[{wx, hby, 16, 16}, White, Black], tri[{wx + 8, hby + 8}, 4, "left"],
     box[{wx + ww - 32, hby, 16, 16}, White, Black], tri[{wx + ww - 24, hby + 8}, 4, "right"], box[{wx + 17, hby, 16, 16}, White, Black],
     box[{sbx, hby, 16, 16}, White, Black], box[{sbx + 3, hby + 3, 8, 8}, White, Black], box[{sbx + 6, hby + 6, 7, 7}, White, Black]}];
$NotebookEras["Mac1988"] = <|
    "Chrome" -> mac1988Chrome, "Content" -> Function[{lw, lh}, {13, 49, lw - 43, lh - 75}], "Pixel" -> 2, "Depth" -> "Bit",
    "Code" -> CanvasFont["Courier Prime", 13, 700], "Label" -> CanvasFont["Arimo", 10.5, 400, True], "LabelsAbove" -> True,
    "Left" -> 22, "Gap" -> 6, "Bracket" -> Black, "Page" -> White, "Ink" -> Black|>;


(* ::Subsection:: *)
(*NotebookSession*)

Options[NotebookSession] = Join[{"Era" -> "Mac1988", "Screen" -> {88, 176, 1100, 780}, "Title" -> "Untitled-1", "Evaluate" -> False,
    "TypeTime" -> 0.25, "OutputDelay" -> 0.3, "Enter" -> "Burst", "EnterTime" -> 0.22, "Pulse" -> None, "PushIn" -> 0.03, "Shadow" -> True}, $LayerOptions];

(* NotebookSession[{cell, ...}, {t0, t1}] is a notebook window of its era, typing and evaluating on the
   clock.  Cells are {t, "In", "code"} (typed from t over "TypeTime") or {t, "Out", output}, where output
   is text (wrapped like the era's output), an Image, or Graphics (rasterized; dithered on a 1-bit
   display).  With "Evaluate" -> True every input also gets its computed output, "OutputDelay" after it
   is typed.  In/Out numbers count up automatically.  "Enter" -> "Burst" grows the window out of the
   middle; "Pulse" -> track punches it on the track's onsets; "PushIn" is the slow zoom across the span. *)
NotebookSession[cells_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[NotebookSession]]},
    With[{era = $NotebookEras[ov[o, "Era"]], cs = sessionCells[cells, o]},
        makeLayer["NotebookSession", {t0, t1}, Function[t, sessionDraw[cs, era, t, {t0, t1}, o]]]]];

(* number the cells, add evaluated outputs, turn graphics into pictures once *)
sessionCells[cells_, o_] := Module[{n = 0, out = {}},
    Do[Switch[c[[2]],
        "In", n++; AppendTo[out, <|"kind" -> "In", "at" -> c[[1]], "n" -> n, "text" -> c[[3]], "type" -> ov[o, "TypeTime"]|>];
            If[TrueQ[ov[o, "Evaluate"]], AppendTo[out, outCell[c[[1]] + ov[o, "TypeTime"] + ov[o, "OutputDelay"], n, ToExpression[c[[3]]]]]],
        "Out", AppendTo[out, outCell[c[[1]], n, c[[3]]]]], {c, SortBy[cells, First]}];
    SortBy[out, #["at"] &]];
outCell[at_, n_, s_String] := <|"kind" -> "Out", "at" -> at, "n" -> n, "text" -> s|>;
outCell[at_, n_, img_Image] := <|"kind" -> "Pic", "at" -> at, "n" -> n, "image" -> img|>;
outCell[at_, n_, g : (_Graphics | _Graphics3D | _Legended)] := outCell[at, n, Rasterize[g, "Image", ImageSize -> 250, ImageResolution -> 72, Background -> White]];
outCell[at_, n_, e_] := outCell[at, n, ToString[e, OutputForm]];

sessionDraw[cs_, era_, t_, {t0_, t1_}, o_] := Module[{R = ov[o, "Screen"], s, c, pulse},
    pulse = If[ov[o, "Pulse"] === None, 0, TrackPulse[ov[o, "Pulse"], 12][t]];
    s = If[ov[o, "Enter"] === "Burst", 0.08 + 0.92 Easing["OutBack", 1.4][localU[t, t0, t0 + ov[o, "EnterTime"]]], 1] (1 + 0.006 pulse) (1 + ov[o, "PushIn"] Easing["InOutCubic"][localU[t, t0, t1]]);
    c = R[[1 ;; 2]] + R[[3 ;; 4]] / 2;
    CanvasTransform[CanvasScale[s, c], {
        If[TrueQ[ov[o, "Shadow"]], Table[CanvasRectangle[R + {-k, 18 - k / 2, 2 k, k}, Black, Opacity -> 0.04], {k, {2, 6, 12, 20, 30}}], {}],
        CanvasScreen[R, Function[{lw, lh}, {era["Chrome"][lw, lh, ov[o, "Title"]], notebookDraw[era["Content"][lw, lh], era, cs, Min[t, t1 - 10^-3]]}],
            "Pixel" -> era["Pixel"], "Depth" -> era["Depth"]],
        CanvasRectangle[R + {-0.5, -0.5, 1, 1}, Black, "Stroke" -> 1, Opacity -> 0.25]}]];

(* the cells, top to bottom, scrolled so the newest stays in view and gliding when one arrives *)
cellHeight[c_, era_, w_] := Switch[c["kind"], "Pic", ImageDimensions[c["image"]][[2]] + 6,
    _, 1.3 era["Code"]["Size"] Length[CanvasWrap[c["text"], era["Code"], w - era["Left"] - 30, "Break" -> "Code"]] + 4] + If[TrueQ[era["LabelsAbove"]], 1.5 era["Label"]["Size"], 0];
notebookDraw[{rx_, ry_, rw_, rh_}, era_, cs_, t_] := Module[{vis = Select[cs, t >= #["at"] &], hs, scrollFor, scroll, y, gap = era["Gap"]},
    hs = cellHeight[#, era, rw] & /@ vis;
    scrollFor[n_] := Max[0, Total[Take[hs, n]] + gap (n + 3) - rh];
    scroll = If[Length[vis] < 2, scrollFor[Length[vis]], scrollFor[Length[vis] - 1] +
        (scrollFor[Length[vis]] - scrollFor[Length[vis] - 1]) Easing["OutCubic"][localU[t, vis[[-1]]["at"], vis[[-1]]["at"] + 0.15]]];
    y = ry + gap - scroll;
    CanvasClip[{rx, ry, rw, rh}, {CanvasRectangle[{rx, ry, rw, rh}, era["Page"]],
        MapThread[{cellDraw[#1, {rx + era["Left"], y}, rw - era["Left"] - 30, #2, era, t], y += #2 + gap}[[1]] &, {vis, hs}]}]];
cellDraw[c_, {x0_, y_}, w_, h_, era_, t_] := Module[{f = era["Code"], ink = era["Ink"], lines, shown, yy = y},
    {If[TrueQ[era["LabelsAbove"]], {CanvasText[If[c["kind"] === "In", "In[" <> ToString[c["n"]] <> "]:=", "Out[" <> ToString[c["n"]] <> "]="],
        {x0 - 14, y + 1.1 era["Label"]["Size"]}, era["Label"], ink], yy += 1.5 era["Label"]["Size"]}[[1]], {}],
     CanvasLine[With[{hh = h Easing["OutExpo"][Clip[(t - c["at"]) / 0.12, {0, 1}]], bx = x0 + w + 16}, {{bx - 4, y - 2}, {bx, y - 2}, {bx, y - 2 + hh}, {bx - 4, y - 2 + hh}}], era["Bracket"]],
     Switch[c["kind"],
        "Pic", CanvasImage[If[era["Depth"] === "Bit", OrderedDither[c["image"], ImageDimensions[c["image"]]], c["image"]],
            Join[{x0, yy}, ImageDimensions[c["image"]]], Opacity -> Easing["OutCubic"][Clip[(t - c["at"]) / 0.12, {0, 1}]]],
        _, lines = CanvasWrap[c["text"], f, w, "Break" -> "Code"];
        shown = If[c["kind"] =!= "In", lines, Module[{n = Floor[Clip[(t - c["at"]) / c["type"], {0, 1}] StringLength[c["text"]]]},
            Flatten[Reap[Do[If[n > 0, Sow[StringTake[ln, Min[n, StringLength[ln]]]]; n -= StringLength[ln]], {ln, lines}]][[2]]]]];
        {MapIndexed[CanvasText[#1, {x0, yy + f["Size"] (1.05 + 1.3 (#2[[1]] - 1))}, f, ink] &, shown],
         If[c["kind"] === "In" && t - c["at"] < c["type"] + 0.25 && EvenQ[Floor[8 t]],
            CanvasRectangle[{x0 + CanvasTextWidth[Last[shown, ""], f] + 1, yy + 1.3 f["Size"] Max[0, Length[shown] - 1] + 2, 1.1, 1.15 f["Size"]}, ink], {}]}]}];
