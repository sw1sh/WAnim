(* ::Package:: *)

(* ::Section:: *)
(*Notebook eras*)

(* The notebook through its eras, as NotebookEra values.  Each era is drawn in its
   own logical pixels -- chrome, cell style and display -- from the 1988 Macintosh to 2024's dark mode.
   An era's "Chrome" draws the window at a logical size and "Content" gives the rectangle the cells
   go in; the rest is the cell style NotebookSession reads. *)

PackageScoped[{bevel, eraBox, eraTri}]

eraBox[r_, fill_, stroke_ : None] := {CanvasRectangle[r, fill], If[stroke === None, {}, CanvasRectangle[r + {0.5, 0.5, -1, -1}, stroke, "Stroke" -> 1]]};
eraTri[{x_, y_}, s_, dir_, c_ : Black, filled_ : True] := CanvasPolygon[Switch[dir, "up", {{x, y - s}, {x + s, y + 0.6 s}, {x - s, y + 0.6 s}},
    "down", {{x, y + s}, {x + s, y - 0.6 s}, {x - s, y - 0.6 s}}, "left", {{x - s, y}, {x + 0.6 s, y - s}, {x + 0.6 s, y + s}},
    _, {{x + s, y}, {x - 0.6 s, y - s}, {x - 0.6 s, y + s}}], c, If[filled, Sequence @@ {}, "Stroke" -> 1]];
(* a Windows-style 3D bevel, raised or sunken *)
bevel[{x_, y_, w_, h_}, face_ : RGBColor["#C0C0C0"], sunken_ : False, deep_ : True] := With[
    {hi = If[sunken, RGBColor["#808080"], White], lo = If[sunken, White, RGBColor["#808080"]], dk = If[sunken, RGBColor["#DFDFDF"], Black]},
    {CanvasRectangle[{x, y, w, h}, face], CanvasRectangle[{x, y, w, 1}, hi], CanvasRectangle[{x, y, 1, h}, hi],
     CanvasRectangle[{x, y + h - 1, w, 1}, If[deep, dk, lo]], CanvasRectangle[{x + w - 1, y, 1, h}, If[deep, dk, lo]],
     If[deep, {CanvasRectangle[{x + 1, y + h - 2, w - 2, 1}, lo], CanvasRectangle[{x + w - 2, y + 1, 1, h - 2}, lo]}, {}]}];
T[s_, {x_, y_}, size_, weight_ : 400, c_ : Black, al_ : Left, fam_ : "Arimo"] := CanvasText[s, {x, y}, CanvasFont[fam, size, weight], c, Alignment -> al];
W[s_, size_, weight_ : 400, fam_ : "Arimo"] := CanvasTextWidth[s, CanvasFont[fam, size, weight]];
(* menu titles laid left to right; Windows underlines each access key *)
menus[items_, {x0_, y_}, size_, weight_, gap_, c_ : Black, underline_ : False] := Module[{x = x0},
    Table[With[{w = W[m, size, weight]}, {T[m, {x, y}, size, weight, c], If[underline, CanvasRectangle[{x, y + 1.5, W[StringTake[m, 1], size, weight], 1}, c], {}], x += w + gap}[[;; 2]]], {m, items}]];
checkerPattern[w_, h_, a_, b_] := checkerPattern[w, h, a, b] = Image[Table[If[EvenQ[i + j], List @@ ColorConvert[b, "RGB"], List @@ ColorConvert[a, "RGB"]], {i, h}, {j, w}]];
checkerFill[{x_, y_, w_, h_}, a_ : White, b_ : Black] := CanvasImage[checkerPattern[Round[w], Round[h], a, b], {x, y, w, h}];
vgrad[r_, stops_] := CanvasGradient[r, "Vertical", stops];
dgrad[r_, stops_] := CanvasGradient[r, "Diagonal", stops];

winMenus[] := {"File", "Edit", "Cell", "Format", "Input", "Kernel", "Find", "Window", "Help"};


(* ::Subsection:: *)
(*Macintosh, 1988*)

(* Mathematica 1.0 on a Macintosh, 1988: System 6 chrome, the 1.0 menus, labels above cells in italics,
   bold Courier, thin black brackets; half resolution, one bit *)
mac1988Chrome[lw_, lh_, title_] := Module[{x = 14, wx = 12, wy = 30, ww = lw - 26, wh = lh - 40, sbx, sby, sbh, hby, tw, mf = CanvasFont["Arimo", 12, 700]},
    sbx = wx + ww - 16; sby = wy + 18; sbh = wh - 33; hby = wy + wh - 16; tw = CanvasTextWidth[title, mf];
    {checkerFill[{0, 0, lw, lh}, Black, White], eraBox[{0, 0, lw, 19}, White], eraBox[{0, 19, lw, 1}, Black],
     Table[{CanvasText[m, {x, 14}, mf, Black], x += CanvasTextWidth[m, mf] + 14}[[1]], {m, {"File", "Edit", "Cells", "Search", "Action", "Styles", "Windows"}}],
     eraBox[{wx + 1, wy + 1, ww, wh}, Black], eraBox[{wx, wy, ww, wh}, White, Black], Table[eraBox[{wx + 2, yy, ww - 4, 1}, Black], {yy, wy + 4, wy + 14, 2}],
     eraBox[{wx, wy + 18, ww, 1}, Black], eraBox[{wx + 8, wy + 4, 11, 11}, White, Black], eraBox[{wx + ww - 20, wy + 4, 11, 11}, White, Black],
     eraBox[{wx + ww - 20, wy + 4, 7, 7}, White, Black], eraBox[{wx + ww / 2 - tw / 2 - 7, wy + 2, tw + 14, 15}, White],
     CanvasText[title, {wx + ww / 2, wy + 14}, mf, Black, Alignment -> Center],
     eraBox[{sbx, sby, 16, sbh}, White, Black], checkerFill[{sbx + 1, sby + 16, 14, sbh - 32}, Black, White], eraBox[{sbx, sby, 16, 16}, White, Black], eraTri[{sbx + 8, sby + 8}, 4, "up", Black, False],
     eraBox[{sbx, sby + sbh - 16, 16, 16}, White, Black], eraTri[{sbx + 8, sby + sbh - 8}, 4, "down", Black, False], eraBox[{sbx, sby + sbh - 34, 16, 16}, White, Black],
     eraBox[{wx, hby, ww - 15, 16}, White, Black], checkerFill[{wx + 17, hby + 1, ww - 49, 14}, Black, White], eraBox[{wx, hby, 16, 16}, White, Black], eraTri[{wx + 8, hby + 8}, 4, "left", Black, False],
     eraBox[{wx + ww - 32, hby, 16, 16}, White, Black], eraTri[{wx + ww - 24, hby + 8}, 4, "right", Black, False], eraBox[{wx + 17, hby, 16, 16}, White, Black],
     eraBox[{sbx, hby, 16, 16}, White, Black], eraBox[{sbx + 3, hby + 3, 8, 8}, White, Black], eraBox[{sbx + 6, hby + 6, 7, 7}, White, Black]}];

(* ::Subsection:: *)
(*NeXTSTEP, 1988*)

nextChrome[lw_, lh_, title_] := Module[{mx = 6, my = 6, mw = 104, items = {"Info", "Notebook", "Edit", "Format", "Cell", "Graph", "Action", "Windows", "Print", "Services", "Hide", "Quit"},
    wx = 122, wy = 12, ww = lw - 186, wh = lh - 22, g1 = RGBColor["#686868"], g2 = RGBColor["#B8B8B8"]},
    {eraBox[{0, 0, lw, lh}, g1],
     eraBox[{mx, my, mw, 17}, Black], T["Mathematica", {mx + mw / 2, my + 13}, 11, 700, White, Center],
     MapIndexed[With[{y = my + 17 + 17 (#2[[1]] - 1), i = #2[[1]] - 1}, {bevel[{mx, y, mw, 17}, g2, False, False], T[#1, {mx + 6, y + 12.5}, 11],
        If[i < 10, eraTri[{mx + mw - 9, y + 8.5}, 3, "right"], T[If[i == 10, "h", "q"], {mx + mw - 10, y + 12.5}, 11, 400, Black, Center]]}] &, items],
     Table[With[{tx = lw - 50, ty = 4 + 50 i}, {bevel[{tx, ty, 48, 48}, g2, False, True],
        Switch[Mod[i, 3], 0, CanvasDisk[{tx + 24, ty + 24}, 13, {Black, g1, White, Black, g1, White}[[i + 1]]],
            1, CanvasRectangle[{tx + 12, ty + 14, 24, 20}, {Black, g1, White, Black, g1, White}[[i + 1]]], _, eraBox[{tx + 14, ty + 10, 20, 28}, White, Black]]}], {i, 0, 5}],
     eraBox[{wx, wy, ww, wh}, g2, Black], eraBox[{wx, wy, ww, 19}, Black],
     bevel[{wx + 3, wy + 3, 13, 13}, g2, False, False], bevel[{wx + ww - 16, wy + 3, 13, 13}, g2, False, False],
     CanvasLine[{{wx + ww - 13, wy + 6}, {wx + ww - 6, wy + 13}}, Black, "Thickness" -> 1.2], CanvasLine[{{wx + ww - 6, wy + 6}, {wx + ww - 13, wy + 13}}, Black, "Thickness" -> 1.2],
     T[title, {wx + ww / 2, wy + 14}, 12, 700, White, Center],
     eraBox[{wx + 1, wy + 19, ww - 2, 20}, g2], bevel[{wx + 24, wy + 22, 70, 15}, g2, False, False], T["Input", {wx + 30, wy + 33}, 10],
     Table[bevel[{wx + 102 + 18 i, wy + 22, 15, 15}, g2, False, False], {i, 0, 2}],
     With[{sx = wx + 1, sy = wy + 40, sh = wh - 49}, {eraBox[{sx, sy, 17, sh}, g1], bevel[{sx + 1, sy + 2, 15, 40}, g2, False, False],
        bevel[{sx + 1, sy + sh - 34, 15, 16}, g2, False, False], eraTri[{sx + 8.5, sy + sh - 26}, 3.5, "up"],
        bevel[{sx + 1, sy + sh - 17, 15, 16}, g2, False, False], eraTri[{sx + 8.5, sy + sh - 9}, 3.5, "down"]}],
     eraBox[{wx + 1, wy + wh - 9, ww - 2, 8}, g2], eraBox[{wx + 24, wy + wh - 9, 1, 8}, g1], eraBox[{wx + ww - 25, wy + wh - 9, 1, 8}, g1],
     T["100%", {wx + 32, wy + wh - 1.5}, 8]}];


(* ::Subsection:: *)
(*Windows 3.1, 1991*)

win31Chrome[lw_, lh_, title_] := Module[{tx = 4, ty = 4, tw = lw - 8, my, ry, by, sy, vx, vy, vh, gr = RGBColor["#C0C0C0"]},
    my = ty + 18; ry = my + 19; by = ry + 14; sy = lh - 22; vx = tx + tw - 17; vy = by + 25; vh = sy - vy - 1;
    {eraBox[{0, 0, lw, lh}, gr, Black], eraBox[{tx, ty, tw, 18}, RGBColor["#000080"]], T[title, {lw / 2, ty + 13.5}, 11, 700, White, Center],
     bevel[{tx, ty, 18, 18}, gr, False, False], eraBox[{tx + 4, ty + 8, 10, 3}, White, Black],
     bevel[{tx + tw - 36, ty, 18, 18}, gr], eraTri[{tx + tw - 27, ty + 9}, 3.5, "down"], bevel[{tx + tw - 18, ty, 18, 18}, gr], eraTri[{tx + tw - 9, ty + 9}, 3.5, "up"],
     eraBox[{tx, my, tw, 18}, White], eraBox[{tx, my + 18, tw, 1}, Black],
     menus[{"File", "Edit", "Cell", "Graph", "Action", "Style", "Options", "Window", "Help"}, {tx + 8, my + 13}, 11, 700, 13, Black, True],
     eraBox[{tx, ry, tw, 13}, White], eraBox[{tx, ry + 13, tw, 1}, Black],
     Table[With[{xx = tx + 10 + 12 i}, {eraBox[{xx, ry + Which[Mod[i, 8] == 0, 3, Mod[i, 4] == 0, 6, True, 9], 1, Which[Mod[i, 8] == 0, 10, Mod[i, 4] == 0, 7, True, 4]}, Black],
        If[Mod[i, 8] == 0 && i > 0, T[ToString[i / 8], {xx + 2, ry + 9}, 7], {}]}], {i, 0, Floor[(tw - 21) / 12]}],
     eraBox[{tx, by, tw, 24}, gr], eraBox[{tx, by + 24, tw, 1}, Black], eraBox[{tx + 6, by + 4, 96, 16}, White, Black], T["Input", {tx + 10, by + 15.5}, 10],
     bevel[{tx + 86, by + 5, 15, 14}, gr, False, False], eraTri[{tx + 93.5, by + 12}, 2.5, "down"],
     Table[With[{bx = tx + 116 + 22 i + If[i >= 3, 8, 0] + If[i >= 7, 8, 0], c = RGBColor /@ {"#000080", "#800000", "#008000", "#000000", "#808000", "#008080"}},
        {bevel[{bx, by + 3, 20, 18}, gr, False, True], Switch[Mod[i, 3], 0, CanvasRectangle[{bx + 6, by + 7, 8, 8}, c[[Mod[i, 6] + 1]]],
            1, CanvasDisk[{bx + 10, by + 12}, 4, c[[Mod[i, 6] + 1]]], _, {CanvasRectangle[{bx + 5, by + 8, 10, 2}, c[[Mod[i, 6] + 1]]], CanvasRectangle[{bx + 5, by + 12, 10, 2}, c[[Mod[i, 6] + 1]]]}]}], {i, 0, 11}],
     eraBox[{tx, sy, tw, 18}, gr], bevel[{tx + 3, sy + 2, 0.62 tw, 14}, gr, True, False], bevel[{tx + 0.62 tw + 7, sy + 2, 0.38 tw - 10, 14}, gr, True, False],
     T["Ready", {tx + 7, sy + 12.5}, 10], T["211833K Bytes Free", {tx + 0.62 tw + 11, sy + 12.5}, 10],
     eraBox[{vx, vy, 17, vh}, RGBColor["#E0E0E0"], Black], bevel[{vx, vy, 17, 17}], eraTri[{vx + 8.5, vy + 8.5}, 3.5, "up"],
     bevel[{vx, vy + vh - 17, 17, 17}], eraTri[{vx + 8.5, vy + vh - 8.5}, 3.5, "down"], bevel[{vx, vy + 18, 17, 17}],
     eraBox[{tx, vy, tw - 17, vh}, White]}];
win31Content[lw_, lh_] := With[{vy = 4 + 18 + 19 + 14 + 25}, {4, vy, lw - 8 - 17, lh - 22 - vy - 1}];


(* ::Subsection:: *)
(*Windows 95, 1996*)

win95Chrome[lw_, lh_, title_] := Module[{tb = lh - 26, wx = 6, wy = 6, ww = lw - 12, wh, my, cx, cy, cw, ch, vx, vy, vh, gr = RGBColor["#C0C0C0"]},
    wh = tb - 12; my = wy + 22; cx = wx + 4; cy = my + 19; cw = ww - 8; ch = wh - (cy - wy) - 4; vx = cx + cw - 18; vy = cy + 2; vh = ch - 4;
    {eraBox[{0, 0, lw, lh}, RGBColor["#008080"]],
     eraBox[{0, tb, lw, 26}, gr], eraBox[{0, tb, lw, 1}, RGBColor["#DFDFDF"]], eraBox[{0, tb + 1, lw, 1}, White],
     bevel[{3, tb + 4, 56, 19}, gr], T["Start", {31, tb + 18}, 11, 700, Black, Center],
     bevel[{64, tb + 4, 150, 19}, gr, True, False], T["Mathematica", {72, tb + 18}, 11, 700],
     bevel[{lw - 66, tb + 4, 63, 19}, gr, True, False], T["10:23 AM", {lw - 34, tb + 17.5}, 10, 400, Black, Center],
     bevel[{wx, wy, ww, wh}, gr], eraBox[{wx + 3, wy + 3, ww - 6, 18}, RGBColor["#000080"]],
     eraBox[{wx + 6, wy + 5, 11, 14}, White, Black], eraBox[{wx + 8, wy + 9, 7, 1}, RGBColor["#000080"]], eraBox[{wx + 8, wy + 12, 7, 1}, RGBColor["#000080"]],
     T[title, {wx + 22, wy + 16.5}, 11, 700, White],
     Table[With[{bx = wx + ww - 5 - 16 (3 - i) + If[i == 2, 2, 0]}, {bevel[{bx, wy + 5, 16, 14}],
        Switch[i, 0, CanvasRectangle[{bx + 4, wy + 14, 6, 2}, Black], 1, {CanvasRectangle[{bx + 3.5, wy + 7.5, 8, 7}, Black, "Stroke" -> 1], CanvasRectangle[{bx + 3, wy + 7, 9, 2}, Black]},
            _, {CanvasLine[{{bx + 4, wy + 8}, {bx + 11, wy + 15}}, Black, "Thickness" -> 1.5], CanvasLine[{{bx + 11, wy + 8}, {bx + 4, wy + 15}}, Black, "Thickness" -> 1.5]}]}], {i, 0, 2}],
     menus[winMenus[], {wx + 10, my + 13}, 11, 400, 14, Black, True],
     bevel[{cx, cy, cw, ch}, White, True, True],
     checkerFill[{vx, vy, 16, vh}, gr, White], bevel[{vx, vy, 16, 16}], eraTri[{vx + 8, vy + 8}, 3, "up"],
     bevel[{vx, vy + vh - 16, 16, 16}], eraTri[{vx + 8, vy + vh - 8}, 3, "down"], bevel[{vx, vy + 17, 16, 30}]}];
win95Content[lw_, lh_] := With[{wh = lh - 26 - 12, cy = 6 + 22 + 19}, {6 + 4 + 2, cy + 2, lw - 12 - 8 - 21, wh - (cy - 6) - 4 - 4}];

(* the 3.0 BasicInput palette, a narrow floating window of symbol buttons; one button lights per eighth *)
basicInputPalette[{x_, y_}, t_] := Module[{syms = Characters["\[Pi]ei\[Infinity]\[Degree]\[Times]\[Divide]\[Rule]\[NotEqual]\[LessEqual]\[GreaterEqual]\[Element]\[Not]\[And]\[Or]\[Alpha]\[Beta]\[Gamma]\[Delta]\[Epsilon]\[Theta]\[Lambda]\[Mu]\[Sigma]\[Phi]\[Omega]\[CapitalGamma]\[CapitalDelta]\[CapitalSigma]\[CapitalOmega]"], cols = 5, bw = 17, w, h, gr = RGBColor["#C0C0C0"]},
    w = cols bw + 8; h = Ceiling[Length[syms] / cols] bw + 26;
    {bevel[{x, y, w, h}, gr], eraBox[{x + 3, y + 3, w - 6, 14}, RGBColor["#000080"]], T["BasicInput", {x + 6, y + 13.5}, 9, 700, White],
     bevel[{x + w - 15, y + 4, 11, 11}],
     MapIndexed[With[{bx = x + 4 + Mod[#2[[1]] - 1, cols] bw, by = y + 20 + Floor[(#2[[1]] - 1) / cols] bw, lit = Mod[Floor[8 t], Length[syms]] == #2[[1]] - 1},
        {bevel[{bx, by, bw - 1, bw - 1}, If[lit, RGBColor["#DFDFDF"], gr], lit, True], T[#1, {bx + (bw - 1) / 2, by + 12}, 11, 400, Black, Center, "Tinos"]}] &, syms]}];


(* ::Subsection:: *)
(*Mac OS 9, 1999*)

mac9Chrome[lw_, lh_, title_] := Module[{wx = 14, wy = 32, ww = lw - 30, wh = lh - 44, cx, cy, cw, ch, vx, vh, hy, tw},
    cx = wx + 5; cy = wy + 22; cw = ww - 10; ch = wh - 27; vx = cx + cw - 16; vh = ch - 15; hy = cy + ch - 15; tw = W[title, 12, 700];
    {vgrad[{0, 0, lw, lh}, {{0, RGBColor["#5C5CA8"]}, {1, RGBColor["#3E3E86"]}}],
     vgrad[{0, 0, lw, 20}, {{0, RGBColor["#F2F2F2"]}, {1, RGBColor["#D6D6D6"]}}], eraBox[{0, 20, lw, 1}, RGBColor["#777777"]],
     menus[winMenus[], {16, 14.5}, 12, 700, 16], T["10:23 AM", {lw - 12, 14.5}, 12, 700, Black, Right],
     CanvasRectangle[{wx + 3, wy + 3, ww, wh}, Black, Opacity -> 0.35], eraBox[{wx, wy, ww, wh}, RGBColor["#DDDDDD"], RGBColor["#555555"]],
     eraBox[{wx + 1, wy + 1, ww - 2, 1}, White], eraBox[{wx + 1, wy + 1, 1, wh - 2}, White],
     Table[{eraBox[{wx + 24, yy, ww - 48, 1}, RGBColor["#9C9C9C"]], eraBox[{wx + 24, yy + 1, ww - 48, 1}, White]}, {yy, wy + 5, wy + 17, 2}],
     eraBox[{wx + ww / 2 - tw / 2 - 8, wy + 3, tw + 16, 17}, RGBColor["#DDDDDD"]], T[title, {wx + ww / 2, wy + 15.5}, 12, 700, Black, Center],
     Table[{eraBox[{bx, wy + 5, 12, 12}, RGBColor["#EEEEEE"], RGBColor["#555555"]], eraBox[{bx + 1, wy + 6, 10, 1}, White]}, {bx, {wx + 7, wx + ww - 19, wx + ww - 35}}],
     eraBox[{cx, cy, cw, ch}, White, RGBColor["#777777"]],
     eraBox[{vx, cy, 16, vh}, RGBColor["#E4E4E4"], RGBColor["#777777"]], eraBox[{vx + 2, cy + 18, 12, 38}, RGBColor["#A6A6D8"], RGBColor["#55557A"]],
     Table[eraBox[{vx + 4, cy + 31 + 3 i, 8, 1}, RGBColor["#E0E0FF"]], {i, 0, 3}],
     eraBox[{vx, cy + vh - 30, 16, 15}, RGBColor["#EEEEEE"], RGBColor["#777777"]], eraTri[{vx + 8, cy + vh - 22.5}, 3, "up"],
     eraBox[{vx, cy + vh - 15, 16, 15}, RGBColor["#EEEEEE"], RGBColor["#777777"]], eraTri[{vx + 8, cy + vh - 7.5}, 3, "down"],
     eraBox[{cx, hy, cw, 15}, RGBColor["#E4E4E4"], RGBColor["#777777"]], eraBox[{cx + 1, hy + 1, 44, 13}, RGBColor["#F4F4F4"], RGBColor["#999999"]],
     T["100%", {cx + 6, hy + 11}, 10], eraTri[{cx + 38, hy + 7.5}, 2.5, "down"]}];
mac9Content[lw_, lh_] := With[{cx = 19, cy = 54, cw = lw - 40, ch = lh - 71}, {cx + 1, cy + 1, cw - 18, ch - 17}];


(* ::Subsection:: *)
(*Windows XP, 2004*)

(* Luna: the Bliss hill under a deep sky, the glossy blue taskbar with its green start button and
   the four-colour flag, the tray, and the window's blue frame, glossy title bar and buttons *)
xpChrome[lw_, lh_, title_] := Module[{tb = lh - 30, wx = 10, wy = 8, ww = lw - 20, wh, tbh = 28, my, cx, cy, cw, ch, vx, hy, hill, flag, gloss},
    wh = tb - 14; my = wy + tbh; cx = wx + 4; cy = my + 20; cw = ww - 8; ch = wh - tbh - 24; vx = cx + cw - 17; hy = cy + ch - 17;
    hill[h_] := FilledCurve[{BezierCurve[cxf /@ {{0, h lh}, {0.28 lw, (h - 0.2) lh}, {0.62 lw, (h - 0.06) lh}, {lw, (h - 0.03) lh}}], Line[cxf /@ {{lw, (h - 0.03) lh}, {lw, lh}, {0, lh}, {0, h lh}}]}];
    flag[{x_, y_}, s_] := MapThread[CanvasRectangle[{x + #1[[1]] (s + 1), y + #1[[2]] (s + 1) - 0.25 #1[[1]] s, s, s}, RGBColor[#2], "Radius" -> 1] &,
        {{{0, 0}, {1, 0}, {0, 1}, {1, 1}}, {"#F35325", "#81BC06", "#05A6F0", "#FFBA08"}}];
    gloss[{x_, y_, w_, h_}, c_, r_] := {CanvasRectangle[{x, y, w, h}, c, "Radius" -> r], CanvasRectangle[{x + 1, y + 1, w - 2, h / 2 - 1}, White, "Radius" -> r, Opacity -> 0.28],
        CanvasRectangle[{x + 0.5, y + 0.5, w - 1, h - 1}, White, "Radius" -> r, "Stroke" -> 1, Opacity -> 0.9]};
    {vgrad[{0, 0, lw, lh}, {{0, RGBColor["#1D57C9"]}, {0.35, RGBColor["#4B8EE6"]}, {0.62, RGBColor["#9CCBF5"]}, {1, RGBColor["#C9E4FA"]}}],
     Table[CanvasTransform[CanvasTranslate[c[[1]]] . CanvasScale[{2.6, 1}], CanvasDisk[{0, 0}, c[[2]], White, Opacity -> 0.35]],
        {c, {{{0.2 lw, 0.16 lh}, 0.05 lw}, {{0.27 lw, 0.14 lh}, 0.035 lw}, {{0.7 lw, 0.22 lh}, 0.06 lw}, {{0.8 lw, 0.19 lh}, 0.04 lw}}}],
     {RGBColor["#6DBE3C"], EdgeForm[], hill[0.68]}, {RGBColor["#3F9A25"], EdgeForm[], hill[0.8]},
     vgrad[{0, tb, lw, 30}, {{0, RGBColor["#3F8CF3"]}, {0.08, RGBColor["#2B6FE6"]}, {0.5, RGBColor["#245EDB"]}, {1, RGBColor["#1941A5"]}}],
     CanvasRectangle[{0, tb, lw, 1}, RGBColor["#6CA2F5"]],
     CanvasRectangle[{0, tb, 104, 30}, RGBColor["#3A9C38"], "Radius" -> 13], CanvasRectangle[{0, tb, 60, 30}, RGBColor["#3A9C38"]],
     CanvasRectangle[{0, tb + 1, 100, 13}, White, "Radius" -> 8, Opacity -> 0.22],
     flag[{10, tb + 7}, 7],
     CanvasText["start", {31, tb + 21.5}, CanvasFont["Arimo", 17, 700, True], RGBColor[0, 0, 0, 0.45]], CanvasText["start", {30, tb + 20.5}, CanvasFont["Arimo", 17, 700, True], White],
     vgrad[{lw - 96, tb, 96, 30}, {{0, RGBColor["#1C9BF0"]}, {1, RGBColor["#0D79D8"]}}], CanvasRectangle[{lw - 96, tb, 1, 30}, RGBColor["#0B4FB4"]],
     CanvasPolygon[{{lw - 86, tb + 13}, {lw - 83, tb + 13}, {lw - 79, tb + 9}, {lw - 79, tb + 21}, {lw - 83, tb + 17}, {lw - 86, tb + 17}}, White],
     T["10:23 AM", {lw - 44, tb + 19.5}, 11, 400, White, Center],
     (* the window: a blue frame, rounded on top, with a glossy title bar *)
     CanvasRectangle[{wx - 1, wy - 1, ww + 2, wh + 2}, RGBColor["#0831D9"], "Radius" -> 9],
     CanvasRectangle[{wx, wy, ww, wh}, RGBColor["#0B5CE6"], "Radius" -> 8], CanvasRectangle[{wx, wy + 10, ww, wh - 10}, RGBColor["#0B5CE6"]],
     vgrad[{wx + 4, wy + 1, ww - 8, tbh}, {{0, RGBColor["#0058EE"]}, {0.08, RGBColor["#3A93FF"]}, {0.2, RGBColor["#288EFF"]}, {0.45, RGBColor["#0761F0"]}, {0.9, RGBColor["#0550E0"]}, {1, RGBColor["#0442C6"]}}],
     CanvasPolygon[Table[{wx + 16, wy + 15} + If[EvenQ[k], 7, 3] {Sin[k Pi / 6], -Cos[k Pi / 6]}, {k, 0, 11}], RGBColor["#E23C1E"]],
     CanvasPolygon[Table[{wx + 16, wy + 15} + If[EvenQ[k], 7, 3] {Sin[k Pi / 6], -Cos[k Pi / 6]}, {k, 0, 11}], RGBColor["#7A1300"], "Stroke" -> 0.7],
     T[title, {wx + 30, wy + 20}, 12.5, 700, RGBColor[0, 0, 0.2, 0.55]], T[title, {wx + 29, wy + 19}, 12.5, 700, White],
     gloss[{wx + ww - 27, wy + 5, 21, 21}, RGBColor["#E0512B"], 3], gloss[{wx + ww - 50, wy + 5, 21, 21}, RGBColor["#2B78F0"], 3], gloss[{wx + ww - 73, wy + 5, 21, 21}, RGBColor["#2B78F0"], 3],
     CanvasLine[{{wx + ww - 21, wy + 10.5}, {wx + ww - 12, wy + 19.5}}, White, "Thickness" -> 2.2], CanvasLine[{{wx + ww - 12, wy + 10.5}, {wx + ww - 21, wy + 19.5}}, White, "Thickness" -> 2.2],
     CanvasRectangle[{wx + ww - 44.5, wy + 10.5, 10, 9}, White, "Stroke" -> 2], CanvasRectangle[{wx + ww - 67, wy + 17.5, 9, 2.5}, White],
     eraBox[{wx + 4, my, ww - 8, 20}, RGBColor["#ECE9D8"]], menus[winMenus[], {wx + 12, my + 14}, 11.5, 400, 14],
     eraBox[{cx, cy, cw, ch}, White, RGBColor["#7F9DB9"]],
     eraBox[{vx, cy + 1, 16, ch - 18}, RGBColor["#F4F3EE"]], CanvasRectangle[{vx + 1, cy + 20, 14, 46}, RGBColor["#B8CBF8"], "Radius" -> 3],
     CanvasRectangle[{vx + 1, cy + 2, 14, 16}, RGBColor["#C3D3FD"], "Radius" -> 3], eraTri[{vx + 8, cy + 10}, 3, "up", RGBColor["#4D6185"]],
     CanvasRectangle[{vx + 1, cy + ch - 35, 14, 16}, RGBColor["#C3D3FD"], "Radius" -> 3], eraTri[{vx + 8, cy + ch - 27}, 3, "down", RGBColor["#4D6185"]],
     eraBox[{cx + 1, hy, cw - 2, 16}, RGBColor["#F4F3EE"]], eraBox[{cx + 3, hy + 2, 42, 12}, White, RGBColor["#7F9DB9"]], T["100%", {cx + 7, hy + 11.5}, 10]}];
xpContent[lw_, lh_] := With[{wh = lh - 30 - 14, cy = 8 + 28 + 20}, {15, cy + 1, lw - 20 - 8 - 19, wh - 28 - 24 - 19}];


(* ::Subsection:: *)
(*Mac OS X, 2007, through dark mode, 2024*)

traffic[{x_, y_}, r_, flat_] := MapIndexed[With[{cx = x + (#2[[1]] - 1) 2.85 r}, If[flat, {CanvasDisk[{cx, y}, r, RGBColor[#1[[1]]]], CanvasDisk[{cx, y}, r, RGBColor[#1[[2]]], "Stroke" -> 0.8]},
    {CanvasDisk[{cx, y}, r, RGBColor[#1[[2]]]], CanvasDisk[{cx, y + 0.1 r}, 0.85 r, RGBColor[#1[[1]]]], CanvasDisk[{cx, y - 0.45 r}, 0.5 r, White, Opacity -> 0.5],
     CanvasDisk[{cx, y}, r, Black, "Stroke" -> 0.8, Opacity -> 0.35]}]] &, {{"#FF6159", "#E2463F"}, {"#FFBD2E", "#E1A116"}, {"#28C941", "#12AC28"}}];
osxMenus[] := {"Mathematica", "File", "Edit", "Insert", "Format", "Cell", "Graphics", "Evaluation", "Palettes", "Window", "Help"};
osxGeom[style_, lw_, lh_] := With[{mbh = If[style === "OSX", 22, 24]}, <|"mbh" -> mbh, "wx" -> 34, "wy" -> mbh + 18, "ww" -> lw - 68, "wh" -> lh - mbh - 34,
    "tbh" -> If[style === "OSX", 23, 28], "rad" -> If[style === "BigSur" || style === "Dark", 11, 5], "tool" -> If[style === "Dark", 39, 0]|>];
osxChrome[style_][lw_, lh_, title_] := Module[{g = osxGeom[style, lw, lh], dark = style === "Dark", wp, cy, h},
    wp = Switch[style, "OSX", {"#1B1745", "#5A2A8C", "#1E4F9A"}, "Yosemite", {"#E9A56A", "#7C6FA0", "#2F4F7D"}, "BigSur", {"#F4A77B", "#C45E8E", "#2C4F9E"}, _, {"#1D2436", "#312043", "#0E2440"}];
    cy = g["wy"] + g["tbh"] + 1 + g["tool"]; h = g["wy"] + g["wh"] - cy - If[style === "OSX", 16, 0];
    {dgrad[{0, 0, lw, lh}, {{0, RGBColor[wp[[1]]]}, {0.5, RGBColor[wp[[2]]]}, {1, RGBColor[wp[[3]]]}}],
     If[style === "OSX", CanvasOpacity[0.3, CanvasLine[Table[{u lw, lh (0.8 - 0.55 u + 0.3 Sin[3 u])}, {u, -0.05, 1.05, 0.05}], RGBColor["#B9A7FF"], "Thickness" -> 60]], {}],
     CanvasRectangle[{0, 0, lw, g["mbh"]}, If[dark, RGBColor[0.12, 0.12, 0.13], RGBColor[0.98, 0.98, 0.98]], Opacity -> If[dark, 0.85, 0.92]],
     CanvasRectangle[{0, g["mbh"], lw, 1}, If[dark, Black, GrayLevel[0, 0.18]]],
     Module[{x = 20, ms = osxMenus[]}, Table[{T[ms[[i]], {x, 0.7 g["mbh"]}, 13, If[i == 1, 700, 400], If[dark, RGBColor["#EEEEEE"], RGBColor["#111111"]]],
        x += W[ms[[i]], 13, If[i == 1, 700, 400]] + 19}[[1]], {i, Length[ms]}]],
     T["Mon 10:23 AM", {lw - 16, 0.7 g["mbh"]}, 13, 400, If[dark, RGBColor["#EEEEEE"], RGBColor["#111111"]], Right],
     Table[CanvasRectangle[{g["wx"] - k, g["wy"] + 12 - k / 2, g["ww"] + 2 k, g["wh"] + k}, Black, "Radius" -> g["rad"] + k, Opacity -> 0.06], {k, {4, 10, 18, 28}}],
     CanvasRectangle[{g["wx"], g["wy"], g["ww"], g["wh"]}, If[dark, RGBColor["#1B1B1B"], White], "Radius" -> g["rad"]],
     CanvasClip[{g["wx"], g["wy"], g["ww"], g["wh"]}, {
        vgrad[{g["wx"], g["wy"], g["ww"], g["tbh"]}, Switch[style, "OSX", {{0, RGBColor["#E9E9E9"]}, {1, RGBColor["#BDBDBD"]}}, "Yosemite", {{0, RGBColor["#EDEDED"]}, {1, RGBColor["#D9D9D9"]}},
            "BigSur", {{0, RGBColor["#F6F6F6"]}, {1, RGBColor["#EFEFEF"]}}, _, {{0, RGBColor["#2E2E2E"]}, {1, RGBColor["#282828"]}}]],
        CanvasRectangle[{g["wx"], g["wy"] + g["tbh"], g["ww"], 1}, Which[dark, RGBColor["#111111"], style === "OSX", RGBColor["#8C8C8C"], True, RGBColor["#CFCFCF"]]],
        traffic[{g["wx"] + 20, g["wy"] + g["tbh"] / 2}, 6.5, style =!= "OSX"],
        T[title, {g["wx"] + g["ww"] / 2, g["wy"] + g["tbh"] / 2 + 5}, 13, If[style === "BigSur" || dark, 700, 400], If[dark, RGBColor["#DDDDDD"], RGBColor["#333333"]], Center],
        If[style =!= "OSX", T["100% \[DownPointer]", {g["wx"] + g["ww"] - 16, g["wy"] + g["tbh"] / 2 + 5}, 12, 400, If[dark, RGBColor["#AAAAAA"], RGBColor["#777777"]], Right], {}],
        If[dark, darkToolbar[{g["wx"], g["wy"] + g["tbh"] + 1, g["ww"], 38}], {}],
        CanvasRectangle[{g["wx"] + g["ww"] - 14, cy, 14, h}, Which[dark, RGBColor["#2A2A2A"], style === "OSX", RGBColor["#EEEEEE"], True, RGBColor["#FAFAFA"]]],
        CanvasRectangle[{g["wx"] + g["ww"] - 11, cy + 8, 8, 60}, Which[style === "OSX", RGBColor["#7BA7E1"], dark, RGBColor["#5A5A5A"], True, RGBColor["#C1C1C1"]], "Radius" -> 4],
        If[style === "OSX", {CanvasRectangle[{g["wx"], g["wy"] + g["wh"] - 16, g["ww"], 16}, RGBColor["#E4E4E4"]], CanvasRectangle[{g["wx"], g["wy"] + g["wh"] - 16, g["ww"], 1}, RGBColor["#AAAAAA"]],
            T["100%", {g["wx"] + 8, g["wy"] + g["wh"] - 4}, 10, 400, RGBColor["#333333"]]}, {}]}]}];
osxContent[style_][lw_, lh_] := With[{g = osxGeom[style, lw, lh]}, With[{cy = g["wy"] + g["tbh"] + 1 + g["tool"]},
    {g["wx"], cy, g["ww"] - 14, g["wy"] + g["wh"] - cy - If[style === "OSX", 16, 0]}]];
(* the 14.3 notebook toolbar *)
darkToolbar[{x_, y_, w_, h_}] := Module[{gx = x + 14},
    {CanvasRectangle[{x, y, w, h}, RGBColor["#262626"]], CanvasRectangle[{x, y + h, w, 1}, RGBColor["#111111"]],
     Table[{T[grp, {gx, y + 12}, 9, 400, RGBColor["#9A9A9A"]],
        If[grp === "Cell Style", {CanvasRectangle[{gx, y + 16, 96, 17}, RGBColor["#383838"], "Radius" -> 3], T["+ Insert Cell...", {gx + 6, y + 28.5}, 10, 400, RGBColor["#DDDDDD"]], gx += 110}[[;; 2]],
            {Table[CanvasRectangle[{gx + 22 k, y + 18, 14, 13}, If[grp === "Evaluation" && k == 0, RGBColor["#E0482F"], RGBColor["#9C9C9C"]], "Radius" -> 2,
                If[grp === "Evaluation" && k == 0, Sequence @@ {}, "Stroke" -> 1.2]], {k, 0, 2}], gx += 88}[[1]]]}, {grp, {"Evaluation", "Assistance", "Cell Style", "Cells", "Code", "Insert", "Notebook"}}]}];


(* ::Subsection:: *)
(*NotebookEra*)

(* the cell style of each look; several windows share one *)
eraStyle["Mac1988"] = <|"Input" -> CanvasFont["Courier Prime", 13, 700], "Output" -> CanvasFont["Courier Prime", 13, 700], "Text" -> CanvasFont["Tinos", 13], "Title" -> CanvasFont["Tinos", 22],
        "Label" -> CanvasFont["Arimo", 10.5, 400, True], "LabelColor" -> Black, "LabelsAbove" -> True, "Left" -> 22, "Gap" -> 6, "Bracket" -> Black, "BracketKind" -> "Mac", "BracketWidth" -> 1|>;
eraStyle["Win1991"] = <|"Input" -> CanvasFont["Courier Prime", 12, 700], "Output" -> CanvasFont["Courier Prime", 12, 400], "Text" -> CanvasFont["Arimo", 12], "Title" -> CanvasFont["Arimo", 20],
        "Label" -> CanvasFont["Arimo", 10, 400, True], "LabelColor" -> Black, "LabelsAbove" -> True, "Left" -> 22, "Gap" -> 6, "Bracket" -> RGBColor["#0000FF"], "BracketKind" -> "Classic", "BracketWidth" -> 1|>;
eraStyle["Win1996"] = <|"Input" -> CanvasFont["Courier Prime", 12, 700], "Output" -> CanvasFont["Courier Prime", 12, 400], "Text" -> CanvasFont["Tinos", 13], "Title" -> CanvasFont["Tinos", 22],
        "Label" -> CanvasFont["Arimo", 10, 400, True], "LabelColor" -> RGBColor["#1B1A46"], "LabelsAbove" -> True, "Left" -> 22, "Gap" -> 7, "Bracket" -> RGBColor["#1B1A46"], "BracketKind" -> "Classic", "BracketWidth" -> 1|>;
eraStyle["Mac1999"] = <|"Input" -> CanvasFont["Courier Prime", 12.5, 700], "Output" -> CanvasFont["Courier Prime", 12.5, 400], "Text" -> CanvasFont["Tinos", 13], "Title" -> CanvasFont["Tinos", 22],
        "Label" -> CanvasFont["Arimo", 9], "LabelColor" -> RGBColor["#4F4E80"], "LabelsAbove" -> False, "Left" -> 62, "Gap" -> 8, "Bracket" -> RGBColor["#605F99"], "BracketKind" -> "Classic", "BracketWidth" -> 1|>;
eraStyle["Mac2007"] = <|"Input" -> CanvasFont["Courier Prime", 15, 700], "Output" -> CanvasFont["Courier Prime", 15, 400], "Text" -> CanvasFont["Tinos", 16], "Title" -> CanvasFont["Tinos", 28],
        "Label" -> CanvasFont["Arimo", 10.5], "LabelColor" -> RGBColor["#3638AF"], "LabelsAbove" -> False, "Left" -> 74, "Gap" -> 12, "Bracket" -> RGBColor["#6D82C7"], "BracketKind" -> "Modern", "BracketWidth" -> 1.2,
        "Syntax" -> <|"User" -> RGBColor["#0000FF"], "String" -> RGBColor["#555555"], "Local" -> RGBColor["#438958"]|>|>;
eraStyle["Mac2014"] = <|"Input" -> CanvasFont["Courier Prime", 17, 700], "Output" -> CanvasFont["Courier Prime", 17, 400], "Text" -> CanvasFont["Source Sans 3", 19], "Title" -> CanvasFont["Source Sans 3", 34, 600],
        "TitleColor" -> RGBColor["#C8321E"], "Label" -> CanvasFont["Source Sans 3", 12.5], "LabelColor" -> RGBColor["#6F97B8"], "LabelsAbove" -> False, "Left" -> 90, "Gap" -> 16,
        "Bracket" -> RGBColor["#BEC2C5"], "BracketKind" -> "Modern", "BracketWidth" -> 1.2, "Page" -> RGBColor["#FCFCFC"],
        "Syntax" -> <|"User" -> RGBColor["#0C30C4"], "String" -> RGBColor["#666666"], "Local" -> RGBColor["#438958"]|>|>;
eraStyle["Mac2020"] = <|"Input" -> CanvasFont["Source Code Pro", 16.5, 700], "Output" -> CanvasFont["Source Code Pro", 16.5, 400], "Text" -> CanvasFont["Source Sans 3", 19], "Title" -> CanvasFont["Source Sans 3", 34, 600],
        "TitleColor" -> RGBColor["#C8321E"], "Label" -> CanvasFont["Source Sans 3", 12.5], "LabelColor" -> RGBColor["#3B6E92"], "LabelsAbove" -> False, "Left" -> 90, "Gap" -> 16,
        "Bracket" -> RGBColor["#BEC2C5"], "BracketKind" -> "Modern", "BracketWidth" -> 1.2, "Ink" -> RGBColor["#080808"],
        "Syntax" -> <|"User" -> RGBColor["#0C30C4"], "String" -> RGBColor["#666666"], "Local" -> RGBColor["#3C8A8A"]|>|>;
eraStyle["Dark2024"] = <|"Input" -> CanvasFont["Source Code Pro", 16.5, 700], "Output" -> CanvasFont["Source Code Pro", 16.5, 400], "Text" -> CanvasFont["Source Sans 3", 19], "Title" -> CanvasFont["Source Sans 3", 34, 600],
        "TitleColor" -> RGBColor["#F79268"], "Label" -> CanvasFont["Source Sans 3", 12.5], "LabelColor" -> RGBColor["#A1A1A1"], "LabelsAbove" -> False, "Left" -> 90, "Gap" -> 16,
        "Bracket" -> RGBColor["#5A5A5A"], "BracketKind" -> "Modern", "BracketWidth" -> 1.2, "LightDark" -> "Dark", "Page" -> RGBColor["#1B1B1B"], "Ink" -> RGBColor["#EDEDED"], "OutputInk" -> RGBColor["#E2E2E2"],
        "Syntax" -> <|"User" -> RGBColor["#8FB0FF"], "String" -> RGBColor["#BDBDBD"], "Local" -> RGBColor["#90D4E9"]|>|>;

(* NotebookEra[name] is an era as a value: its chrome, content rectangle, display and cell style, all
   keys of one association.  NotebookEra[name, key -> value, ...] changes some of them (another font,
   a darker page); NotebookEra[] lists the names.  NotebookSession takes either through "Era". *)
NotebookEra[] = {"Mac1988", "NeXT1988", "Win1991", "Win1996", "Mac1999", "WinXP2004", "MacOSX2007", "Yosemite2014", "BigSur2020", "Dark2024"};
NotebookEra[name_String, changes : (_Rule | _RuleDelayed) ...] /; MemberQ[NotebookEra[], name] := Join[
    <|"Name" -> name, "LightDark" -> "Light", "Page" -> White, "Ink" -> Black, "OutputInk" -> Automatic, "Extras" -> None, "Typeset" -> ! MemberQ[{"Mac1988", "NeXT1988", "Win1991"}, name], "TitleColor" -> Automatic, "Syntax" -> None,
        "Version" -> Lookup[<|"Mac1988" -> 1, "NeXT1988" -> 1, "Win1991" -> 2, "Win1996" -> 3, "Mac1999" -> 4, "WinXP2004" -> 5, "MacOSX2007" -> 6, "Yosemite2014" -> 10,
            "BigSur2020" -> 12, "Dark2024" -> 14|>, name, 15]|>,
    eraStyle[eraLook[name]], eraWindow[name], <|changes|>];
NotebookEra[era_Association, changes : (_Rule | _RuleDelayed) ...] := Join[era, <|changes|>];
NotebookEra::unknown = "`1` is not a notebook era; NotebookEra[] lists them.";
NotebookEra[name_String, ___] := (Message[NotebookEra::unknown, name]; $Failed);

eraLook[name_] := Replace[name, {"NeXT1988" -> "Mac1988", "WinXP2004" -> "Mac1999", "MacOSX2007" -> "Mac2007", "Yosemite2014" -> "Mac2014", "BigSur2020" -> "Mac2020"}];
window[chrome_, content_, pixel_, depth_, extra___Rule] := <|"Chrome" -> chrome, "Content" -> content, "Pixel" -> pixel, "Depth" -> depth, extra|>;
eraWindow["Mac1988"] := window[mac1988Chrome, Function[{lw, lh}, {13, 49, lw - 43, lh - 75}], 2, "Bit"];
eraWindow["NeXT1988"] := window[nextChrome, Function[{lw, lh}, {122 + 19, 12 + 40, lw - 186 - 20, lh - 22 - 50}], 2, "Gray4"];
eraWindow["Win1991"] := window[win31Chrome, win31Content, 2, "Color"];
eraWindow["Win1996"] := window[win95Chrome, win95Content, 2, "Color", "Extras" -> Function[{lw, lh, t}, basicInputPalette[{lw - 118, 60}, t]]];
eraWindow["Mac1999"] := window[mac9Chrome, mac9Content, 2, "Color"];
eraWindow["WinXP2004"] := window[xpChrome, xpContent, 1.7, "Color"];
eraWindow["MacOSX2007"] := window[osxChrome["OSX"], osxContent["OSX"], 1.3, "Full"];
eraWindow["Yosemite2014"] := window[osxChrome["Yosemite"], osxContent["Yosemite"], 1.35, "Full"];
eraWindow["BigSur2020"] := window[osxChrome["BigSur"], osxContent["BigSur"], 1.35, "Full"];
eraWindow["Dark2024"] := window[osxChrome["Dark"], osxContent["Dark"], 1.35, "Full"];
