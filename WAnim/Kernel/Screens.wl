(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{TerminalSession, NotebookSession, NotebookEra}]


(* ::Section:: *)
(*Screens: a terminal and a notebook, each of its era*)

(* ::Subsection:: *)
(*TerminalSession*)

Options[TerminalSession] = elementOptions[{FontFamily -> "VT323", FontSize -> 46, FontColor -> RGBColor["#6BFF8E"], "Screen" -> Automatic,
    "Bezel" -> RGBColor["#0B0C0B"], Background -> RGBColor["#081309"], "Glow" -> True, "Scanlines" -> True,
    "LineHeight" -> 52, "OutputGap" -> 10, "TypeTime" -> 0.4, "Interval" -> 0.05, "PrintSize" -> 27,
    "CaptionSizes" -> {44, 58, 58}, "CaptionColor" -> RGBColor["#E6FFEC"], "CaptionTime" -> 0.35,
    "Enter" -> "PowerOn", "Exit" -> "PowerOff", "EnterTime" -> 0.18, "ExitTime" -> 0.28}];

(* TerminalSession[{line, ...}, {t0, t1}] is a green-phosphor terminal that powers on at t0 (a line opening to
   the full screen) and off at t1 (collapsing to a line, then a dot).  Each line is {t, content, kind}:
     "Input"    typed from t over "TypeTime"          (the default kind)
     "Output"   appears whole at t, slightly paler
     "Print"    a list of rows printed one per "Interval" in a smaller size ("PrintSize")
     "Caption"  typed at the bottom of the screen in large type, captions stacking upward
   Glow and scanlines can be switched off; "Screen" -> {x, y, w, h} places the glass. *)
TerminalSession[lines_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, TerminalSession]},
    makeElement["TerminalSession", {t0, t1}, Function[t, terminalDraw[lines, t, {t0, t1}, drawOptions[{opts}, TerminalSession, t]]],
        <|"Foley" -> Join @@ Cases[lines, {at_, s_String, kind : ("Input" | "Caption") : "Input"} :>
            keystrokes[at, ov[o, If[kind === "Input", "TypeTime", "CaptionTime"]], StringLength[s]]]|>]];

glowText[s_, {x_, y_}, f_, c_, glow_] := {If[glow, CanvasOpacity[0.18, Table[CanvasText[s, {x, y} + d, f, RGBColor["#39FF6A"]], {d, {{-2, 0}, {2, 0}, {0, -2}, {0, 2}}}]], {}],
    CanvasText[s, {x, y}, f, c]};

terminalDraw[lines_, t_, {t0_, t1_}, o_] := Module[{W = $canvasSize[[1]], H = $canvasSize[[2]], sx, sy, sw, sh, x0, y, f = layerFont[o, "Terminal"],
    ph = ov[o, FontColor], glow = TrueQ[ov[o, "Glow"]], on, off1, off2, caps, capY},
    {sx, sy, sw, sh} = Replace[ov[o, "Screen"], Automatic -> {150, 70, W - 300, H - 190}];
    x0 = sx + 90; y = sy + 90;
    on = If[ov[o, "Enter"] === "PowerOn", Easing["OutExpo"][localU[t, t0, t0 + ov[o, "EnterTime"]]], 1];
    {off1, off2} = If[ov[o, "Exit"] === "PowerOff", {Easing["InCubic"][localU[t, t1 - ov[o, "ExitTime"], t1 - 0.1]], Easing["InCubic"][localU[t, t1 - 0.1, t1]]}, {0, 0}];
    caps = Select[lines, Length[#] >= 3 && #[[3]] === "Caption" &];
    {CanvasRectangle[{0, 0, W, H}, ov[o, "Bezel"]],
     CanvasTransform[CanvasTranslate[{W / 2, sy + sh / 2}] . CanvasScale[{1 - 0.998 off2, Max[0.002, on * (1 - 0.995 off1)]}] . CanvasTranslate[{-W / 2, -sy - sh / 2}], {
        CanvasRectangle[{sx, sy, sw, sh}, ov[o, Background], "Radius" -> 38],
        Table[If[t < l[[1]], Nothing, Switch[If[Length[l] >= 3, l[[3]], "Input"],
            "Input", {glowText[TypedText[l[[2]], localU[t, l[[1]], l[[1]] + ov[o, "TypeTime"]]], {x0, y}, f, ph, glow], y += ov[o, "LineHeight"]}[[1]],
            "Output", {glowText[l[[2]], {x0, y}, f, Blend[{ph, White}, 0.3], glow], y += ov[o, "LineHeight"] + ov[o, "OutputGap"]}[[1]],
            "Print", With[{ps = ov[o, "PrintSize"]}, {MapIndexed[If[t < l[[1]] + (#2[[1]] - 1) ov[o, "Interval"], Nothing,
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

Options[NotebookSession] = elementOptions[{"Era" -> "Mac1988", "Screen" -> {88, 176, 1100, 780}, "Title" -> "Untitled-1", "Evaluate" -> False,
    "TypeTime" -> 0.25, "OutputDelay" -> 0.3, "Enter" -> "Burst", "EnterTime" -> 0.22, "Pulse" -> None, "PushIn" -> 0.03, "Shadow" -> True, "Frames" -> Automatic, "From" -> None, "Dim" -> None, "Hide" -> {}, "GraphicsSize" -> Automatic, "Extras" -> Automatic, "ChatBar" -> None}];

(* NotebookSession[{cell, ...}, {t0, t1}] is a notebook window of its era, typing and evaluating on the
   clock.  Cells:
     {t, "In", "code"}            typed from t over "TypeTime" (or {t, "In", "code", typeTime})
     {t, "In", HoldForm[expr]}    a typeset input (2D math), shown whole
     {t, "Out", output}           text is set in the era's output font; an Image as is; any other
                                  expression is shown as the front end displays it (graphics always;
                                  other expressions as OutputForm text in eras before typesetting, 3.0)
     {t, "Out", u |-> expr, dur}  an animated output: expr at u from 0 to 1 over dur (a moving
                                  slider, a rotating plot), rendered once as "Frames" pictures
                                  ({t, "Out", u |-> expr, dur, frames} sets its own count)
     {t, "Title", "text"}, {t, "Text", "text"}   the notebook's own prose
   With "Evaluate" -> True every input also gets its computed output, "OutputDelay" after it is typed.
   In/Out numbers count up automatically.  "Enter" -> "Burst" grows the window out of the middle;
   "Pulse" -> track punches it on the track's onsets; "PushIn" is the slow zoom across the span; "Hide" -> {{ta, tb}, ...} takes the window off
   screen for an interlude and bursts it back after. *)
NotebookSession[cells_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{e = sessionOptions[{opts}, t0]}, With[{o = toolOptions[e, NotebookSession]},
    With[{era = NotebookEra[ov[o, "Era"]]}, With[{cs = sessionCells[cells, era, o]},
        With[{screen = Function[t, sessionScreen[cs, era, Min[t, t1 - 10^-3], o]]},
            makeElement["NotebookSession", {t0, t1}, Function[t, sessionDraw[screen, t, {t0, t1}, drawOptions[e, NotebookSession, t]]], <|"Screen" -> screen, "Foley" -> Join[sessionFoley[cs],
                Replace[ov[o, "ChatBar"], {{tb_, txt_String, dur_, sent_} :> Append[keystrokes[tb, dur, StringLength[txt]], {sent, "Tick", 1}], _ -> {}}]]|>]]]]]];
(* typing each input, return on its last key, a blip as each output appears *)
sessionFoley[cs_] := Join @@ Map[Switch[#["kind"],
    "In", Append[keystrokes[#["at"], #["type"], StringLength[#["text"]]], {#["at"] + #["type"] + 1/16, "Tick", 1}],
    "ChatInput" | "FreeForm", Append[keystrokes[#["at"], #["type"], StringLength[#["text"]]], {#["at"] + #["type"] + 1/16, "Tick", 1}],
    "ChatOutput", {{#["at"], "Blip", 1}},
    "Out" | "Pic", If[TrueQ[#["input"]], {}, {{#["at"], "Blip", 1}}],
    _, {}] &, cs];

(* "From" -> previous session wipes this era in over the last picture of the previous one ("Enter" ->
   "Wipe" in a tenth of a cycle, unless told otherwise).  A wipe only needs that picture, so it is kept
   instead of the whole previous session (which would carry its own predecessor, and so on down the film) *)
sessionOptions[opts_List, t0_] := With[{o = Replace[opts, ("From" -> g_AnimatedGraphics) :> ("From" -> <|"Screen" -> g["Screen"][t0 - 10^-3]|>), {1}]},
    If[MatchQ[ov[o, "From"], _Association] && MissingQ[ov[o, "Enter"]], Join[o, {"Enter" -> "Wipe", "EnterTime" -> Replace[ov[o, "EnterTime"], _Missing -> 0.1]}], o]];

(* number the cells, add evaluated outputs, turn expressions into pictures once *)
sessionCells[cells_, era_, o_] := Module[{n = 0, out = {}},
    Do[Switch[c[[2]],
        "In" /; ! StringQ[c[[3]]], n++;   (* a typeset input, e.g. HoldForm[Integrate[...]]: it appears whole, strings in their quotes *)
            AppendTo[out, Join[outCell[c[[1]], n, "", era, o], <|"kind" -> "Pic", "input" -> True|>, displayed[Style[c[[3]], ShowStringCharacters -> True, FontFamily -> era["Input"]["Family"], FontWeight -> If[era["Input"]["Weight"] >= 600, Bold, Plain], FontSize -> era["Input"]["Size"]], era, o]]];
            If[TrueQ[ov[o, "Evaluate"]], out = Join[out, Flatten[{outCell[c[[1]] + ov[o, "OutputDelay"], n, ReleaseHold[c[[3]]], era, o]}]]],
        "In", n++; With[{tt = If[Length[c] > 3, c[[4]], ov[o, "TypeTime"]]},
            AppendTo[out, <|"kind" -> "In", "at" -> c[[1]], "n" -> n, "text" -> c[[3]], "type" -> tt, "colors" -> symbolColors[c[[3]], era]|>];
            If[TrueQ[ov[o, "Evaluate"]], out = Join[out, Flatten[{outCell[c[[1]] + tt + ov[o, "OutputDelay"], n, ToExpression[c[[3]]], era, o]}]]]],
        "Out", out = Join[out, Flatten[{If[Length[c] > 3, animCell[c[[1]], n, c[[3]], c[[4]], era, Join[If[Length[c] > 4, {"Frames" -> c[[5]]}, {}], o]], outCell[c[[1]], n, c[[3]], era, o]]}]],
        "FreeForm", n++; AppendTo[out, <|"kind" -> "FreeForm", "at" -> c[[1]], "n" -> n, "text" -> c[[3]], "code" -> c[[4]],
            "type" -> If[Length[c] > 4, c[[5]], ov[o, "TypeTime"]], "colors" -> symbolColors[c[[4]], era]|>],
        "Replace", With[{i = Last[Flatten[Position[out, a_ /; MatchQ[a["kind"], "Out" | "Pic"] && a["n"] == n && ! TrueQ[a["input"]], {1}, Heads -> False]], None]},
            If[i =!= None, out[[i]] = Append[out[[i]], "until" -> c[[1]]]];
            out = Join[out, Flatten[{outCell[c[[1]], n, c[[3]], era, o]}]]],
        "Title" | "Text", AppendTo[out, <|"kind" -> c[[2]], "at" -> c[[1]], "n" -> n, "text" -> c[[3]]|>],
        "ChatInput", AppendTo[out, <|"kind" -> "ChatInput", "at" -> c[[1]], "n" -> n, "text" -> c[[3]], "type" -> If[Length[c] > 3, c[[4]], 2 ov[o, "TypeTime"]]|>],
        "ChatOutput", AppendTo[out, <|"kind" -> "ChatOutput", "at" -> c[[1]], "n" -> n, "text" -> c[[3]], "code" -> If[Length[c] > 3, c[[4]], {}],
            "link" -> If[Length[c] > 4, c[[5]], None], "colors" -> symbolColors[StringRiffle[If[Length[c] > 3, c[[4]], {}], "\n"], era]|>]], {c, SortBy[cells, First]}];
    SortBy[out, #["at"] &]];
(* an output as the version of its era drew it: before 10, surfaces white under the coloured lights
   of the classic lighting and curves in the old default colours (black before 6, then dark blue);
   from 10 to 14 the ColorData[97] colours; a Manipulate before 10 with the controls of 6.0 *)
$defaultColors15 = {RGBColor[0.24, 0.6, 0.8], RGBColor[0.95, 0.627, 0.1425], RGBColor[0.455, 0.7, 0.21], RGBColor[0.922526, 0.385626, 0.209179]};
asOfVersion[e_, v_ /; v >= 15] := e;
asOfVersion[m : HoldPattern[Manipulate[body_, {{var_Symbol, init_, label___}, min_, max_}, ___]], v_ /; v < 10] := classicManipulate[
    asOfVersion[ReleaseHold[Hold[body] /. HoldPattern[var] -> init], v], Replace[{label}, {{l_String} :> l, _ :> SymbolName[Unevaluated[var]]}], (init - min) / (max - min)];
asOfVersion[e_, v_] := With[{cols = Which[v < 6, ConstantArray[Black, 4], v < 10, Hue[#, 0.6, 0.6] & /@ {0.67, 0.9061, 0.1421, 0.378}, True, ColorData[97] /@ Range[4]]},
    e /. {g_Graphics3D /; v < 10 :> Show[g /. Directive[___, RGBColor[0.880722, 0.611041, 0.142051], ___] -> Directive[GrayLevel[1], Specularity[GrayLevel[1], 20]],
            Lighting -> "Classic", AxesStyle -> Black, BoxStyle -> Black],
        g : (_Graphics | _Graphics3D) :> MapAt[ReplaceAll[Thread[$defaultColors15 -> cols]], g, 1]}];
(* the Manipulate of 6.0: a grey rounded panel, the variable's name, a white groove with an aqua knob,
   the + that opens its animation controls, and the picture in a white framed pane below *)
classicManipulate[body_, name_, u_] := Module[{w = 380, knob},
    knob[x_] := Table[{Blend[{RGBColor["#2B5CB8"], RGBColor["#5C8FE0"], RGBColor["#DDEBFF"]}, k], Disk[{x - 1.5 k, 1.5 k}, 8 (1 - 0.8 k)]}, {k, 0, 1, 0.125}];
    Framed[Column[{
        Row[{Style[name, FontFamily -> "Arial", 13], Spacer[8],
            Graphics[{EdgeForm[GrayLevel[0.6]], White, Rectangle[{0, -2.5}, {w - 90, 2.5}, RoundingRadius -> 2.5], EdgeForm[RGBColor["#1D3F80"]], knob[u * (w - 90)]},
                PlotRange -> {{-9, w - 81}, {-9, 9}}, ImageSize -> {w - 72, 18}, ImagePadding -> 1], Spacer[6],
            Framed[Style["+", FontFamily -> "Arial", Bold, 12, GrayLevel[0.35]], FrameStyle -> GrayLevel[0.6], Background -> GrayLevel[0.97], FrameMargins -> {{4, 4}, {0, 0}}, RoundingRadius -> 2]}],
        Framed[body, FrameStyle -> GrayLevel[0.78], Background -> White, FrameMargins -> 4]}, Spacings -> 0.8],
        FrameStyle -> GrayLevel[0.65], Background -> GrayLevel[0.95], RoundingRadius -> 5, FrameMargins -> 10]];
(* "GraphicsSize" -> w shows graphics w logical pixels wide *)
sized[e_, w_ ? NumericQ] /; MatchQ[e, _Graphics | _Graphics3D | _Graph | _GeoGraphics] := Show[e, ImageSize -> w];
sized[e_, _] := e;
richEraQ[era_] := TrueQ[era["Typeset"]];
outCell[at_, n_, s_String, _, _] := <|"kind" -> "Out", "at" -> at, "n" -> n, "text" -> s|>;
outCell[at_, n_, img_Image, _, _] := <|"kind" -> "Pic", "at" -> at, "n" -> n, "image" -> img, "size" -> ImageDimensions[img]|>;
graphicsQ[e_] := MatchQ[e, _Graphics | _Graphics3D | _Legended | _Image3D | _Graph | _GeoGraphics];
(* before typesetting, a picture came with its -Graphics- line *)
outCell[at_, n_, e_, era_, o_] /; ! richEraQ[era] && graphicsQ[e] := {Join[outCell[at, n, "", era, o], <|"kind" -> "Pic"|>, displayed[e, era, o]],
    outCell[at + 0.1, n, "-" <> ToString[Head[e]] <> "-", era, o]};
outCell[at_, n_, e_, era_, o_] /; richEraQ[era] || graphicsQ[e] := Join[outCell[at, n, "", era, o], <|"kind" -> "Pic"|>, displayed[e, era, o]];
outCell[at_, n_, e_, era_, o_] := outCell[at, n, ToString[e, OutputForm], era, o];
(* "Frames" -> Automatic: 40 pictures a unit, 20 a second at the film's two seconds a bar, at least 24 *)
animCell[at_, n_, f_, dur_, era_, o_] := With[{fr = displayed[f[#], era, o] & /@ Subdivide[0., 1., Replace[ov[o, "Frames"], Automatic :> Max[24, Ceiling[40 dur]]] - 1]},
    <|"kind" -> "Pic", "at" -> at, "n" -> n, "frames" -> fr[[All, "image"]], "size" -> fr[[1, "size"]], "dur" -> dur|>];
(* an expression as the front end shows it, in the era's light or dark mode, at the display's own
   resolution: a logical pixel is "Pixel" screen pixels on a full-depth display, one on the old ones *)
displayed[e_, era_, o_] := With[{k = If[era["Depth"] === "Full", era["Pixel"], 1]},
    With[{img = Rasterize[Style[sized[asOfVersion[e, era["Version"]], ov[o, "GraphicsSize"]], LightDark -> era["LightDark"]], "Image", ImageResolution -> 72 k, Background -> era["Page"]]},
        <|"image" -> img, "size" -> ImageDimensions[img] / k|>]];

(* the window: burst or wipe in, pulse, push in, dim, fly away *)
sessionDraw[screen_, t_, {t0_, t1_}, o_] /; AnyTrue[ov[o, "Hide"], #[[1]] <= t < #[[2]] &] := {};
sessionDraw[screen_, t_, {t0_, t1_}, o_] := Module[{R = ov[o, "Screen"], s, c, pulse, dim = 0, a = 1, et = ov[o, "EnterTime"], xt = ov[o, "ExitTime"], prev = ov[o, "From"], wipe,
    back = Max[{-Infinity}, Select[ov[o, "Hide"][[All, 2]], # <= t &]], burst},
    (* it bursts in at the start, and back after each interlude *)
    burst = Which[back > -Infinity, back, ov[o, "Enter"] === "Burst", t0, True, None];
    pulse = If[ov[o, "Pulse"] === None, 0, TrackPulse[ov[o, "Pulse"], 24][t]];
    s = If[burst === None, 1, 0.08 + 0.92 Easing["OutBack", 1.4][localU[t, burst, burst + et]]] (1 + 0.006 pulse) (1 + ov[o, "PushIn"] Easing["InOutCubic"][localU[t, t0, t1]]);
    If[ListQ[ov[o, "Dim"]], With[{u = Easing["InOutCubic"][localU[t, Sequence @@ ov[o, "Dim"]]]}, s *= 1 - 0.14 u; dim = 0.65 u]];
    If[ov[o, "Exit"] === "FlyAway", With[{u = Easing["InExpo"][localU[t, t1 - xt, t1]]}, s *= 1 + 0.9 u; a = 1 - u]];
    wipe = If[ov[o, "Enter"] === "Wipe" && AssociationQ[prev], localU[t, t0, t0 + et], 1];
    c = R[[1 ;; 2]] + R[[3 ;; 4]] / 2;
    CanvasOpacity[a, CanvasTransform[CanvasScale[s, c], {
        If[TrueQ[ov[o, "Shadow"]], Table[CanvasRectangle[R + {-k, 18 - k / 2, 2 k, k}, Black, Opacity -> 0.04], {k, {2, 6, 12, 20, 30}}], {}],
        If[wipe < 1, With[{y = R[[2]] + R[[4]] Easing["OutCubic"][wipe]}, {
            prev["Screen"],
            CanvasClip[{R[[1]], R[[2]], R[[3]], y - R[[2]]}, screen[t]],
            CanvasRectangle[{R[[1]], y - 3, R[[3]], 6}, White, Opacity -> 0.9 (1 - wipe)]}],
            screen[t]],
        If[dim > 0, CanvasRectangle[R, Black, Opacity -> dim], {}],
        CanvasRectangle[R + {-0.5, -0.5, 1, 1}, Black, "Stroke" -> 1, Opacity -> 0.25]}]]];
(* the screen alone: chrome, cells and the era's extras (the 3.0 BasicInput palette) *)
sessionScreen[cs_, era_, t_, o_] := CanvasScreen[ov[o, "Screen"], Function[{lw, lh}, {era["Chrome"][lw, lh, ov[o, "Title"]],
    With[{r = era["Content"][lw, lh], bar = ov[o, "ChatBar"]}, If[bar === None, notebookDraw[r, era, cs, t],
        {notebookDraw[r - {0, 0, 0, 64}, era, cs, t], CanvasRectangle[{r[[1]], r[[2]] + r[[4]] - 64, r[[3]], 64}, era["Page"]],
         chatBarDraw[{r[[1]] + 24, r[[2]] + r[[4]] - 54, r[[3]] - 30}, bar, t]}]],
    If[ov[o, "Extras"] === Automatic && era["Extras"] =!= None, era["Extras"][lw, lh, t], {}]}], "Pixel" -> era["Pixel"], "Depth" -> era["Depth"]];

(* a picture on a one-bit display, dithered once: a new image every frame would also be kept by the front end *)
dithered[img_, size_] := dithered[img, size] = OrderedDither[img, size];

(* the cells, top to bottom, scrolled so the newest stays in view and gliding when one arrives *)
cellFont[c_, era_] := Switch[c["kind"], "In", era["Input"], "Out", era["Output"], "Title", era["Title"], _, era["Text"]];
labelH[c_, era_] := If[TrueQ[era["LabelsAbove"]] && MatchQ[c["kind"], "In" | "Out" | "Pic"], 1.5 era["Label"]["Size"], 0];
cellHeight[c_, era_, w_] := labelH[c, era] + Switch[c["kind"], "Pic", c["size"][[2]] + 6, "ChatInput", 46, "ChatOutput", 64 + 24 Length[c["code"]] + 16, "FreeForm", 92,
    _, With[{f = cellFont[c, era]}, 1.3 f["Size"] Length[CanvasWrap[c["text"], f, w, "Break" -> If[MatchQ[c["kind"], "In" | "Out"], "Code", "Words"]]] + 4]];
notebookDraw[{rx_, ry_, rw_, rh_}, era_, cs_, t_] := Module[{vis = Select[cs, #["at"] <= t < Lookup[#, "until", Infinity] &], w = rw - era["Left"] - 30, hs, scrollFor, scroll, y, gap = era["Gap"]},
    hs = cellHeight[#, era, w] & /@ vis;
    scrollFor[n_] := Max[0, Total[Take[hs, n]] + gap * (n + 3) - rh];
    scroll = If[Length[vis] < 2, scrollFor[Length[vis]], scrollFor[Length[vis] - 1] +
        (scrollFor[Length[vis]] - scrollFor[Length[vis] - 1]) Easing["OutCubic"][localU[t, vis[[-1]]["at"], vis[[-1]]["at"] + 0.15]]];
    y = ry + gap - scroll;
    CanvasClip[{rx, ry, rw, rh}, {CanvasRectangle[{rx, ry, rw, rh}, era["Page"]],
        MapThread[{cellDraw[#1, {rx + era["Left"], y}, w, #2, era, t, ry], y += #2 + gap}[[1]] &, {vis, hs}]}]];

(* the cell bracket: a thin square hook in the classic eras, a lighter one with a small foot since 6.0 *)
bracket[{bx_, y_}, hh_, era_] := CanvasLine[If[era["BracketKind"] === "Modern", {{bx - 3, y}, {bx, y}, {bx, y + hh}, {bx - 3, y + hh}},
    {{bx - 4, y}, {bx, y}, {bx, y + hh}, {bx - 4, y + hh}}], era["Bracket"], "Thickness" -> era["BracketWidth"]];
cellLabel[c_, era_] := Switch[c["kind"], "In" | "FreeForm", "In[" <> ToString[c["n"]] <> "]:=", _ /; TrueQ[c["input"]], "In[" <> ToString[c["n"]] <> "]:=", "Out" | "Pic", "Out[" <> ToString[c["n"]] <> "]=", _, None];

(* top: the page top; text is not clipped by the page's inset, so lines scrolled above it are dropped *)
cellDraw[c_, {x0_, y_}, w_, h_, era_, t_, top_] := Module[{f = cellFont[c, era], ink = era["Ink"], lab = cellLabel[c, era], lines, shown, yy = y + labelH[c, era]},
    {If[lab === None || y < top, {}, If[TrueQ[era["LabelsAbove"]], CanvasText[lab, {x0 - 14, y + 1.1 era["Label"]["Size"]}, era["Label"], era["LabelColor"]],
        CanvasText[lab, {x0 - 8, yy + If[c["kind"] === "Pic", era["Label"]["Size"] + 4, 1.05 f["Size"]]}, era["Label"], era["LabelColor"], Alignment -> Right]]],
     bracket[{x0 + w + 16, y - 2}, h Easing["OutExpo"][Clip[(t - c["at"]) / 0.12, {0, 1}]], era],
     Switch[c["kind"],
        "ChatInput", chatInputDraw[c, {x0, y}, w, t],
        "FreeForm", freeFormDraw[c, {x0 + 26, yy}, w - 26, era, t],
        "ChatOutput", chatOutputDraw[c, {x0, y}, w, h, era, t],
        "Pic", With[{img = If[KeyExistsQ[c, "frames"], c["frames"][[1 + Floor[Clip[(t - c["at"]) / c["dur"], {0, 1}] (Length[c["frames"]] - 1)]]], c["image"]]},
            CanvasImage[If[era["Depth"] === "Bit", dithered[img, Round[c["size"]]], img], Join[{x0, yy}, c["size"]], Opacity -> Easing["OutCubic"][Clip[(t - c["at"]) / 0.12, {0, 1}]]]],
        _, lines = CanvasWrap[c["text"], f, w, "Break" -> If[MatchQ[c["kind"], "In" | "Out"], "Code", "Words"]];
        shown = If[c["kind"] =!= "In", lines, Module[{n = Floor[Clip[(t - c["at"]) / c["type"], {0, 1}] StringLength[c["text"]]]},
            Flatten[Reap[Do[If[n > 0, Sow[StringTake[ln, Min[n, StringLength[ln]]]]; n -= StringLength[ln]], {ln, lines}]][[2]]]]];
        {MapIndexed[With[{p = {x0, yy + f["Size"] (1.05 + 1.3 (#2[[1]] - 1))}}, If[p[[2]] - f["Size"] < top, {}, codeLine[#1, p, f, c["kind"], era, Lookup[c, "colors", <||>],
            OddQ[Total[quoteCount /@ Take[lines, #2[[1]] - 1]]]]]] &, shown],
         If[c["kind"] === "In" && t - c["at"] < c["type"] + 0.25 && EvenQ[Floor[8 t]],
            CanvasRectangle[{x0 + CanvasTextWidth[Last[shown, ""], f] + 1, yy + 1.3 f["Size"] Max[0, Length[shown] - 1] + 2, 1.1, 1.15 f["Size"]}, ink], {}]}]}];

(* the chat notebooks of 13.3: a speech-bubble icon beside each cell, the question typed into a framed
   input, the answer streamed word by word into a pale pane with a code block *)
speechBubble[{x_, y_}, fill_, stroke_] := {CanvasRectangle[{x, y, 22, 16}, fill, "Radius" -> 3], CanvasPolygon[{{x + 5, y + 15}, {x + 5, y + 22}, {x + 11, y + 15}}, fill],
    CanvasRectangle[{x, y, 22, 16}, stroke, "Radius" -> 3, "Stroke" -> 1.2]};
chatInputDraw[c_, {x_, y_}, w_, t_] := With[{shown = TypedText[c["text"], localU[t, c["at"], c["at"] + c["type"]]], f = CanvasFont["Source Sans 3", 18]},
    {speechBubble[{x - 48, y + 9}, RGBColor["#7DD2FF"], RGBColor["#4992B9"]],
     CanvasRectangle[{x, y + 1, w - 8, 38}, White, "Radius" -> 2], CanvasRectangle[{x, y + 1, w - 8, 38}, RGBColor["#A3C9F1"], "Radius" -> 2, "Stroke" -> 2],
     CanvasText[shown, {x + 14, y + 26}, f, RGBColor["#080808"]],
     If[StringLength[shown] < StringLength[c["text"]] || EvenQ[Floor[8 t]], CanvasRectangle[{x + 15 + CanvasTextWidth[shown, f], y + 11, 1.5, 20}, RGBColor["#080808"]], {}]}];
chatOutputDraw[c_, {x_, y_}, w_, h_, era_, t_] := Module[{u = Easing["OutCubic"][localU[t, c["at"], c["at"] + 0.2]], ws = StringSplit[c["text"]], n, cx = x + 16,
        f = CanvasFont["Source Sans 3", 17.5], cf = <|era["Input"], "Size" -> 15|>, k, left},
    n = Floor[localU[t, c["at"], c["at"] + 0.45] Length[ws]];
    k = localU[t, c["at"] + 0.45, c["at"] + 0.8]; left = Floor[k StringLength[StringRiffle[c["code"], "\n"]]];
    CanvasOpacity[u, {speechBubble[{x - 48, y + 9}, RGBColor["#E6E8EE"], RGBColor["#9AA0AC"]],
        CanvasRectangle[{x, y, w - 8, h - 8}, RGBColor["#F3F4F8"], "Radius" -> 3], CanvasRectangle[{x, y, w - 8, h - 8}, RGBColor["#DADDE4"], "Radius" -> 3, "Stroke" -> 1],
        CanvasText["\[VerticalEllipsis]", {x + w - 22, y + 20}, CanvasFont["Arimo", 14, 700], RGBColor["#888888"]],
        Table[With[{wd = ws[[i]] <> " "}, {CanvasText[wd, {cx, y + 28}, f, If[StringDelete[ws[[i]], PunctuationCharacter] === c["link"], RGBColor["#35569C"], RGBColor["#111111"]]],
            cx += CanvasTextWidth[wd, f]}[[1]]], {i, n}],
        If[k > 0, {CanvasRectangle[{x + 16, y + 42, w - 48, 24 Length[c["code"]] + 14}, White], CanvasRectangle[{x + 16, y + 42, w - 48, 24 Length[c["code"]] + 14}, RGBColor["#E0E0E0"], "Stroke" -> 1],
            MapIndexed[With[{ln = #1, i = #2[[1]]}, With[{m = Max[0, Min[StringLength[ln], left - Total[StringLength /@ Take[c["code"], i - 1]] - (i - 1)]]},
                If[m > 0, codeLine[StringTake[ln, m], {x + 30, y + 67 + 24 (i - 1)}, cf, "In", era, c["colors"], OddQ[Total[quoteCount /@ Take[c["code"], i - 1]]]], {}]]] &, c["code"]]}, {}]}]];

(* the 15.0 chat bar under the notebook: a request typed in, then sent *)
chatBarDraw[{x_, y_, w_}, {t0_, txt_, dur_, sent_}, t_] := With[{shown = TypedText[txt, localU[t, t0, t0 + dur]], f = CanvasFont["Source Sans 3", 16],
        placeholder = t < t0 || t >= sent},
    {CanvasRectangle[{x, y, w - 40, 40}, White, "Radius" -> 10], CanvasRectangle[{x, y, w - 40, 40}, RGBColor["#76C3EB"], "Radius" -> 10, "Stroke" -> 1.5],
     CanvasRectangle[{x + 12, y + 12, 18, 13}, RGBColor["#3F9BD5"], "Radius" -> 3, "Stroke" -> 1.3], CanvasLine[{{x + 16, y + 25}, {x + 16, y + 30}, {x + 21, y + 25}}, RGBColor["#3F9BD5"], "Thickness" -> 1.3],
     CanvasText[If[placeholder, "What would you like to do?", shown], {x + 40, y + 26}, f, If[placeholder, RGBColor["#9A9A9A"], RGBColor["#111111"]]],
     If[! placeholder && EvenQ[Floor[8 t]], CanvasRectangle[{x + 41 + CanvasTextWidth[shown, f], y + 11, 1.4, 18}, RGBColor["#111111"]], {}],
     CanvasText["\[RightArrow]", {x + w - 62, y + 27}, CanvasFont["Arimo", 18, 700], RGBColor["#007DCA"], Alignment -> Center],
     CanvasText["\[Times]", {x + w - 22, y + 16}, CanvasFont["Arimo", 11], RGBColor["#8A8A8A"], Alignment -> Center],
     CanvasText["\[Ellipsis]", {x + w - 22, y + 34}, CanvasFont["Arimo", 12, 700], RGBColor["#8A8A8A"], Alignment -> Center]}];

(* one line of a cell; since 6.0 input is syntax-coloured as the front end colours it: strings grey
   (also where a string wraps onto the next line: inString says the line starts inside one), local
   variables green, symbols the kernel knows nothing about blue, everything else -- the system's words,
   the user's defined ones, slots like #name -- in ink.  colors is the cell's symbol -> colour map *)
codeLine[s_, p_, f_, kind_, era_, colors_ : <||>, inString_ : False] := Which[
    kind === "Title", CanvasText[s, p, f, Replace[era["TitleColor"], Automatic -> era["Ink"]]],
    kind === "Out", CanvasText[s, p, f, Replace[era["OutputInk"], Automatic -> era["Ink"]]],
    kind =!= "In" || era["Syntax"] === None, CanvasText[s, p, f, era["Ink"]],
    True, Module[{x = p[[1]], head = "", rest = s},
        If[inString, With[{k = StringPosition[s, RegularExpression["(?<!\\\\)\""], 1]}, If[k === {}, head = s; rest = "", head = StringTake[s, k[[1, 1]]]; rest = StringDrop[s, k[[1, 1]]]]]];
        Map[{CanvasText[#[[1]], {x, p[[2]]}, f, #[[2]]], x += CanvasTextWidth[#[[1]], f]}[[1]] &,
            Join[If[head === "", {}, {{head, era["Syntax"]["String"]}}], {#, tokenColor[#, era, colors]} & /@
                StringSplit[rest, tok : (("\"" ~~ Shortest[___] ~~ ("\"" | EndOfString)) | ("#" ~~ (WordCharacter | "$") ...) | (("$" | LetterCharacter) ~~ (WordCharacter | "$") ...)) :> tok]]]]];
tokenColor[tok_String, era_, colors_] := Which[StringStartsQ[tok, "\""], era["Syntax"]["String"], StringStartsQ[tok, "#"], era["Ink"],
    True, Lookup[colors, tok, era["Ink"]]];
quoteCount[s_String] := StringCount[s, RegularExpression["(?<!\\\\)\""]];

(* the colours of an input's symbols, worked out once: iterators ({x, 0, 1}), scoped variables
   (Module[{s = 0}, ...]), pattern names (x_) and function variables (u |-> ...) are local; a symbol
   is known when it is the system's, a package's, or given a value in this session *)
symbolColors[code_String, era_] := If[era["Syntax"] === None, <||>, Module[{bare = StringReplace[code, "\"" ~~ Shortest[___] ~~ ("\"" | EndOfString) -> "\" \""], id, locals, syms},
    id = ("$" | LetterCharacter) ~~ (WordCharacter | "$") ...;
    syms = DeleteDuplicates[StringCases[bare, RegularExpression["(?<![#\\w$`])[$A-Za-z][$\\w]*"]]];
    locals = DeleteDuplicates @ Join[
        StringCases[bare, "{" ~~ WhitespaceCharacter ... ~~ v : id ~~ WhitespaceCharacter ... ~~ "," :> v],
        StringCases[bare, ("{" | ",") ~~ WhitespaceCharacter ... ~~ v : id ~~ WhitespaceCharacter ... ~~ "=" ~~ Except["=" | "!"] :> v],
        StringCases[bare, v : id ~~ "_" :> v], StringCases[bare, v : id ~~ WhitespaceCharacter ... ~~ "|->" :> v],
        StringCases[bare, "Function[" ~~ v : id ~~ "," :> v]];
    locals = Select[locals, Names["System`" <> #] === {} && ! knownQ[#] &];
    Association[# -> Which[MemberQ[locals, #], era["Syntax"]["Local"], Names["System`" <> #] =!= {} || knownQ[#], era["Ink"], True, era["Syntax"]["User"]] & /@ syms]]];
knownQ[name_String] := With[{n = Quiet[Names[name]]}, n =!= {} && ToExpression[First[n], InputForm,
    Function[x, ! StringStartsQ[Context[x], "Global`"] || OwnValues[x] =!= {} || DownValues[x] =!= {} || SubValues[x] =!= {} || UpValues[x] =!= {}, HoldAllComplete]]];

(* 8.0's free-form input: an orange = marker, the English typed into its box, then how it was
   understood: an arrow, the head it chose, and the code *)
freeFormDraw[c_, {x_, y_}, w_, era_, t_] := With[{shown = TypedText[c["text"], localU[t, c["at"], c["at"] + c["type"]]], f = CanvasFont["Arimo", 15, 700],
        u = localU[t, c["at"] + c["type"] + 0.15, c["at"] + c["type"] + 0.3], orange = RGBColor["#F76504"]},
    {CanvasRectangle[{x - 26, y + 4, 17, 17}, orange, "Radius" -> 4], CanvasText["=", {x - 17.5, y + 17.5}, CanvasFont["Arimo", 15, 700], White, Alignment -> Center],
     CanvasRectangle[{x - 2, y + 1, Min[w - 20, 380], 25}, White, "Radius" -> 5], CanvasRectangle[{x - 2, y + 1, Min[w - 20, 380], 25}, RGBColor["#CFCFCF"], "Radius" -> 5, "Stroke" -> 1],
     CanvasText[shown, {x + 7, y + 19}, f, RGBColor["#222222"]],
     If[u > 0, CanvasOpacity[u, {CanvasLine[{{x + 4, y + 33}, {x + 4, y + 41}, {x + 13, y + 41}}, orange, "Thickness" -> 1.6],
        CanvasLine[{{x + 10, y + 38}, {x + 13.5, y + 41}, {x + 10, y + 44}}, orange, "Thickness" -> 1.6],
        CanvasText[First[StringSplit[c["code"], "["]], {x + 18, y + 45}, CanvasFont["Arimo", 13], orange],
        codeLine[c["code"], {x + 2, y + 74}, era["Input"], "In", era, c["colors"]]}], {}]}];
