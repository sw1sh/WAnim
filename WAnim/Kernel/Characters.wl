(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Spikey, AutomatonTape, WordWall}]


(* ::Section:: *)
(*Spikey*)

Options[Spikey] = elementOptions[{Position -> {1790, 930}, "Radius" -> 46, "Version" -> 15, "Display" -> Automatic, "Pulse" -> None,
    "BeatsPerCycle" -> 4, "Dance" -> 1, "Spin" -> 1.8, "Face" -> False, "Raise" -> 0, "Blink" -> False, "Enter" -> "Pop", "EnterTime" -> 0.3}];

(* Spikey[{t0, t1}] is the Wolfram mascot, dancing: it spins, sways each beat ("BeatsPerCycle" beats per
   cycle), hops, and squashes on each onset of "Pulse" (a Track, e.g. the kick).  It is the Spikey of its
   "Version", exactly as Mathematica drew it: the stellated icosahedron of 1.0, the hyperbolic dodecahedra
   of 2 to 13 and the rhombic ones since, from the paclet's Spikeys asset (scripts/make_spikeys.wls, from
   MathematicaSpikey.wl).  A version without a model of its own shows the nearest one.  "Display" -> "1Bit"
   or "Gray" draws it as a one-bit or greyscale display would.  "Version" and "Display" may be functions
   of time, so one Spikey lives through the eras.  "Face" -> True gives it eyes, a smile, arms and legs;
   "Raise" (0-1) lifts its right hand and "Blink" -> True shuts its eyes.  Position, "Radius", "Dance",
   "Raise" and "Blink" may be functions of time too: Spikey can walk, grow and wave. *)
Spikey[{t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, Spikey]},
    makeElement["Spikey", {t0, t1}, Function[t, spikeyDraw[t, {t0, t1}, drawOptions[{opts}, Spikey, t]]]]];

(* the models: <|"Graphics", "Options", "Period"|>, centred, of radius 1, a five-fold axis vertical, their
   coordinates packed as Integer16 in units of 1/10000 *)
spikeyDirectory[] := PacletObject["WolframInstitute/WAnim"]["AssetLocation", "Spikeys"];
spikeyVersions[] := spikeyVersions[] = Sort[ToExpression /@ FileBaseName /@ FileNames["*.wxf", spikeyDirectory[]]];
spikeyVersion[v_] := First[Nearest[spikeyVersions[], Round[v]]];
spikeyModel[v_Integer] := spikeyModel[v] = With[{file = FileNameJoin[{spikeyDirectory[], ToString[v] <> ".wxf"}]}, With[{m = Import[file, "WXF"]},
    <|m, "Graphics" -> (m["Graphics"] /. na_NumericArray :> Normal[na] / 10000.), "Key" -> IntegerString[FileHash[file, "CRC32"], 36]|>]];

(* a view of a model, turned by spin degrees about the vertical and tilted towards the viewer, as an image
   px wide: rendered once, and kept on disk, so every kernel of a render shares it *)
spikeySprite[v_Integer, spin_Integer, tilt_Integer, px_Integer] := spikeySprite[v, spin, tilt, px] = Module[{file, m, img},
    (* named by the model's file and the view, so a changed model is drawn anew *)
    file = FileNameJoin[{$UserBaseDirectory, "ApplicationData", "WAnim", "Spikeys", StringRiffle[{ToString[v], spikeyModel[v]["Key"], "2", ToString[spin], ToString[tilt], ToString[px]}, "-"] <> ".png"}];
    If[FileExistsQ[file], Import[file],
        m = spikeyModel[v];
        img = Rasterize[Graphics3D[GeometricTransformation[m["Graphics"], RotationTransform[tilt Degree, {1, 0, 0}] . RotationTransform[spin Degree, {0, 1, 0}]],
            Sequence @@ m["Options"], Boxed -> False, SphericalRegion -> True, PlotRange -> 1.05 {{-1, 1}, {-1, 1}, {-1, 1}}, ViewPoint -> {0, 0, 100},
            ViewVertical -> {0, 1, 0}, ViewAngle -> 2 ArcTan[0.5 / 100], ImageSize -> px, Background -> None], "Image", Background -> None, ImageResolution -> 72];
        Quiet[CreateDirectory[DirectoryName[file], CreateIntermediateDirectories -> True]; Export[file, img]];
        img]];
(* as a one-bit or a four-grey display would show it *)
spikeyDisplay[img_, "1Bit"] := SetAlphaChannel[Binarize[ColorConvert[RemoveAlphaChannel[img, White], "Grayscale"], 0.5], AlphaChannel[img]];
spikeyDisplay[img_, "Gray"] := SetAlphaChannel[ImageApply[Round[3 #] / 3 &, ColorConvert[RemoveAlphaChannel[img, White], "Grayscale"]], AlphaChannel[img]];
spikeyDisplay[img_, _] := img;

spikeyDraw[t_, {t0_, t1_}, o_] := Module[{p = layerPoint[ov[o, Position]], r, kick, beat, d = ov[o, "Dance"], v, m, spin, px, img, env = envelope[t, {t0, t1}, o]},
    r = ov[o, "Radius"] env["Scale"];
    kick = If[ov[o, "Pulse"] === None, 0, d TrackPulse[ov[o, "Pulse"], 14][t]];
    beat = ov[o, "BeatsPerCycle"] t;
    v = spikeyVersion[ov[o, "Version"]]; m = spikeyModel[v];
    (* the spin, to 2 degrees, within the model's symmetry period; the image a little larger than drawn *)
    spin = 2 Round[Mod[ov[o, "Spin"] t / Degree, m["Period"]] / 2];
    px = 32 Ceiling[2.2 r / 32];
    If[r <= 0.5, {}, {
        If[TrueQ[ov[o, "Face"]], spikeyLimbs[p, r, t, ov[o, "Raise"]], {}],
        img = spikeyDisplay[spikeySprite[v, spin, 26, px], ov[o, "Display"]];
        CanvasTransform[CanvasTranslate[{p[[1]], p[[2]] - 0.12 r d Abs[Sin[Pi beat]]}] . CanvasRotate[0.22 d Sin[Pi beat]] . CanvasScale[{1 + 0.08 kick, 1 - 0.1 kick}],
            (* the image spans the model's box, 2.1 radii *)
            CanvasImage[img, {-1.05 r, -1.05 r, 2.1 r, 2.1 r}, Opacity -> env["Alpha"]]],
        If[TrueQ[ov[o, "Face"]], spikeyFace[p, r, TrueQ[ov[o, "Blink"]]], {}]}]];

(* legs stepping, the left arm relaxed, the right arm rising as "Raise" goes to 1 *)
spikeyLimbs[{cx_, cy_}, r_, t_, raise_] := With[{ink = RGBColor["#8A0A00"], w = 0.09 r, step = 0.08 r Sin[4 Pi t], hx = cx + r * (0.95 + 0.25 raise), hy = cy + r * (0.5 - 1.25 raise)},
    {CanvasLine[{{cx - 0.25 r, cy + 0.6 r}, {cx - 0.3 r, cy + 1.05 r + step}}, ink, "Thickness" -> w], CanvasLine[{{cx + 0.25 r, cy + 0.6 r}, {cx + 0.3 r, cy + 1.05 r - step}}, ink, "Thickness" -> w],
     CanvasLine[BezierFunction[{{cx - 0.7 r, cy + 0.1 r}, {cx - 1.05 r, cy + 0.35 r}, {cx - r, cy + 0.65 r}}] /@ Subdivide[0., 1., 12], ink, "Thickness" -> w],
     CanvasLine[BezierFunction[{{cx + 0.7 r, cy + 0.05 r}, {cx + 1.1 r, cy - 0.1 r raise}, {hx, hy}}] /@ Subdivide[0., 1., 12], ink, "Thickness" -> w],
     CanvasDisk[{hx, hy}, 0.11 r, ink]}];
(* two eyes (shut in a blink), a smile and blushing cheeks *)
spikeyFace[{cx_, cy_}, r_, blink_] := With[{ey = cy - 0.08 r, ex = 0.28 r, line = RGBColor["#3A0400"]},
    {Table[{CanvasTransform[CanvasTranslate[{cx + s ex, ey}] . CanvasScale[{1, If[blink, 0.13, 1.15]}], {CanvasDisk[{0, 0}, 0.2 r, White], CanvasDisk[{0, 0}, 0.2 r, line, "Stroke" -> 0.03 r]}],
        If[blink, {}, {CanvasDisk[{cx + s ex + 0.06 r, ey + 0.03 r}, 0.1 r, RGBColor["#111111"]], CanvasDisk[{cx + s ex + 0.1 r, ey - 0.02 r}, 0.035 r, White]}],
        CanvasTransform[CanvasTranslate[{cx + 0.5 s r, cy + 0.2 r}] . CanvasScale[{1, 0.6}], CanvasDisk[{0, 0}, 0.1 r, RGBColor[1, 0.47, 0.47], Opacity -> 0.55]]}, {s, {-1, 1}}],
     CanvasLine[Table[{cx, cy + 0.2 r} + 0.2 r {Cos[a], Sin[a]}, {a, 0.15 Pi, 0.85 Pi, 0.05 Pi}], line, "Thickness" -> 0.05 r]}];


(* ::Section:: *)
(*AutomatonTape*)

Options[AutomatonTape] = elementOptions[{Position -> {1712, 930}, "Length" -> 400, "CellSize" -> 8, "Rows" -> 13, "StepsPerCycle" -> 32, "Group" -> 4,
    "Label" -> Automatic, "Ink" -> RGBColor["#0E0F11"], "BitColor" -> RGBColor["#DD1100"], "HotColor" -> RGBColor["#FF3B1F"], "Steps" -> 4000,
    "Enter" -> "Fade", "Exit" -> "Fade"}];

(* AutomatonTape[rule, track, {t0, t1}] draws a cellular automaton turned on its side and fed into a
   read head at Position: each slice is one row of CellularAutomaton[rule] from a single cell (the
   centre +- ("Rows"-1)/2 cells), advancing "StepsPerCycle" rows per cycle.  The centre column is
   drawn in "BitColor", grouped in "Group"s whose last cell (a gate, in the film's melody) is a dot.
   When track is a Track, the note it plays under the head is named above the head -- the same Track
   that sounds; use None for a tape without a track. *)
AutomatonTape[rule_, track_, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, AutomatonTape]},
    With[{rows = CellularAutomaton[rule, {{1}, 0}, {{0, ov[o, "Steps"] - 1}, {-(ov[o, "Rows"] - 1) / 2, (ov[o, "Rows"] - 1) / 2}}]},
        makeElement["AutomatonTape", {t0, t1}, Function[t, tapeDraw[rule, rows, track, t, {t0, t1}, drawOptions[{opts}, AutomatonTape, t]]]]]];

noteName[m_Integer] := {"C", "C\[Sharp]", "D", "D\[Sharp]", "E", "F", "F\[Sharp]", "G", "G\[Sharp]", "A", "A\[Sharp]", "B"}[[Mod[m, 12] + 1]] <> ToString[Floor[m / 12] - 1];
noteName[x_] := ToString[x];
tapeDraw[rule_, rows_, track_, t_, span_, o_] := Module[{c = ov[o, "CellSize"], n = ov[o, "Rows"], mid, head, cy, top, spu = ov[o, "StepsPerCycle"], g = ov[o, "Group"],
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
        If[ListQ[ev] && ev =!= {}, CanvasText[noteName[ev[[1]]["Value"]], {head - g c / 2, top - 8}, CanvasFont[defaultFont["Mono"], 15, 600], ov[o, "HotColor"], Alignment -> Center,
            Opacity -> 1 - 0.6 FractionalPart[t spu / g]], {}],
        CanvasRectangle[{head, top - 2, 1.5, n c + 4}, ov[o, "BitColor"], Opacity -> 0.45],
        CanvasText[Replace[ov[o, "Label"], Automatic -> "RULE " <> ToString[rule] <> " \[CenterDot] CENTRE COLUMN"], {head - len + 4, top - 8},
            CanvasFont[defaultFont["Sans"], 11, 600], RGBColor["#8B877F"], "Tracking" -> 2, Opacity -> 0.9]}]];


(* ::Section:: *)
(*WordWall*)

Options[WordWall] = elementOptions[{"Margin" -> {36, 30}, "Presence" -> 0, Background -> None, "Camera" -> None, "Emphasis" -> None, "Color" -> RGBColor["#B9B3A7"], "StrongColor" -> RGBColor["#2A2825"],
    "FlashColor" -> RGBColor["#DD1100"], "Origin" -> None, "FlightTime" -> 0.35, "FlightCount" -> 90, FontWeight -> 600, "Enter" -> "Cut", "Exit" -> "Cut"}];

(* WordWall[{{"word", weight, t}, ...}, {t0, t1}] lays every word out alphabetically in justified lines,
   like a dictionary page, each sized by its weight (e.g. a usage frequency, on a log scale) and fitted
   to fill the canvas; each word pops in at its time t, flashes "FlashColor" and settles.  "Presence"
   (0-1, or a function of time) takes the settled words from a faint texture to full strength.  Settled
   words are rasterized once per half unit, so a wall of thousands of words stays fast.  With "Origin" -> {x, y}
   the most prominent arriving words (up to "FlightCount" at a time) fly in an arc from that point
   to their place over "FlightTime", as if coming out of an output.  Give Background -> the colour
   beneath the wall (or a function of time) so the cached layer is opaque: much cheaper to draw.
   "Camera" -> f moves the page: f[t] is a canvas transform (CanvasTranslate, CanvasScale, ...) or None,
   for zooming onto words or letting the page fall away.  "Emphasis" -> f picks words out: f[t] is
   {test, strength} or None; the page dims by strength and the words for which test[word] is True
   stand out at full strength.  wall["Places"] says where each word sits: the canvas point at the
   middle of its letters, for pointing a camera at it. *)
WordWall[words_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, WordWall]},
    With[{placed = wallPlace[words, o]}, makeElement["WordWall", {t0, t1}, Function[t, wallDraw[placed, t, drawOptions[{opts}, WordWall, t]]],
        <|"Places" -> Association[#[[1]] -> {#[[5]] + #[[4]] / 2, #[[6]] - 0.3 #[[3]]} & /@ placed]|>]]];

wallSize[w_, k_] := k * (1 + 11 Clip[(Log10[Max[w, 10^-9]] + 7.2) / 6.8, {0, 1}]^3.1);
wallLayout[words_, k_, o_] := Module[{f = CanvasFont[defaultFont["Sans"], 1, weightNum[ov[o, FontWeight]]], mx, my, W, out = {}, line = {}, x, y, maxW, flush},
    {mx, my} = ov[o, "Margin"]; W = $canvasSize[[1]]; x = mx; y = my; maxW = W - 2 mx;
    flush[justify_] := If[line =!= {}, With[{lh = 1.02 Max[line[[All, 3]]], gaps = Length[line] - 1},
        With[{gap = If[justify && gaps > 0, (maxW - Total[line[[All, 4]]]) / gaps, 0.9 k]}, Module[{cx = mx},
            out = Join[out, ({#[[1]], #[[2]], #[[3]], #[[4]], cx, y + 0.8 lh, cx += #[[4]] + gap}[[;; 6]] &) /@ line]]];
        y += lh; line = {}; x = mx]];
    Do[With[{size = wallSize[w[[2]], k]}, With[{width = size CanvasTextWidth[w[[1]], f]},
        If[x + width > mx + maxW && line =!= {}, flush[True]]; AppendTo[line, {w[[1]], w[[3]], size, width}]; x += width + 0.9 k]],
        {w, SortBy[words, {ToLowerCase[StringDelete[#[[1]], "$"]] &, #[[1]] &}]}];
    flush[False]; {out, y + my}];
(* the largest base size that fits the canvas *)
wallPlace[words_, o_] := wallPlace[words, ov[o, "Margin"], ov[o, FontWeight], $canvasSize];
wallPlace[words_, margin_, weight_, size_] := wallPlace[words, margin, weight, size] = With[{o = {"Margin" -> margin, FontWeight -> weight}}, Module[{lo = 2., hi = 12.},
    Do[With[{m = (lo + hi) / 2}, If[wallLayout[words, m, o][[2]] > $canvasSize[[2]], hi = m, lo = m]], {18}];
    First @ wallLayout[words, lo, o]]];
wordDraw[{name_, at_, size_, width_, x_, y_}, t_, presence_, o_] := Module[{age = t - at, pop, heat, base, s},
    pop = If[age === Infinity, 1, Easing["OutBack", 2.2][localU[age, 0, 0.18]]]; heat = If[age === Infinity, 0, Exp[-1.6 age]];
    base = If[presence > 0.5, ov[o, "StrongColor"], ov[o, "Color"]];
    s = size (0.6 + 0.4 pop) (1 + 0.25 heat);
    CanvasText[name, {x + width (1 - s / size) / 2, y}, CanvasFont[defaultFont["Sans"], Round[4 s] / 4., weightNum[ov[o, FontWeight]]],
        If[heat > 0.02, Blend[{base, ov[o, "FlashColor"]}, heat], base], Opacity -> Clip[(0.18 + 0.82 presence) pop + 0.9 heat, {0, 1}]]];
wallLayer[placed_, cutoff_, presence_, o_, size_] := wallLayer[placed, cutoff, presence, o, size] = Rasterize[
    Graphics[canvasResolve[size, wordDraw[{#[[1]], #[[2]], #[[3]], #[[4]], #[[5]], #[[6]]}, Infinity, presence, o] & /@ Select[placed, #[[2]] <= cutoff &]],
        PlotRange -> {{0, size[[1]]}, {0, size[[2]]}}, ImageSize -> size[[1]], PlotRangePadding -> None, ImagePadding -> None], "Image", Background -> ov[o, Background]];
(* the settled layer is cached by its options, so colours changing over time are coarsened to a few steps *)
coarseColors[o_] := Replace[o, (r : Rule | RuleDelayed)[k_, c_ ? ColorQ] :> r[k, RGBColor @@ Round[List @@ ColorConvert[c, "RGB"], 1/12]], {1}];
(* Background -> colour (or a function of time) makes the settled layer opaque, the colour of what the
   wall sits on: a front end keeps a fresh copy of a transparent image every time it draws one, so a
   transparent full-frame layer would cost a frame's worth of memory per frame *)
wallDraw[placed_, t_, o_] := With[{cam = ov[o, "Camera"], emph = ov[o, "Emphasis"], bg = ov[o, Background]},
    {Which[cam === None || cam == IdentityMatrix[3], wallPage[placed, t, o, bg],
        (* near its resting size the page is moved as it is; closer, the words in view are drawn as type, so they stay sharp *)
        Norm[cam[[;; 2, 1]]] <= 1.3, {If[bg === None, {}, CanvasRectangle[{0, 0, $canvasSize[[1]], $canvasSize[[2]]}, bg]], CanvasTransform[cam, wallPage[placed, t, o, bg]]},
        True, {If[bg === None, {}, CanvasRectangle[{0, 0, $canvasSize[[1]], $canvasSize[[2]]}, bg]],
            CanvasTransform[cam, With[{pr = presenceAt[o, t]}, wordDraw[#, t, pr, o] & /@ Select[placed, #[[2]] <= t && inView[cam, #] &]]]}],
     If[emph === None || emph[[2]] <= 0, {}, {
        CanvasRectangle[{0, 0, $canvasSize[[1]], $canvasSize[[2]]}, Replace[bg, None -> Black], Opacity -> 0.6 emph[[2]]],
        CanvasOpacity[emph[[2]], CanvasTransform[Replace[cam, None -> IdentityMatrix[3]], wordDraw[#, Infinity, 1, o] & /@ Select[placed, #[[2]] <= t && TrueQ[emph[[1]][#[[1]]]] &]]]}],
     If[ov[o, "Origin"] === None, {}, flightDraw[placed, t, o]]}];
inView[m_, {_, _, size_, width_, x_, y_}] := With[{a = m . {x, y - size, 1.}, b = m . {x + width, y + 0.3 size, 1.}},
    a[[1]] < $canvasSize[[1]] && b[[1]] > 0 && a[[2]] < $canvasSize[[2]] && b[[2]] > 0];
presenceAt[o_, t_] := Round[ov[o, "Presence"], 0.001];
(* the page at rest: settled words from the cache, arriving ones drawn as they pop in *)
wallPage[placed_, t_, o_, bg_] := With[{pr = presenceAt[o, t], cutoff = Floor[2 (t - 4)] / 2., lo = coarseColors[Join[{Background -> bg}, o]]},
    {If[AnyTrue[placed, #[[2]] <= cutoff &], CanvasImage[wallLayer[placed, cutoff, pr, lo, $canvasSize], {0, 0, $canvasSize[[1]], $canvasSize[[2]]}], {}],
     wordDraw[#, t, pr, o] & /@ Select[placed, cutoff < #[[2]] <= t &]}];
(* the biggest words still on their way fly from "From" to their place *)
flightDraw[placed_, t_, o_] := With[{from = layerPoint[ov[o, "Origin"]], ft = ov[o, "FlightTime"]},
    Map[With[{u = localU[t, #[[2]] - ft, #[[2]]]}, With[{e = Easing["InOutCubic"][u]},
        CanvasText[#[[1]], {from[[1]] + (#[[5]] - from[[1]]) e, from[[2]] + (#[[6]] - from[[2]]) e - (120 + 200 Mod[Hash[#[[1]]] 10^-6, 1]) Sin[Pi e]},
            CanvasFont[defaultFont["Sans"], 14 + (#[[3]] - 14) e, 700], ov[o, "FlashColor"], Opacity -> 0.95 Sin[Pi Min[1, 1.2 u]]]]] &,
        Take[ReverseSortBy[Select[placed, #[[2]] - ft < t < #[[2]] &], #[[3]] &], UpTo[ov[o, "FlightCount"]]]]];
