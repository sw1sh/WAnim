(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Terminal, NotebookSession, NotebookEra}]


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
(*NotebookSession*)

Options[NotebookSession] = Join[{"Era" -> "Mac1988", "Screen" -> {88, 176, 1100, 780}, "Title" -> "Untitled-1", "Evaluate" -> False,
    "TypeTime" -> 0.25, "OutputDelay" -> 0.3, "Enter" -> "Burst", "EnterTime" -> 0.22, "Pulse" -> None, "PushIn" -> 0.03, "Shadow" -> True, "Frames" -> 24, "From" -> None, "Dim" -> None, "Extras" -> Automatic}, $LayerOptions];

(* NotebookSession[{cell, ...}, {t0, t1}] is a notebook window of its era, typing and evaluating on the
   clock.  Cells:
     {t, "In", "code"}            typed from t over "TypeTime" (or {t, "In", "code", typeTime})
     {t, "Out", output}           text is set in the era's output font; an Image as is; any other
                                  expression is shown as the front end displays it (graphics always;
                                  other expressions as OutputForm text in eras before 2007)
     {t, "Out", u |-> expr, dur}  an animated output: expr at u from 0 to 1 over dur (a moving
                                  slider, a rotating plot), rendered once as "Frames" pictures
     {t, "Title", "text"}, {t, "Text", "text"}   the notebook's own prose
   With "Evaluate" -> True every input also gets its computed output, "OutputDelay" after it is typed.
   In/Out numbers count up automatically.  "Enter" -> "Burst" grows the window out of the middle;
   "Pulse" -> track punches it on the track's onsets; "PushIn" is the slow zoom across the span. *)
NotebookSession[cells_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[NotebookSession]]},
    With[{era = NotebookEra[ov[o, "Era"]]}, With[{cs = sessionCells[cells, era, o]},
        With[{screen = Function[t, sessionScreen[cs, era, Min[t, t1 - 10^-3], o]]},
            makeLayer["NotebookSession", {t0, t1}, Function[t, sessionDraw[screen, t, {t0, t1}, o]], <|"Screen" -> screen|>]]]]];

(* number the cells, add evaluated outputs, turn expressions into pictures once *)
sessionCells[cells_, era_, o_] := Module[{n = 0, out = {}},
    Do[Switch[c[[2]],
        "In", n++; With[{tt = If[Length[c] > 3, c[[4]], ov[o, "TypeTime"]]},
            AppendTo[out, <|"kind" -> "In", "at" -> c[[1]], "n" -> n, "text" -> c[[3]], "type" -> tt|>];
            If[TrueQ[ov[o, "Evaluate"]], AppendTo[out, outCell[c[[1]] + tt + ov[o, "OutputDelay"], n, ToExpression[c[[3]]], era, o]]]],
        "Out", AppendTo[out, If[Length[c] > 3, animCell[c[[1]], n, c[[3]], c[[4]], era, o], outCell[c[[1]], n, c[[3]], era, o]]],
        "Title" | "Text", AppendTo[out, <|"kind" -> c[[2]], "at" -> c[[1]], "n" -> n, "text" -> c[[3]]|>]], {c, SortBy[cells, First]}];
    SortBy[out, #["at"] &]];
richEraQ[era_] := era["Depth"] === "Full";
outCell[at_, n_, s_String, _, _] := <|"kind" -> "Out", "at" -> at, "n" -> n, "text" -> s|>;
outCell[at_, n_, img_Image, _, _] := <|"kind" -> "Pic", "at" -> at, "n" -> n, "image" -> img, "size" -> ImageDimensions[img]|>;
outCell[at_, n_, e_, era_, o_] /; richEraQ[era] || MatchQ[e, _Graphics | _Graphics3D | _Legended | _Image3D | _Graph] :=
    Join[outCell[at, n, "", era, o], <|"kind" -> "Pic"|>, displayed[e, era]];
outCell[at_, n_, e_, era_, o_] := outCell[at, n, ToString[e, OutputForm], era, o];
animCell[at_, n_, f_, dur_, era_, o_] := With[{fr = displayed[f[#], era] & /@ Subdivide[0., 1., ov[o, "Frames"] - 1]},
    <|"kind" -> "Pic", "at" -> at, "n" -> n, "frames" -> fr[[All, "image"]], "size" -> fr[[1, "size"]], "dur" -> dur|>];
(* an expression as the front end shows it, in the era's light or dark mode, at twice its logical size for a sharp screen *)
displayed[e_, era_] := With[{img = Rasterize[Style[e, LightDark -> era["LightDark"]], "Image", ImageResolution -> 144, Background -> era["Page"]]},
    <|"image" -> img, "size" -> ImageDimensions[img] / 2|>];

(* the window: burst or wipe in, pulse, push in, dim, fly away *)
sessionDraw[screen_, t_, {t0_, t1_}, o_] := Module[{R = ov[o, "Screen"], s, c, pulse, dim = 0, a = 1, et = ov[o, "EnterTime"], xt = ov[o, "ExitTime"], prev = ov[o, "From"], wipe},
    pulse = If[ov[o, "Pulse"] === None, 0, TrackPulse[ov[o, "Pulse"], 24][t]];
    s = If[ov[o, "Enter"] === "Burst", 0.08 + 0.92 Easing["OutBack", 1.4][localU[t, t0, t0 + et]], 1] (1 + 0.006 pulse) (1 + ov[o, "PushIn"] Easing["InOutCubic"][localU[t, t0, t1]]);
    If[ListQ[ov[o, "Dim"]], With[{u = Easing["InOutCubic"][localU[t, Sequence @@ ov[o, "Dim"]]]}, s *= 1 - 0.14 u; dim = 0.65 u]];
    If[ov[o, "Exit"] === "FlyAway", With[{u = Easing["InExpo"][localU[t, t1 - xt, t1]]}, s *= 1 + 0.9 u; a = 1 - u]];
    wipe = If[ov[o, "Enter"] === "Wipe" && Head[prev] === TimelineLayer, localU[t, t0, t0 + et], 1];
    c = R[[1 ;; 2]] + R[[3 ;; 4]] / 2;
    CanvasOpacity[a, CanvasTransform[CanvasScale[s, c], {
        If[TrueQ[ov[o, "Shadow"]], Table[CanvasRectangle[R + {-k, 18 - k / 2, 2 k, k}, Black, Opacity -> 0.04], {k, {2, 6, 12, 20, 30}}], {}],
        If[wipe < 1, With[{y = R[[2]] + R[[4]] Easing["OutCubic"][wipe]}, {
            First[prev]["Screen"][t0 - 10^-3],
            CanvasClip[{R[[1]], R[[2]], R[[3]], y - R[[2]]}, screen[t]],
            CanvasRectangle[{R[[1]], y - 3, R[[3]], 6}, White, Opacity -> 0.9 (1 - wipe)]}],
            screen[t]],
        If[dim > 0, CanvasRectangle[R, Black, Opacity -> dim], {}],
        CanvasRectangle[R + {-0.5, -0.5, 1, 1}, Black, "Stroke" -> 1, Opacity -> 0.25]}]]];
(* the screen alone: chrome, cells and the era's extras (the 3.0 BasicInput palette) *)
sessionScreen[cs_, era_, t_, o_] := CanvasScreen[ov[o, "Screen"], Function[{lw, lh}, {era["Chrome"][lw, lh, ov[o, "Title"]], notebookDraw[era["Content"][lw, lh], era, cs, t],
    If[ov[o, "Extras"] === Automatic && era["Extras"] =!= None, era["Extras"][lw, lh, t], {}]}], "Pixel" -> era["Pixel"], "Depth" -> era["Depth"]];

(* the cells, top to bottom, scrolled so the newest stays in view and gliding when one arrives *)
cellFont[c_, era_] := Switch[c["kind"], "In", era["Input"], "Out", era["Output"], "Title", era["Title"], _, era["Text"]];
labelH[c_, era_] := If[TrueQ[era["LabelsAbove"]] && MatchQ[c["kind"], "In" | "Out" | "Pic"], 1.5 era["Label"]["Size"], 0];
cellHeight[c_, era_, w_] := labelH[c, era] + Switch[c["kind"], "Pic", c["size"][[2]] + 6,
    _, With[{f = cellFont[c, era]}, 1.3 f["Size"] Length[CanvasWrap[c["text"], f, w, "Break" -> If[MatchQ[c["kind"], "In" | "Out"], "Code", "Words"]]] + 4]];
notebookDraw[{rx_, ry_, rw_, rh_}, era_, cs_, t_] := Module[{vis = Select[cs, t >= #["at"] &], w = rw - era["Left"] - 30, hs, scrollFor, scroll, y, gap = era["Gap"]},
    hs = cellHeight[#, era, w] & /@ vis;
    scrollFor[n_] := Max[0, Total[Take[hs, n]] + gap (n + 3) - rh];
    scroll = If[Length[vis] < 2, scrollFor[Length[vis]], scrollFor[Length[vis] - 1] +
        (scrollFor[Length[vis]] - scrollFor[Length[vis] - 1]) Easing["OutCubic"][localU[t, vis[[-1]]["at"], vis[[-1]]["at"] + 0.15]]];
    y = ry + gap - scroll;
    CanvasClip[{rx, ry, rw, rh}, {CanvasRectangle[{rx, ry, rw, rh}, era["Page"]],
        MapThread[{cellDraw[#1, {rx + era["Left"], y}, w, #2, era, t, ry], y += #2 + gap}[[1]] &, {vis, hs}]}]];

(* the cell bracket: a thin square hook in the classic eras, a lighter one with a small foot since 6.0 *)
bracket[{bx_, y_}, hh_, era_] := CanvasLine[If[era["BracketKind"] === "Modern", {{bx - 3, y}, {bx, y}, {bx, y + hh}, {bx - 3, y + hh}},
    {{bx - 4, y}, {bx, y}, {bx, y + hh}, {bx - 4, y + hh}}], era["Bracket"], "Thickness" -> era["BracketWidth"]];
cellLabel[c_, era_] := Switch[c["kind"], "In", "In[" <> ToString[c["n"]] <> "]:=", "Out" | "Pic", "Out[" <> ToString[c["n"]] <> "]=", _, None];

(* top: the page top; text is not clipped by the page's inset, so lines scrolled above it are dropped *)
cellDraw[c_, {x0_, y_}, w_, h_, era_, t_, top_] := Module[{f = cellFont[c, era], ink = era["Ink"], lab = cellLabel[c, era], lines, shown, yy = y + labelH[c, era]},
    {If[lab === None || y < top, {}, If[TrueQ[era["LabelsAbove"]], CanvasText[lab, {x0 - 14, y + 1.1 era["Label"]["Size"]}, era["Label"], era["LabelColor"]],
        CanvasText[lab, {x0 - 8, yy + If[c["kind"] === "Pic", era["Label"]["Size"] + 4, 1.05 f["Size"]]}, era["Label"], era["LabelColor"], Alignment -> Right]]],
     bracket[{x0 + w + 16, y - 2}, h Easing["OutExpo"][Clip[(t - c["at"]) / 0.12, {0, 1}]], era],
     Switch[c["kind"],
        "Pic", With[{img = If[KeyExistsQ[c, "frames"], c["frames"][[1 + Floor[Clip[(t - c["at"]) / c["dur"], {0, 1}] (Length[c["frames"]] - 1)]]], c["image"]]},
            CanvasImage[If[era["Depth"] === "Bit", OrderedDither[img, Round[c["size"]]], img], Join[{x0, yy}, c["size"]], Opacity -> Easing["OutCubic"][Clip[(t - c["at"]) / 0.12, {0, 1}]]]],
        _, lines = CanvasWrap[c["text"], f, w, "Break" -> If[MatchQ[c["kind"], "In" | "Out"], "Code", "Words"]];
        shown = If[c["kind"] =!= "In", lines, Module[{n = Floor[Clip[(t - c["at"]) / c["type"], {0, 1}] StringLength[c["text"]]]},
            Flatten[Reap[Do[If[n > 0, Sow[StringTake[ln, Min[n, StringLength[ln]]]]; n -= StringLength[ln]], {ln, lines}]][[2]]]]];
        {MapIndexed[With[{p = {x0, yy + f["Size"] (1.05 + 1.3 (#2[[1]] - 1))}}, If[p[[2]] - f["Size"] < top, {}, codeLine[#1, p, f, c["kind"], era]]] &, shown],
         If[c["kind"] === "In" && t - c["at"] < c["type"] + 0.25 && EvenQ[Floor[8 t]],
            CanvasRectangle[{x0 + CanvasTextWidth[Last[shown, ""], f] + 1, yy + 1.3 f["Size"] Max[0, Length[shown] - 1] + 2, 1.1, 1.15 f["Size"]}, ink], {}]}]}];

(* one line of a cell; since 6.0 input is syntax-coloured: strings grey, symbols the system does not
   know (the user's own) blue *)
codeLine[s_, p_, f_, kind_, era_] := Which[
    kind === "Title", CanvasText[s, p, f, Replace[era["TitleColor"], Automatic -> era["Ink"]]],
    kind === "Out", CanvasText[s, p, f, Replace[era["OutputInk"], Automatic -> era["Ink"]]],
    kind =!= "In" || era["Syntax"] === None, CanvasText[s, p, f, era["Ink"]],
    True, Module[{x = p[[1]]}, Map[With[{c = tokenColor[#, era]}, {CanvasText[#, {x, p[[2]]}, f, c], x += CanvasTextWidth[#, f]}[[1]]] &,
        StringSplit[s, tok : (("\"" ~~ Shortest[___] ~~ ("\"" | EndOfString)) | (("$" | LetterCharacter) ~~ (WordCharacter | "$") ...)) :> tok]]]];
tokenColor[tok_, era_] := Which[StringStartsQ[tok, "\""], era["Syntax"]["String"],
    StringMatchQ[tok, ("$" | LetterCharacter) ~~ ___] && Names["System`" <> tok] === {}, era["Syntax"]["User"], True, era["Ink"]];
