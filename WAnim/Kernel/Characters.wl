(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Spikey, AutomatonTape, WordWall}]


(* ::Section:: *)
(*Spikey*)

Options[Spikey] = Join[{Position -> {1790, 930}, "Radius" -> 46, "Form" -> "Stellated", "Style" -> "Red", "Pulse" -> None,
    "BeatsPerUnit" -> 4, "Dance" -> 1, "Spin" -> 1.8, "Enter" -> "Pop", "EnterTime" -> 0.3}, $LayerOptions];

(* Spikey[{t0, t1}] is the Wolfram mascot, dancing: it spins, sways each beat ("BeatsPerUnit" beats per
   timeline unit), hops, and squashes on each onset of "Pulse" (a Track, e.g. the kick).  Its "Form"
   follows the versions -- "Stellated" (the 1.0 stellated icosahedron), "Spiked" (a spiked
   dodecahedron, 2-9), "Hexecontahedron" (10+) -- and its "Style" the displays: "1Bit", "Gray",
   "Classic" (lilac) or "Red".  Geometry comes from PolyhedronData. *)
Spikey[{t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Spikey]]},
    makeLayer["Spikey", {t0, t1}, Function[t, spikeyDraw[t, {t0, t1}, o]]]];

polyUnit[name_] := polyUnit[name] = With[{v = N[PolyhedronData[name, "VertexCoordinates"]]}, {v / Max[Norm /@ v], PolyhedronData[name, "FaceIndices"]}];
spikeyFaces["Hexecontahedron", spike_] := With[{p = polyUnit["RhombicHexecontahedron"]},
    Map[p[[1]][[#]] (1 + If[Norm[p[[1]][[#]]] > 0.99, 0.25 spike, 0]) &, p[[2]], {2}] /. x_List /; Length[x] == 3 && VectorQ[x, NumericQ] :> x];
spikeyFaces[form_, spike_] := With[{p = polyUnit[If[form === "Stellated", "Icosahedron", "Dodecahedron"]], h = If[form === "Stellated", 1.9, 1.75] + 0.35 spike},
    Flatten[Table[With[{pts = p[[1]][[f]], c = Mean[p[[1]][[f]]]},
        Table[{pts[[k]], pts[[Mod[k, Length[pts]] + 1]], h Norm[c] Normalize[c]}, {k, Length[pts]}]], {f, p[[2]]}], 1]];
spikeyShade["1Bit", lam_] := Which[lam > 0.66, White, lam > 0.4, GrayLevel[0.54], True, Black];
spikeyShade["Gray", lam_] := Which[lam > 0.7, White, lam > 0.45, GrayLevel[0.72], lam > 0.25, GrayLevel[0.41], True, Black];
spikeyShade["Classic", lam_] := Blend[{Blend[{RGBColor["#3C3C9A"], RGBColor["#F2B0C8"]}, lam], White}, 0.6 lam^4];
spikeyShade[_, lam_] := Blend[{Blend[{RGBColor["#5A0600"], RGBColor["#DD1100"]}, Clip[1.4 lam, {0, 1}]], RGBColor["#FF9A80"]}, lam^6];

spikeyDraw[t_, {t0_, t1_}, o_] := Module[{p = layerPoint[ov[o, Position]], r, kick, beat, d = ov[o, "Dance"], ay, ax, rot, light = Normalize[{-0.5, 0.7, 0.9}], style = ov[o, "Style"], polys},
    r = ov[o, "Radius"] envelope[t, {t0, t1}, o]["Scale"];
    kick = If[ov[o, "Pulse"] === None, 0, d TrackPulse[ov[o, "Pulse"], 14][t]];
    beat = ov[o, "BeatsPerUnit"] t; ay = ov[o, "Spin"] t; ax = 0.45 + 0.15 Sin[1.3 t];
    rot[{x_, y_, z_}] := With[{x1 = x Cos[ay] + z Sin[ay], z1 = z Cos[ay] - x Sin[ay]}, {x1, y Cos[ax] - z1 Sin[ax], y Sin[ax] + z1 Cos[ax]}];
    polys = SortBy[Select[{#, Normalize[Cross[#[[2]] - #[[1]], #[[3]] - #[[1]]]]} & /@ Map[rot, spikeyFaces[ov[o, "Form"], kick], {2}], #[[2, 3]] > -0.05 &], Mean[#[[1, All, 3]]] &];
    If[r <= 0.5, {}, CanvasTransform[CanvasTranslate[{p[[1]], p[[2]] - 0.12 r d Abs[Sin[Pi beat]]}] . CanvasRotate[0.22 d Sin[Pi beat]] . CanvasScale[{1 + 0.08 kick, 1 - 0.1 kick}],
        Map[With[{lam = Clip[0.25 + 0.75 Max[0, #[[2]] . light], {0, 1}], pts = {r #[[1]], -r #[[2]]} & /@ #[[1]]}, With[{c = spikeyShade[style, lam]},
            {CanvasPolygon[pts, c], CanvasPolygon[pts, If[MemberQ[{"1Bit", "Gray"}, style], Black, Blend[{c, Black}, 0.35]], "Stroke" -> If[style === "1Bit", 1.2, 0.8]]}]] &, polys]]]];


(* ::Section:: *)
(*AutomatonTape*)

Options[AutomatonTape] = Join[{Position -> {1712, 930}, "Length" -> 400, "CellSize" -> 8, "Rows" -> 13, "StepsPerUnit" -> 32, "Group" -> 4,
    "Label" -> Automatic, "Ink" -> RGBColor["#0E0F11"], "BitColor" -> RGBColor["#DD1100"], "HotColor" -> RGBColor["#FF3B1F"], "Steps" -> 4000,
    "Enter" -> "Fade", "Exit" -> "Fade"}, $LayerOptions];

(* AutomatonTape[rule, track, {t0, t1}] draws a cellular automaton turned on its side and fed into a
   read head at Position: each slice is one row of CellularAutomaton[rule] from a single cell (the
   centre +- ("Rows"-1)/2 cells), advancing "StepsPerUnit" rows per timeline unit.  The centre column is
   drawn in "BitColor", grouped in "Group"s whose last cell (a gate, in the film's melody) is a dot.
   When track is a Track, the note it plays under the head is named above the head -- the same Track
   that sounds; use None for a tape without a track. *)
AutomatonTape[rule_, track_, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[AutomatonTape]]},
    With[{rows = CellularAutomaton[rule, {{1}, 0}, {{0, ov[o, "Steps"] - 1}, {-(ov[o, "Rows"] - 1) / 2, (ov[o, "Rows"] - 1) / 2}}]},
        makeLayer["AutomatonTape", {t0, t1}, Function[t, tapeDraw[rule, rows, track, t, {t0, t1}, o]]]]];

noteName[m_Integer] := {"C", "C\[Sharp]", "D", "D\[Sharp]", "E", "F", "F\[Sharp]", "G", "G\[Sharp]", "A", "A\[Sharp]", "B"}[[Mod[m, 12] + 1]] <> ToString[Floor[m / 12] - 1];
noteName[x_] := ToString[x];
tapeDraw[rule_, rows_, track_, t_, span_, o_] := Module[{c = ov[o, "CellSize"], n = ov[o, "Rows"], mid, head, cy, top, spu = ov[o, "StepsPerUnit"], g = ov[o, "Group"],
    tNow, s, ev, ink = ov[o, "Ink"], len = ov[o, "Length"]},
    {head, cy} = layerPoint[ov[o, Position]]; mid = (n + 1) / 2; top = cy - n c / 2; tNow = spu t;
    s = Floor[t spu / g];
    ev = If[track === None, {}, Quiet @ track["Onsets", s g / spu, (s + 1) g / spu]];
    CanvasOpacity[envelope[t, span, o]["Alpha"], {
        Table[With[{x = head - (k - tNow) c - c, row = rows[[k + 1]]}, With[{a = Clip[(x - head + len) / 90, {0, 1}]}, {
            Table[If[j == mid || row[[j]] == 0, Nothing, CanvasRectangle[{x + 1, top + (j - 1) c + 1, c - 2, c - 2}, ink, Opacity -> 0.13 a (1 - Abs[j - mid] / (mid + 1))]], {j, n}],
            With[{bit = row[[mid]], on = Floor[k / g] == s && ev =!= {}, yc = top + (mid - 1) c}, Which[
                Mod[k, g] == g - 1, CanvasDisk[{x + c / 2, yc + c / 2}, If[bit == 1, 0.35 c, 0.2 c], If[bit == 1, ov[o, "BitColor"], ink], Opacity -> If[bit == 1, 0.85, 0.12] a],
                bit == 1, CanvasRectangle[{x + 0.5, yc + 0.5, c - 1, c - 1}, If[on, ov[o, "HotColor"], ov[o, "BitColor"]], Opacity -> a],
                True, CanvasRectangle[{x + 1.5, yc + 1.5, c - 3, c - 3}, ink, "Stroke" -> 1, Opacity -> 0.22 a]]]}]], {k, Floor[tNow], Min[Floor[tNow] + Ceiling[len / c], Length[rows] - 1]}],
        If[ListQ[ev] && ev =!= {}, CanvasText[noteName[ev[[1]]["Value"]], {head - g c / 2, top - 8}, CanvasFont[$defaultFonts["Mono"], 15, 600], ov[o, "HotColor"], Alignment -> Center,
            Opacity -> 1 - 0.6 FractionalPart[t spu / g]], {}],
        CanvasRectangle[{head, top - 2, 1.5, n c + 4}, ov[o, "BitColor"], Opacity -> 0.45],
        CanvasText[Replace[ov[o, "Label"], Automatic -> "RULE " <> ToString[rule] <> " \[CenterDot] CENTRE COLUMN"], {head - len + 4, top - 8},
            CanvasFont[$defaultFonts["Sans"], 11, 600], RGBColor["#8B877F"], "Tracking" -> 2, Opacity -> 0.9]}]];


(* ::Section:: *)
(*WordWall*)

Options[WordWall] = Join[{"Margin" -> {36, 30}, "Presence" -> 0, "Color" -> RGBColor["#B9B3A7"], "StrongColor" -> RGBColor["#2A2825"],
    "FlashColor" -> RGBColor["#DD1100"], "From" -> None, "FlightTime" -> 0.35, "FlightCount" -> 90, FontWeight -> 600, "Enter" -> "Cut", "Exit" -> "Cut"}, $LayerOptions];

(* WordWall[{{"word", weight, t}, ...}, {t0, t1}] lays every word out alphabetically in justified lines,
   like a dictionary page, each sized by its weight (e.g. a usage frequency, on a log scale) and fitted
   to fill the canvas; each word pops in at its time t, flashes "FlashColor" and settles.  "Presence"
   (0-1, or a function of time) takes the settled words from a faint texture to full strength.  Settled
   words are rasterized once per half unit, so a wall of thousands of words stays fast.  With "From" -> {x, y}
   the most prominent arriving words (up to "FlightCount" at a time) fly in an arc from that point
   to their place over "FlightTime", as if coming out of an output. *)
WordWall[words_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[WordWall]]},
    With[{placed = wallPlace[words, o]}, makeLayer["WordWall", {t0, t1}, Function[t, wallDraw[placed, t, o]]]]];

wallSize[w_, k_] := k (1 + 11 Clip[(Log10[Max[w, 10^-9]] + 7.2) / 6.8, {0, 1}]^3.1);
wallLayout[words_, k_, o_] := Module[{f = CanvasFont[$defaultFonts["Sans"], 1, weightNum[ov[o, FontWeight]]], mx, my, W, out = {}, line = {}, x, y, maxW, flush},
    {mx, my} = ov[o, "Margin"]; W = $CanvasSize[[1]]; x = mx; y = my; maxW = W - 2 mx;
    flush[justify_] := If[line =!= {}, With[{lh = 1.02 Max[line[[All, 3]]], gaps = Length[line] - 1},
        With[{gap = If[justify && gaps > 0, (maxW - Total[line[[All, 4]]]) / gaps, 0.9 k]}, Module[{cx = mx},
            out = Join[out, ({#[[1]], #[[2]], #[[3]], #[[4]], cx, y + 0.8 lh, cx += #[[4]] + gap}[[;; 6]] &) /@ line]]];
        y += lh; line = {}; x = mx]];
    Do[With[{size = wallSize[w[[2]], k]}, With[{width = size CanvasTextWidth[w[[1]], f]},
        If[x + width > mx + maxW && line =!= {}, flush[True]]; AppendTo[line, {w[[1]], w[[3]], size, width}]; x += width + 0.9 k]],
        {w, SortBy[words, {ToLowerCase[StringDelete[#[[1]], "$"]] &, #[[1]] &}]}];
    flush[False]; {out, y + my}];
(* the largest base size that fits the canvas *)
wallPlace[words_, o_] := Module[{lo = 2., hi = 12.},
    Do[With[{m = (lo + hi) / 2}, If[wallLayout[words, m, o][[2]] > $CanvasSize[[2]], hi = m, lo = m]], {18}];
    First @ wallLayout[words, lo, o]];
wordDraw[{name_, at_, size_, width_, x_, y_}, t_, presence_, o_] := Module[{age = t - at, pop, heat, base, s},
    pop = If[age === Infinity, 1, Easing["OutBack", 2.2][localU[age, 0, 0.18]]]; heat = If[age === Infinity, 0, Exp[-1.6 age]];
    base = If[presence > 0.5, ov[o, "StrongColor"], ov[o, "Color"]];
    s = size (0.6 + 0.4 pop) (1 + 0.25 heat);
    CanvasText[name, {x + width (1 - s / size) / 2, y}, CanvasFont[$defaultFonts["Sans"], Round[4 s] / 4., weightNum[ov[o, FontWeight]]],
        If[heat > 0.02, Blend[{base, ov[o, "FlashColor"]}, heat], base], Opacity -> Clip[(0.18 + 0.82 presence) pop + 0.9 heat, {0, 1}]]];
wallLayer[placed_, cutoff_, presence_, o_, size_] := wallLayer[placed, cutoff, presence, o, size] = Rasterize[
    Graphics[CanvasBlock[size, wordDraw[{#[[1]], #[[2]], #[[3]], #[[4]], #[[5]], #[[6]]}, Infinity, presence, o] & /@ Select[placed, #[[2]] <= cutoff &]],
        PlotRange -> {{0, size[[1]]}, {0, size[[2]]}}, ImageSize -> size[[1]], PlotRangePadding -> None, ImagePadding -> None], "Image", Background -> None];
wallDraw[placed_, t_, o_] := With[{pr = Round[If[NumericQ[ov[o, "Presence"]], ov[o, "Presence"], ov[o, "Presence"][t]], 0.001], cutoff = Floor[2 (t - 4)] / 2.},
    {If[AnyTrue[placed, #[[2]] <= cutoff &], CanvasImage[wallLayer[placed, cutoff, pr, o, $CanvasSize], {0, 0, $CanvasSize[[1]], $CanvasSize[[2]]}], {}],
     wordDraw[#, t, pr, o] & /@ Select[placed, cutoff < #[[2]] <= t &],
     If[ov[o, "From"] === None, {}, flightDraw[placed, t, o]]}];
(* the biggest words still on their way fly from "From" to their place *)
flightDraw[placed_, t_, o_] := With[{from = layerPoint[ov[o, "From"]], ft = ov[o, "FlightTime"]},
    Map[With[{u = localU[t, #[[2]] - ft, #[[2]]]}, With[{e = Easing["InOutCubic"][u]},
        CanvasText[#[[1]], {from[[1]] + (#[[5]] - from[[1]]) e, from[[2]] + (#[[6]] - from[[2]]) e - (120 + 200 Mod[Hash[#[[1]]] 10^-6, 1]) Sin[Pi e]},
            CanvasFont[$defaultFonts["Sans"], 14 + (#[[3]] - 14) e, 700], ov[o, "FlashColor"], Opacity -> 0.95 Sin[Pi Min[1, 1.2 u]]]]] &,
        Take[ReverseSortBy[Select[placed, #[[2]] - ft < t < #[[2]] &], #[[3]] &], UpTo[ov[o, "FlightCount"]]]]];
