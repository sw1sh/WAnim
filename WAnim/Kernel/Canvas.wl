(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{
    CanvasTransform, CanvasOpacity, CanvasTranslate, CanvasScale, CanvasRotate,
    CanvasRectangle, CanvasPolygon, CanvasLine, CanvasDisk, CanvasImage, CanvasGradient, CanvasClip, CanvasScreen,
    CanvasFont, CanvasText, CanvasTextWidth, CanvasWrap, CanvasTeX, CanvasTeXWidth,
    TypedText, OrderedDither
}]

(* the renderer draws canvas primitives on a canvas of its size *)
PackageScoped[{$canvasSize, canvasResolve, canvasPrimitiveQ, cxf, texShape}]


(* ::Section:: *)
(*A canvas-2D drawing kit*)

(* Pixel-exact 2D drawing the way an HTML canvas does it.  Coordinates are CANVAS coordinates -- x
   right, y DOWN, in pixels of the frame an AnimatedGraphics draws on (its "CanvasSize", 1920 x 1080
   by default) -- so a scene written for a canvas ports line by line.  The primitives are symbolic,
   like Graphics primitives: CanvasRectangle[...] stays as it is until a frame is drawn, when the
   renderer turns it into ordinary graphics in whatever coordinates the frame has (the canvas is laid
   over its PlotRange, the way Scaled coordinates are).  CanvasTransform / CanvasOpacity nest like
   ctx.save + translate / scale / rotate / globalAlpha:

     CanvasTransform[CanvasTranslate[{960, 540}] . CanvasScale[2], {CanvasRectangle[{-10, -10, 20, 20}, Red], ...}]

   Text is anchored on its ALPHABETIC BASELINE, measured with per-face advance tables built once
   through the front end, and scales with the transform. *)

$canvasSize = {1920, 1080};
$canvasXF = IdentityMatrix[3];
$canvasAlpha = 1.;
(* Font sizes and line widths are emitted as Scaled fractions of the enclosing graphic's width, so a
   frame keeps its proportions at any ImageSize (a thumbnail, a video frame); $canvasRef is that width
   in WL units -- the canvas width, or a CanvasClip inset's own width inside one. *)
$canvasRef := $canvasSize[[1]];

$canvasPattern = Alternatives @@ (Blank /@ {CanvasTransform, CanvasOpacity, CanvasClip, CanvasScreen, CanvasRectangle, CanvasPolygon, CanvasLine, CanvasDisk, CanvasImage, CanvasGradient, CanvasText, CanvasTeX});
canvasPrimitiveQ[e_] := ! FreeQ[e, $canvasPattern];

(* canvasResolve[size, expr] turns every canvas primitive in expr into graphics primitives, drawn on a
   fresh size canvas (identity transform, full opacity); anything else is left as it is *)
SetAttributes[canvasResolve, HoldRest];
canvasResolve[size : {_, _}, expr_] := Block[{$canvasSize = size, $canvasXF = IdentityMatrix[3], $canvasAlpha = 1., $canvasRef = size[[1]]}, rc[expr]];
rc[l_List] := rc /@ l;
rc[CanvasTransform[m_, body_]] := Block[{$canvasXF = $canvasXF . toMatrix[m]}, rc[body]];
rc[CanvasOpacity[a_, body_]] := Block[{$canvasAlpha = $canvasAlpha a}, rc[body]];
rc[CanvasClip[r_, body_]] := clipImpl[r, body];
rc[CanvasScreen[args__]] := screenImpl[args];
rc[CanvasRectangle[args__]] := rectImpl[args];
rc[CanvasPolygon[args__]] := polygonImpl[args];
rc[CanvasLine[args__]] := lineImpl[args];
rc[CanvasDisk[args__]] := diskImpl[args];
rc[CanvasImage[args__]] := imageImpl[args];
rc[CanvasGradient[args__]] := gradientImpl[args];
rc[CanvasText[args__]] := textImpl[args];
rc[CanvasTeX[args__]] := texImpl[args];
rc[x_] := x;
toMatrix[m_ ? MatrixQ] := m;
toMatrix[tf_TransformationFunction] := TransformationMatrix[tf];

CanvasTranslate[{dx_, dy_}] := {{1, 0, dx}, {0, 1, dy}, {0, 0, 1}};
CanvasScale[s_ ? NumericQ] := CanvasScale[{s, s}];
CanvasScale[{sx_, sy_}] := {{sx, 0, 0}, {0, sy, 0}, {0, 0, 1}};
CanvasScale[s_, {cx_, cy_}] := CanvasTranslate[{cx, cy}] . CanvasScale[s] . CanvasTranslate[{-cx, -cy}];   (* about a point *)
CanvasRotate[a_] := {{Cos[a], -Sin[a], 0}, {Sin[a], Cos[a], 0}, {0, 0, 1}};   (* clockwise on screen, like ctx.rotate *)

(* canvas point -> WL point *)
cxf[{x_, y_}] := With[{p = $canvasXF . {x, y, 1.}}, {p[[1]], $canvasSize[[2]] - p[[2]]}];
cscale[] := Sqrt[Abs[Det[$canvasXF[[;; 2, ;; 2]]]]];
cscaleX[] := Norm[$canvasXF[[;; 2, 1]]]; cscaleY[] := Norm[$canvasXF[[;; 2, 2]]];
cangle[] := ArcTan[$canvasXF[[1, 1]], $canvasXF[[2, 1]]];
cop[a_ : 1] := Opacity[Clip[$canvasAlpha a, {0, 1}]];
toColor[c_String] := RGBColor[c];
toColor[c_ ? ColorQ] := c;
thick[lw_] := Thickness[lw cscale[] / $canvasRef];


(* ::Section:: *)
(*Shapes*)

(* colour and opacity go together, as Opacity[a, colour] (FaceForm[...] for fills): a front end keeps
   something for every separate Opacity directive it meets at a new position, so translucent shapes
   that move would otherwise grow it every frame *)
paint[c_, a_ : 1] := With[{al = Clip[$canvasAlpha a, {0, 1}]}, If[al >= 1, toColor[c], Opacity[al, toColor[c]]]];

(* CanvasRectangle[{x, y, w, h}, colour]: filled, or outlined with "Stroke" -> width; "Radius" rounds the corners *)
Options[CanvasRectangle] = {Opacity -> 1, "Stroke" -> None, "Radius" -> 0};
rectImpl[{x_, y_, w_, h_}, c_, opts : OptionsPattern[CanvasRectangle]] := With[{a = OptionValue[CanvasRectangle, {opts}, Opacity], s = OptionValue[CanvasRectangle, {opts}, "Stroke"], r = OptionValue[CanvasRectangle, {opts}, "Radius"]},
    Which[
        r > 0,   (* exact when the transform is a translation / uniform scale *)
        With[{rect = Rectangle[cxf[{x, y + h}], cxf[{x + w, y}], RoundingRadius -> Min[r, w / 2, h / 2] cscale[]]},
            If[s === None, {EdgeForm[], FaceForm[paint[c, a]], rect}, {FaceForm[], EdgeForm[{paint[c, a], thick[s]}], rect}]],   (* EdgeForm takes the same Scaled thickness *)
        s === None, {EdgeForm[], FaceForm[paint[c, a]], Polygon[cxf /@ {{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}}]},
        True, {paint[c, a], thick[s], Line[cxf /@ {{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}, {x, y}}]}
    ]];
(* "Edge" -> colour outlines the face thinly in the same primitive: the seams of a mesh disappear, or show as lines *)
(* "VertexColors" -> {colour, ...} shades the face smoothly between colours at its corners *)
Options[CanvasPolygon] = {Opacity -> 1, "Stroke" -> None, "Edge" -> None, "VertexColors" -> None};
polygonImpl[pts_, c_, opts : OptionsPattern[CanvasPolygon]] := With[{a = OptionValue[CanvasPolygon, {opts}, Opacity], s = OptionValue[CanvasPolygon, {opts}, "Stroke"], e = OptionValue[CanvasPolygon, {opts}, "Edge"],
        vc = OptionValue[CanvasPolygon, {opts}, "VertexColors"]},
    Which[vc =!= None && s === None, {If[$canvasAlpha a < 1, cop[a], Nothing], EdgeForm[], Polygon[cxf /@ pts, VertexColors -> (toColor /@ vc)]},
      s === None, {If[e === None, EdgeForm[], EdgeForm[Directive[paint[e, a], AbsoluteThickness[0.6]]]], FaceForm[paint[c, a]], Polygon[cxf /@ pts]},
      True,
        {paint[c, a], thick[s], JoinForm["Round"], Line[cxf /@ Append[pts, First[pts]]]}]];
(* "Glow" -> r haloes a line, a disk or an outline: wider, fainter copies beneath it out to r pixels, as light
   bleeds around a bright stroke *)
Options[CanvasLine] = {Opacity -> 1, "Thickness" -> 1, "Glow" -> 0};
lineImpl[pts_, c_, opts : OptionsPattern[CanvasLine]] := With[{a = OptionValue[CanvasLine, {opts}, Opacity], w = OptionValue[CanvasLine, {opts}, "Thickness"], g = OptionValue[CanvasLine, {opts}, "Glow"]},
    {If[g > 0, Table[{paint[c, a 0.12 (1 - k / 5)], thick[w + 2 g k / 4], CapForm["Round"], JoinForm["Round"], Line[cxf /@ pts]}, {k, 4, 1, -1}], {}],
     paint[c, a], thick[w], CapForm["Round"], JoinForm["Round"], Line[cxf /@ pts]}];
Options[CanvasDisk] = {Opacity -> 1, "Stroke" -> None, "Glow" -> 0};
diskImpl[{x_, y_}, r_, c_, opts : OptionsPattern[CanvasDisk]] := With[{p = cxf[{x, y}], rr = {r cscaleX[], r cscaleY[]}, a = OptionValue[CanvasDisk, {opts}, Opacity],
        s = OptionValue[CanvasDisk, {opts}, "Stroke"], g = OptionValue[CanvasDisk, {opts}, "Glow"]},
    {If[g > 0, Table[With[{rk = r + g k / 4}, If[s === None, {EdgeForm[], FaceForm[paint[c, a 0.14 (1 - k / 5)]], Disk[p, {rk cscaleX[], rk cscaleY[]}]},
            {paint[c, a 0.12 (1 - k / 5)], thick[s + 2 g k / 4], Circle[p, rr]}]], {k, 4, 1, -1}], {}],
     If[s === None, {EdgeForm[], FaceForm[paint[c, a]], Disk[p, rr]}, {paint[c, a], thick[s], Circle[p, rr]}]}];

(* a colour fading across a rectangle: stops {{u, opacity}, ...} along "Horizontal" or "Vertical",
   drawn as thin strips (LinearGradientFilling has no per-stop opacity) *)
Options[CanvasGradient] = {"Steps" -> 24};
(* "Radial": from the centre of the rectangle out to its edge, as concentric rings (a glow, a vignette, a hot body) *)
gradientImpl[{x_, y_, w_, h_}, "Radial", c_, stops_, opts : OptionsPattern[CanvasGradient]] /; ! MatchQ[c, {{_ ? NumericQ, _} ..}] := With[{n = OptionValue[CanvasGradient, {opts}, "Steps"],
        f = Interpolation[stops, InterpolationOrder -> 1], cx = x + w / 2, cy = y + h / 2, th = Subdivide[0., 2 Pi, 72]},
    Table[With[{u0 = (i - 1) / n, u1 = i / n}, polygonImpl[Join[Transpose[{cx + w / 2 u1 Cos[th], cy + h / 2 u1 Sin[th]}], Reverse @ Transpose[{cx + w / 2 u0 Cos[th], cy + h / 2 u0 Sin[th]}]],
        c, Opacity -> f[(u0 + u1) / 2]]], {i, n}]];
gradientImpl[{x_, y_, w_, h_}, dir_, c_, stops_, opts : OptionsPattern[CanvasGradient]] /; ! MatchQ[c, {{_ ? NumericQ, _} ..}] := With[{n = OptionValue[CanvasGradient, {opts}, "Steps"], f = Interpolation[stops, InterpolationOrder -> 1]},
    Table[With[{u0 = (i - 1) / n, a = f[(i - 1 / 2) / n]},
        If[dir === "Horizontal", rectImpl[{x + w u0, y, w / n + 0.6, h}, c, Opacity -> a], rectImpl[{x, y + h u0, w, h / n + 0.6}, c, Opacity -> a]]],
        {i, n}]];

(* CanvasGradient[rect, dir, {{u, colour}, ...}] blends colours instead, exactly, as vertex-coloured
   bands; dir may also be "Diagonal" (top-left to bottom-right) *)
gradientImpl[{x_, y_, w_, h_}, dir_, stops : {{_ ? NumericQ, _ ? ColorQ | _String} ..}] := Module[
    {st = {#1, toColor[#2]} & @@@ SortBy[stops, First], col, us, vs},
    col[u_] := Blend[st, Clip[u, {st[[1, 1]], st[[-1, 1]]}]];
    us = Union[{0, 1}, Select[st[[All, 1]], 0 < # < 1 &]];
    Switch[dir,
        "Horizontal", Table[With[{a = us[[i]], b = us[[i + 1]]}, quad[{x + w a, y, w * (b - a), h}, {col[a], col[b], col[b], col[a]}]], {i, Length[us] - 1}],
        "Vertical", Table[With[{a = us[[i]], b = us[[i + 1]]}, quad[{x, y + h a, w, h * (b - a)}, {col[a], col[a], col[b], col[b]}]], {i, Length[us] - 1}],
        _, vs = Range[0, 1, 1 / 8];
        Table[With[{a = vs[[i]], b = vs[[i + 1]], c = vs[[j]], d = vs[[j + 1]]},
            quad[{x + w a, y + h c, w * (b - a), h * (d - c)}, col /@ ({a + c, b + c, b + d, a + d} / 2)]], {i, 8}, {j, 8}]]];
(* a rectangle whose corners (tl, tr, br, bl) carry colours; a hair oversized so bands meet without seams *)
quad[{x_, y_, w_, h_}, cs_] := {If[$canvasAlpha < 1, cop[], Nothing], EdgeForm[], Polygon[cxf /@ {{x, y}, {x + w + 0.4, y}, {x + w + 0.4, y + h + 0.4}, {x, y + h + 0.4}}, VertexColors -> cs]};

(* draw only inside a canvas rectangle (ctx.clip): the body goes into an inset whose plot range is the rect *)
clipImpl[{x_, y_, w_, h_}, body_] := With[{p0 = cxf[{x, y + h}], p1 = cxf[{x + w, y}]},
    Inset[Graphics[Block[{$canvasRef = p1[[1]] - p0[[1]]}, rc[body]], PlotRange -> Transpose[{p0, p1}], PlotRangePadding -> None, ImagePadding -> None, PlotRangeClipping -> True,
        AspectRatio -> (p1[[2]] - p0[[2]]) / (p1[[1]] - p0[[1]])], p0, p0, p1[[1]] - p0[[1]]]];

(* an image into a canvas rect; "Fit" -> "Contain" letterboxes it like CSS object-fit; rotation is honoured *)
Options[CanvasImage] = {Opacity -> 1, "Fit" -> "Stretch"};
imageImpl[img_Image, {x_, y_, w_, h_}, opts : OptionsPattern[CanvasImage]] := With[{a = OptionValue[CanvasImage, {opts}, Opacity]}, If[OptionValue[CanvasImage, {opts}, "Fit"] === "Contain",
    With[{d = ImageDimensions[img]}, With[{s = Min[w / d[[1]], h / d[[2]]]},
        imageImpl[img, {x + (w - d[[1]] s) / 2, y + (h - d[[2]] s) / 2, d[[1]] s, d[[2]] s}, Opacity -> a]]],
    With[{p = cxf[{x, y + h}], c = cxf[{x + w / 2, y + h / 2}], ang = cangle[]},
        {cop[a], If[Abs[ang] < 10^-6, #, Rotate[#, -ang, c]] &[Inset[faded[img, a $canvasAlpha], p, {Left, Bottom}, {w cscaleX[], h cscaleY[]}]]}]]];
(* Opacity does not reach an inset image, so a fading image carries its opacity in its own alpha channel *)
faded[img_, a_] := Which[a >= 0.999, img, a <= 0.001, SetAlphaChannel[img, 0],
    True, SetAlphaChannel[img, If[ImageChannels[img] == 4 || ImageChannels[img] == 2, ImageMultiply[AlphaChannel[img], a], ConstantImage[a, ImageDimensions[img], "Byte"]]]];


(* ::Section:: *)
(*Text*)

(* CanvasFont[family, size, weight, italic] with CSS numeric weights (300 light .. 900 black) *)
CanvasFont[family_String, size_, weight_ : 400, italic_ : False] := <|"Family" -> family, "Size" -> size, "Weight" -> weight, "Italic" -> TrueQ[italic]|>;
weightName[w_] := Which[w <= 300, "Light", w <= 400, "Plain", w <= 500, "Medium", w <= 600, "SemiBold", w <= 700, "Bold", True, "Black"];
styleOpts[f_, size_] := Sequence[FontFamily -> f["Family"], FontSize -> If[TrueQ[$scaledFonts], Scaled[size / $canvasRef], size], FontWeight -> weightName[f["Weight"]], FontSlant -> If[f["Italic"], "Italic", "Plain"]];

(* per face: "Desc" = line-box bottom below the baseline, "Adv" = advance of each character, both per
   1 px of size; measured once through the front end and cached per user *)
$metricsFile := FileNameJoin[{$UserBaseDirectory, "ApplicationData", "WAnim", "CanvasMetrics.wl"}];
$metrics := $metrics = If[FileExistsQ[$metricsFile], Get[$metricsFile], <||>];
saveMetrics[] := (Quiet @ CreateDirectory[DirectoryName[$metricsFile], CreateIntermediateDirectories -> True]; Put[$metrics, $metricsFile]);
faceKey[f_] := {f["Family"], weightName[f["Weight"]], f["Italic"]};
bbox[s_String, f_] := N @ Block[{$scaledFonts = False}, Rasterize[Style[s, styleOpts[f, 100]], "BoundingBox", ImageResolution -> 288]];   (* in points, i.e. px *)
$measuredChars = Characters @ StringJoin[FromCharacterCode /@ Range[32, 126], "\[Ellipsis]\[CenterDot]\[Rule]\[RightArrow]\[OpenCurlyQuote]\[CloseCurlyQuote]\[OpenCurlyDoubleQuote]\[CloseCurlyDoubleQuote]\[Dash]\[LongDash]\[Times]\[Integral]\[Degree]"];
measureFace[f_] := Module[{hb = bbox["H", f], adv},
    adv = AssociationMap[If[# === " ", (bbox["H H", f][[1]] - 2 hb[[1]]) / 100., bbox[#, f][[1]] / 100.] &, $measuredChars];   (* a lone space measures 0 *)
    $metrics[faceKey[f]] = <|"Desc" -> (hb[[2]] - hb[[3]]) / 100., "Adv" -> adv|>;
    saveMetrics[];
    $metrics[faceKey[f]]];
faceMetrics[f_] := Lookup[$metrics, Key[faceKey[f]], measureFace[f]];

(* Some faces are laid out differently by the front end than by a browser (VT323 ~18% wider):
   pin their advance per 1 px here and they are drawn glyph by glyph, centred in canvas cells. *)
$canvasFixedAdvance = <|"VT323" -> 0.4|>;
$scaledFonts = True;
charAdv[f_, c_] := If[KeyExistsQ[$canvasFixedAdvance, f["Family"]], $canvasFixedAdvance[f["Family"]],
    Lookup[faceMetrics[f]["Adv"], c, $metrics[faceKey[f]]["Adv", c] = bbox[c, f][[1]] / 100.]];

(* width in canvas px, like ctx.measureText (no kerning); "Tracking" adds letter spacing *)
CanvasTextWidth[s_String, f_Association, tracking_ : 0] := f["Size"] Total[charAdv[f, #] & /@ Characters[s]] + tracking Max[0, StringLength[s] - 1];

(* size follows the transform's horizontal scale, so glyph widths agree with positions even under a
   non-uniform scale (canvas squashes glyphs; WL Text cannot, so it shrinks them evenly) *)
(* sizes are snapped to steps of 1%: a front end keeps the glyphs it renders at every size it has
   seen, so text that grows or zooms continuously would make new ones every frame without bound *)
snapSize[s_ ? Positive] := 1.01^Round[Log[1.01, s]];
snapSize[s_] := s;
textPrim[s_, {x_, y_}, f_, c_, align_, a_] := Module[{size = snapSize[f["Size"] cscaleX[]], p = cxf[{x, y}], ang = cangle[]},
    With[{t = Text[Style[s, styleOpts[f, size], toColor[c]], p + {0, -faceMetrics[f]["Desc"] size}, {Switch[align, Center, 0, Right, 1, _, -1], -1}]},
        {cop[a], If[Abs[ang] < 10^-6, t, Rotate[t, -ang, p]]}]];

(* CanvasText[s, {x, y}, font, colour] draws s with its alphabetic baseline at canvas (x, y) *)
Options[CanvasText] = {Alignment -> Left, Opacity -> 1, "Tracking" -> 0};
textImpl[s_String, {x_, y_}, f_Association, c_, opts : OptionsPattern[CanvasText]] := Module[{al = OptionValue[CanvasText, {opts}, Alignment], a = OptionValue[CanvasText, {opts}, Opacity], tr = OptionValue[CanvasText, {opts}, "Tracking"],
    fixed = KeyExistsQ[$canvasFixedAdvance, f["Family"]], cx},
    Which[
        s === "", {},
        tr == 0 && ! fixed, textPrim[s, {x, y}, f, c, al, a],
        True,   (* glyph by glyph *)
        cx = Switch[al, Center, x - CanvasTextWidth[s, f, tr] / 2, Right, x - CanvasTextWidth[s, f, tr], _, x];
        Table[With[{adv = f["Size"] charAdv[f, ch]},
            {If[fixed, textPrim[ch, {cx + adv / 2, y}, f, c, Center, a], textPrim[ch, {cx, y}, f, c, Left, a]], cx += adv + tr}[[1]]], {ch, Characters[s]}]
    ]];

(* CanvasWrap[s, font, width] breaks s into lines no wider than width: at spaces ("Words"), or after
   spaces and commas keeping them at line ends ("Code", for long outputs); newlines start paragraphs *)
Options[CanvasWrap] = {"Break" -> "Words"};
CanvasWrap[s_String, f_Association, w_, opts : OptionsPattern[]] := Flatten @ Map[wrapPara[#, f, w, OptionValue["Break"]] &, StringSplit[s, "\n", All]];
wrapPara[para_, f_, w_, "Words"] := Module[{lines = {}, cur = ""},
    Do[With[{t = If[cur === "", wd, cur <> " " <> wd]}, If[CanvasTextWidth[t, f] > w && cur =!= "", AppendTo[lines, cur]; cur = wd, cur = t]], {wd, StringSplit[para]}];
    Append[lines, cur]];
(* code breaks after a space, a comma or an opening bracket, as the front end breaks it; a piece
   still wider than the line is cut where it must be *)
wrapPara[para_, f_, w_, "Code"] := Module[{out = {}, cur = ""},
    Do[If[CanvasTextWidth[StringTrim[cur <> p, WhitespaceCharacter .. ~~ EndOfString], f] > w && cur =!= "",
            AppendTo[out, StringTrim[cur, WhitespaceCharacter .. ~~ EndOfString]]; cur = StringTrim[p, StartOfString ~~ WhitespaceCharacter ..], cur = cur <> p];
        While[CanvasTextWidth[cur, f] > w && StringLength[cur] > 1,
            With[{k = Max[1, LengthWhile[Range[StringLength[cur]], CanvasTextWidth[StringTake[cur, #], f] <= w &]]}, AppendTo[out, StringTake[cur, k]]; cur = StringDrop[cur, k]]],
        {p, StringCases[para, RegularExpression["[^ ,\\[]+[ ,\\[]*|[ ,\\[]+"]]}];
    Append[out, cur]];


(* ::Section:: *)
(*TeX*)

(* CanvasTeX["tex", {x, y}, size, colour] typesets TeX math with MaTeX, its baseline at canvas (x, y), size px
   the size of its type; CanvasTeX["text $tex$ text", {x, y}, font, colour] sets text in a CanvasFont with the
   math between dollars typeset inline, on the same baseline.  Glyphs are polygons (even-odd, holes cut), so
   they draw on the GPU, crisp at any size, and fade with the canvas.  Alignment -> Left | Center | Right.
   A formula is typeset once and kept on disk, so the kernels that render a film share it; a kernel without
   MaTeX loaded loads it when a formula it needs is not there yet. *)
Options[CanvasTeX] = {Alignment -> Left, Opacity -> 1};
CanvasTeX::tex = "MaTeX could not typeset `1`.";
texImpl[s_String, {x_, y_}, size_ ? NumericQ, c_, opts : OptionsPattern[CanvasTeX]] := With[{sh = texShape[s], k = size / 12.},
    With[{x0 = Switch[OptionValue[CanvasTeX, {opts}, Alignment], Center, x - k sh["Width"] / 2, Right, x - k sh["Width"], _, x]},
        texGlyphs[sh, {x0, y}, k, c, OptionValue[CanvasTeX, {opts}, Opacity]]]];
texImpl[s_String, {x_, y_}, f_Association, c_, opts : OptionsPattern[CanvasTeX]] := Module[{pieces = texPieces[s], k = f["Size"] / 12. 1.08, w, cx, a = OptionValue[CanvasTeX, {opts}, Opacity]},
    w = Total[If[#[[2]], k texShape[#[[1]]]["Width"], CanvasTextWidth[#[[1]], f]] & /@ pieces];
    cx = Switch[OptionValue[CanvasTeX, {opts}, Alignment], Center, x - w / 2, Right, x - w, _, x];
    Map[If[#[[2]], With[{sh = texShape[#[[1]]]}, {texGlyphs[sh, {cx, y}, k, c, a], cx += k sh["Width"]}[[1]]],
        {textImpl[#[[1]], {cx, y}, f, c, Opacity -> a], cx += CanvasTextWidth[#[[1]], f]}[[1]]] &, pieces]];
(* text and $math$ pieces: {"piece", math?} *)
texPieces[s_] := MapIndexed[{#1, EvenQ[#2[[1]]]} &, StringSplit[s, "$", All]] // DeleteCases[{"", _}];
(* CanvasTeXWidth["tex", size] and CanvasTeXWidth["text $tex$", font]: the width CanvasTeX sets it in *)
CanvasTeXWidth[s_String, size_ ? NumericQ] := size / 12. texShape[s]["Width"];
CanvasTeXWidth[s_String, f_Association] := Total[If[#[[2]], f["Size"] / 12. 1.08 texShape[#[[1]]]["Width"], CanvasTextWidth[#[[1]], f]] & /@ texPieces[s]];
texGlyphs[sh_, {x_, y_}, k_, c_, a_] := {EdgeForm[], FaceForm[paint[c, a]], Polygon[cxf /@ ({x, y} + k {1, -1} # & /@ #) & /@ sh["Glyphs"]]};

(* a formula as glyph outlines in TeX points (12 pt type), the baseline at y = 0: <|"Glyphs", "Width"|> *)
texShape[s_String] := texShape[s] = Module[{file = FileNameJoin[{$UserBaseDirectory, "ApplicationData", "WAnim", "TeX", IntegerString[Hash[{s, 2}, "SHA256"], 36] <> ".wxf"}], g, base, h, sh},
    If[FileExistsQ[file], Return[Import[file, "WXF"], Module]];
    If[! MemberQ[$Packages, "MaTeX`"], Quiet @ Needs["MaTeX`"]];
    g = Quiet @ MaTeX`MaTeX[s, FontSize -> 12];
    (* what will not typeset is said once and drawn as nothing; kept in this session only, so a formula
       typeset where MaTeX works is not hidden by a kernel where it does not *)
    If[Head[g] =!= Graphics, If[$KernelID == 0, Message[CanvasTeX::tex, s]]; Return[<|"Glyphs" -> {}, "Width" -> 0.|>, Module]];
    h = OptionValue[Graphics, Options[g], PlotRange][[2, 2]];
    base = h Replace[OptionValue[Graphics, Options[g], BaselinePosition], {Scaled[b_] :> b, _ -> 0}];
    sh = <|"Glyphs" -> (Function[pt, {pt[[1]], pt[[2]] - base}] /@ # &) /@ texGlyphOutlines[First[g], OptionValue[Graphics, Options[g], PlotRange][[1, 2]]],
        "Width" -> OptionValue[Graphics, Options[g], PlotRange][[1, 2]]|>;
    Quiet[CreateDirectory[DirectoryName[file], CreateIntermediateDirectories -> True]; Export[file, sh, "WXF"]];
    sh];
(* the glyphs in drawing order; a stroke (a fraction's bar, a root's overline) is a JoinedCurve at the
   Thickness before it, a fraction of the formula's width, drawn here as a thin bar *)
texGlyphOutlines[prims_, width_] := Module[{th = 0.01, out = {}},
    Scan[Which[MatchQ[#, _Thickness], th = First[#],
        MatchQ[#, _JoinedCurve], out = Join[out, strokeBars[Cases[#, {_ ? NumericQ, _ ? NumericQ}, Infinity], th width]],
        MatchQ[#, _FilledCurve | _Polygon | _Rectangle], out = Join[out, texOutline[#]]] &,
        Flatten[{prims} /. Style[x_, st___] :> {st, x}]];
    out];
strokeBars[pts_, w_] := Table[With[{a = pts[[i]], b = pts[[i + 1]]}, With[{nv = w / 2 Normalize[{-(b - a)[[2]], (b - a)[[1]]}]}, {a + nv, b + nv, b - nv, a - nv}]], {i, Length[pts] - 1}];
(* each glyph as ONE closed path through all its rings, back to the first point after each: filled even-odd,
   its holes are holes *)
texOutline[FilledCurve[specs_, pts_, ___]] := {joinRings[MapThread[curveRing, {specs, pts}]]};
texOutline[FilledCurve[c_, ___]] := {joinRings[Cases[c, Line[p_] :> p, Infinity]]};
texOutline[Polygon[p_ ? MatrixQ, ___]] := {p};
texOutline[Rectangle[{x0_, y0_}, {x1_, y1_}, ___]] := {{{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}}};
texOutline[_] := {};
joinRings[rings_] := With[{r1 = First[rings]}, Join[r1, {First[r1]}, Join @@ ({#, {First[#], First[r1]}} & /@ Rest[rings] // Map[Join @@ # &])]];
(* a ring of FilledCurve's compact form: {type, n, degree} segments, 0 a line, 1 a Bezier curve; the first takes
   its start point too, each next continues from the last *)
curveRing[spec_, pts_] := Module[{i = 0, cur, out = {}},
    Do[With[{n = sg[[2]] - If[i == 0, 1, 0]},
        If[i == 0, cur = pts[[1]]; AppendTo[out, cur]; i = 1];
        With[{new = pts[[i + 1 ;; i + n]]},
            (* a run of Bezier pieces of the segment's degree, each from where the last ended *)
            If[sg[[1]] == 1, Do[out = Join[out, Rest[BezierFunction[Prepend[piece, Last[out]]] /@ Subdivide[0., 1., 8]]], {piece, Partition[new, Max[1, sg[[3]]]]}], out = Join[out, new]];
            cur = Last[new]; i += n]], {sg, spec}];
    out];


(* ::Section:: *)
(*Old screens: drawn at a low resolution, quantized, upscaled nearest-neighbour*)

(* CanvasScreen[{x, y, w, h}, f] is a display placed in a canvas rectangle, drawn by f[lw, lh] -- canvas
   primitives on the screen's own logical canvas, lw x lh = the rectangle / "Pixel" -- as an old
   display would show it:
     "Pixel" -> k       a logical pixel is k canvas pixels
     "Depth" -> "Full"  vector, just magnified (crisp at any zoom)
              | "Bit"   1-bit: luminance threshold (default 160/255), pictures should arrive pre-dithered
              | "Gray4" four greys (NeXT MegaPixel levels 0, 104, 184, 255)
              | "Color" rasterized at the low resolution, colour kept *)
Options[CanvasScreen] = {"Pixel" -> 2, "Depth" -> "Full", Background -> White, "Threshold" -> 160 / 255};
screenImpl[{x_, y_, w_, h_}, f_, opts : OptionsPattern[CanvasScreen]] := With[{k = OptionValue[CanvasScreen, {opts}, "Pixel"], depth = OptionValue[CanvasScreen, {opts}, "Depth"],
        bg = OptionValue[CanvasScreen, {opts}, Background], p0 = cxf[{x, y + h}], p1 = cxf[{x + w, y}]},
    With[{lw = Round[w / k], lh = Round[h / k], ow = p1[[1]] - p0[[1]], oh = p1[[2]] - p0[[2]]},
        With[{prims = canvasResolve[{lw, lh}, f[lw, lh]]},
            If[depth === "Full",
                Inset[Graphics[prims, PlotRange -> {{0, lw}, {0, lh}}, ImageSize -> {ow, oh}, AspectRatio -> oh / ow, Background -> bg,
                    PlotRangePadding -> None, ImagePadding -> None, PlotRangeClipping -> True], p0, {Left, Bottom}, {ow, oh}],
                Inset[screenImage[prims, {lw, lh}, depth, bg, OptionValue[CanvasScreen, {opts}, "Threshold"], Ceiling[k]], p0, {Left, Bottom}, {ow, oh}]]]]];

(* the screen's picture: rasterized at its logical resolution, quantized, and blown up (nearest
   neighbour) to a fixed multiple of it -- independent of where and how big it is drawn, so an
   unchanged screen is the very same image from frame to frame.  The last few are kept: a front end
   keeps a copy of every distinct image it is sent, so a new image per frame would grow it *)
screenImage[prims_, {lw_, lh_}, depth_, bg_, thr_, m_] := With[{key = Hash[{prims, lw, lh, depth, bg, thr, m}]},
    Lookup[screenCache, key, With[{img = ImageResize[quantize[Rasterize[Graphics[prims, PlotRange -> {{0, lw}, {0, lh}}, ImageSize -> {lw, lh}, AspectRatio -> lh / lw,
            Background -> bg, PlotRangePadding -> None, ImagePadding -> None], "Image", ImageResolution -> 72], depth, thr], {lw, lh} m, Resampling -> "Nearest"]},
        screenCache = Take[Append[screenCache, key -> img], -Min[8, Length[screenCache] + 1]]; img]]];
screenCache = <||>;
quantize[img_, "Bit", thr_] := ColorConvert[Binarize[ColorConvert[img, "Grayscale"], thr], "RGB"]
quantize[img_, "Gray4", _] := ColorConvert[ImageApply[Which[# < 52 / 255, 0, # < 144 / 255, 104 / 255, # < 220 / 255, 184 / 255, True, 1] &, ColorConvert[img, "Grayscale"]], "RGB"]
quantize[img_, _, _] := img


(* ::Section:: *)
(*Small helpers every film needs*)

(* the part of s typed by fraction u of the way through (typing on the clock) *)
TypedText[s_String, u_] := StringTake[s, Floor[Clip[u, {0, 1}] StringLength[s] + 10^-6]];

(* an image reduced to 1 bit with ordered (4x4 Bayer) dithering, letterboxed into w x h on white:
   how a 1-bit display showed a picture *)
$bayer = {{0, 8, 2, 10}, {12, 4, 14, 6}, {3, 11, 1, 9}, {15, 7, 13, 5}};
OrderedDither[img_Image, {w_, h_}] := Module[{d = ImageDimensions[img], s, canvas, L},
    s = Min[w / d[[1]], h / d[[2]]];
    canvas = ImageCompose[ConstantImage[White, {Round[w], Round[h]}], ImageResize[RemoveAlphaChannel[img, White], Round[d s]]];
    L = ImageData[ColorConvert[canvas, "Grayscale"]];
    Image[MapIndexed[If[#1 > ($bayer[[Mod[#2[[1]] - 1, 4] + 1, Mod[#2[[2]] - 1, 4] + 1]] + 0.5) / 16, 1, 0] &, L, {2}], "Bit"]
];
