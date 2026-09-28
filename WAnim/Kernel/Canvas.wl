(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{
    CanvasBlock, CanvasTransform, CanvasOpacity, CanvasTranslate, CanvasScale, CanvasRotate, $CanvasSize,
    CanvasRectangle, CanvasPolygon, CanvasLine, CanvasDisk, CanvasImage, CanvasGradient, CanvasClip,
    CanvasFont, CanvasText, CanvasTextWidth, CanvasWrap, $CanvasFixedAdvance,
    TypedText, OrderedDither
}]

(* shared with Timeline.wl (CanvasScreen places a screen by its canvas rectangle) *)
PackageScoped[{cxf, cscaleX}]


(* ::Section:: *)
(*A canvas-2D drawing kit*)

(* Pixel-exact 2D drawing the way an HTML canvas does it, emitting ordinary WL graphics primitives.
   Coordinates are CANVAS coordinates -- x right, y DOWN, in pixels of a $CanvasSize frame (the
   Timeline sets it while drawing a frame) -- so a scene written for a canvas ports line by line.
   CanvasTransform / CanvasOpacity nest like ctx.save + translate / scale / rotate / globalAlpha:

     CanvasTransform[CanvasTranslate[{960, 540}] . CanvasScale[2], {CanvasRectangle[{-10, -10, 20, 20}, Red], ...}]

   Text is anchored on its ALPHABETIC BASELINE, measured with per-face advance tables built once
   through the front end, and scales with the transform (plain Scale / GeometricTransformation
   would move Text without resizing it). *)

$CanvasSize = {1920, 1080};
$canvasXF = IdentityMatrix[3];
$canvasAlpha = 1.;
(* Font sizes and line widths are emitted as Scaled fractions of the enclosing graphic's width, so a
   frame keeps its proportions at any ImageSize (a live player, a thumbnail); $canvasRef is that width
   in WL units -- the canvas width, or a CanvasClip inset's own width inside one. *)
$canvasRef := $CanvasSize[[1]];

SetAttributes[{CanvasBlock, CanvasTransform, CanvasOpacity, CanvasClip}, HoldRest];
(* a fresh canvas of the given size: own coordinates, identity transform, full opacity *)
CanvasBlock[size : {_, _}, body_] := Block[{$CanvasSize = size, $canvasXF = IdentityMatrix[3], $canvasAlpha = 1., $canvasRef = size[[1]]}, body];
CanvasTransform[m_ ? MatrixQ, body_] := Block[{$canvasXF = $canvasXF . m}, body];
CanvasTransform[tf_TransformationFunction, body_] := CanvasTransform[TransformationMatrix[tf], body];
CanvasOpacity[a_, body_] := Block[{$canvasAlpha = $canvasAlpha a}, body];

CanvasTranslate[{dx_, dy_}] := {{1, 0, dx}, {0, 1, dy}, {0, 0, 1}};
CanvasScale[s_ ? NumericQ] := CanvasScale[{s, s}];
CanvasScale[{sx_, sy_}] := {{sx, 0, 0}, {0, sy, 0}, {0, 0, 1}};
CanvasScale[s_, {cx_, cy_}] := CanvasTranslate[{cx, cy}] . CanvasScale[s] . CanvasTranslate[{-cx, -cy}];   (* about a point *)
CanvasRotate[a_] := {{Cos[a], -Sin[a], 0}, {Sin[a], Cos[a], 0}, {0, 0, 1}};   (* clockwise on screen, like ctx.rotate *)

(* canvas point -> WL point *)
cxf[{x_, y_}] := With[{p = $canvasXF . {x, y, 1.}}, {p[[1]], $CanvasSize[[2]] - p[[2]]}];
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
CanvasRectangle[{x_, y_, w_, h_}, c_, opts : OptionsPattern[]] := With[{a = OptionValue[Opacity], s = OptionValue["Stroke"], r = OptionValue["Radius"]},
    Which[
        r > 0,   (* exact when the transform is a translation / uniform scale *)
        With[{rect = Rectangle[cxf[{x, y + h}], cxf[{x + w, y}], RoundingRadius -> Min[r, w / 2, h / 2] cscale[]]},
            If[s === None, {EdgeForm[], FaceForm[paint[c, a]], rect}, {FaceForm[], EdgeForm[{paint[c, a], thick[s]}], rect}]],   (* EdgeForm takes the same Scaled thickness *)
        s === None, {EdgeForm[], FaceForm[paint[c, a]], Polygon[cxf /@ {{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}}]},
        True, {paint[c, a], thick[s], Line[cxf /@ {{x, y}, {x + w, y}, {x + w, y + h}, {x, y + h}, {x, y}}]}
    ]];
Options[CanvasPolygon] = {Opacity -> 1, "Stroke" -> None};
CanvasPolygon[pts_, c_, opts : OptionsPattern[]] := With[{a = OptionValue[Opacity], s = OptionValue["Stroke"]},
    If[s === None, {EdgeForm[], FaceForm[paint[c, a]], Polygon[cxf /@ pts]},
        {paint[c, a], thick[s], JoinForm["Round"], Line[cxf /@ Append[pts, First[pts]]]}]];
Options[CanvasLine] = {Opacity -> 1, "Thickness" -> 1};
CanvasLine[pts_, c_, opts : OptionsPattern[]] := {paint[c, OptionValue[Opacity]], thick[OptionValue["Thickness"]], CapForm["Round"], Line[cxf /@ pts]};
Options[CanvasDisk] = {Opacity -> 1, "Stroke" -> None};
CanvasDisk[{x_, y_}, r_, c_, opts : OptionsPattern[]] := With[{p = cxf[{x, y}], rr = {r cscaleX[], r cscaleY[]}},
    If[OptionValue["Stroke"] === None, {EdgeForm[], FaceForm[paint[c, OptionValue[Opacity]]], Disk[p, rr]},
        {paint[c, OptionValue[Opacity]], thick[OptionValue["Stroke"]], Circle[p, rr]}]];

(* a colour fading across a rectangle: stops {{u, opacity}, ...} along "Horizontal" or "Vertical",
   drawn as thin strips (LinearGradientFilling has no per-stop opacity) *)
Options[CanvasGradient] = {"Steps" -> 24};
CanvasGradient[{x_, y_, w_, h_}, dir_, c_, stops_, opts : OptionsPattern[]] := With[{n = OptionValue["Steps"], f = Interpolation[stops, InterpolationOrder -> 1]},
    Table[With[{u0 = (i - 1) / n, a = f[(i - 1 / 2) / n]},
        If[dir === "Horizontal", CanvasRectangle[{x + w u0, y, w / n + 0.6, h}, c, Opacity -> a], CanvasRectangle[{x, y + h u0, w, h / n + 0.6}, c, Opacity -> a]]],
        {i, n}]];

(* CanvasGradient[rect, dir, {{u, colour}, ...}] blends colours instead, exactly, as vertex-coloured
   bands; dir may also be "Diagonal" (top-left to bottom-right) *)
CanvasGradient[{x_, y_, w_, h_}, dir_, stops : {{_ ? NumericQ, _ ? ColorQ | _String} ..}] := Module[
    {st = {#1, toColor[#2]} & @@@ SortBy[stops, First], col, us, vs},
    col[u_] := Blend[st, Clip[u, {st[[1, 1]], st[[-1, 1]]}]];
    us = Union[{0, 1}, Select[st[[All, 1]], 0 < # < 1 &]];
    Switch[dir,
        "Horizontal", Table[With[{a = us[[i]], b = us[[i + 1]]}, quad[{x + w a, y, w (b - a), h}, {col[a], col[b], col[b], col[a]}]], {i, Length[us] - 1}],
        "Vertical", Table[With[{a = us[[i]], b = us[[i + 1]]}, quad[{x, y + h a, w, h (b - a)}, {col[a], col[a], col[b], col[b]}]], {i, Length[us] - 1}],
        _, vs = Range[0, 1, 1 / 8];
        Table[With[{a = vs[[i]], b = vs[[i + 1]], c = vs[[j]], d = vs[[j + 1]]},
            quad[{x + w a, y + h c, w (b - a), h (d - c)}, col /@ ({a + c, b + c, b + d, a + d} / 2)]], {i, 8}, {j, 8}]]];
(* a rectangle whose corners (tl, tr, br, bl) carry colours; a hair oversized so bands meet without seams *)
quad[{x_, y_, w_, h_}, cs_] := {If[$canvasAlpha < 1, cop[], Nothing], EdgeForm[], Polygon[cxf /@ {{x, y}, {x + w + 0.4, y}, {x + w + 0.4, y + h + 0.4}, {x, y + h + 0.4}}, VertexColors -> cs]};

(* draw only inside a canvas rectangle (ctx.clip): the body goes into an inset whose plot range is the rect *)
CanvasClip[{x_, y_, w_, h_}, body_] := With[{p0 = cxf[{x, y + h}], p1 = cxf[{x + w, y}]},
    Inset[Graphics[Block[{$canvasRef = p1[[1]] - p0[[1]]}, body], PlotRange -> Transpose[{p0, p1}], PlotRangePadding -> None, ImagePadding -> None, PlotRangeClipping -> True,
        AspectRatio -> (p1[[2]] - p0[[2]]) / (p1[[1]] - p0[[1]])], p0, p0, p1[[1]] - p0[[1]]]];

(* an image into a canvas rect; "Fit" -> "Contain" letterboxes it like CSS object-fit; rotation is honoured *)
Options[CanvasImage] = {Opacity -> 1, "Fit" -> "Stretch"};
CanvasImage[img_Image, {x_, y_, w_, h_}, opts : OptionsPattern[]] := If[OptionValue["Fit"] === "Contain",
    With[{d = ImageDimensions[img]}, With[{s = Min[w / d[[1]], h / d[[2]]]},
        CanvasImage[img, {x + (w - d[[1]] s) / 2, y + (h - d[[2]] s) / 2, d[[1]] s, d[[2]] s}, Opacity -> OptionValue[Opacity]]]],
    With[{p = cxf[{x, y + h}], c = cxf[{x + w / 2, y + h / 2}], ang = cangle[]},
        {cop[OptionValue[Opacity]], If[Abs[ang] < 10^-6, #, Rotate[#, -ang, c]] &[Inset[img, p, {Left, Bottom}, {w cscaleX[], h cscaleY[]}]]}]];


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
$CanvasFixedAdvance = <|"VT323" -> 0.4|>;
$scaledFonts = True;
charAdv[f_, c_] := If[KeyExistsQ[$CanvasFixedAdvance, f["Family"]], $CanvasFixedAdvance[f["Family"]],
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
CanvasText[s_String, {x_, y_}, f_Association, c_, opts : OptionsPattern[]] := Module[{al = OptionValue[Alignment], a = OptionValue[Opacity], tr = OptionValue["Tracking"],
    fixed = KeyExistsQ[$CanvasFixedAdvance, f["Family"]], cx},
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
wrapPara[para_, f_, w_, "Code"] := Module[{out = {}, cur = ""},
    Do[If[CanvasTextWidth[StringTrim[cur <> p, WhitespaceCharacter .. ~~ EndOfString], f] > w && cur =!= "",
            AppendTo[out, StringTrim[cur, WhitespaceCharacter .. ~~ EndOfString]]; cur = StringTrim[p, StartOfString ~~ WhitespaceCharacter ..], cur = cur <> p],
        {p, StringCases[para, RegularExpression["[^ ,]+[ ,]*|[ ,]+"]]}];
    Append[out, cur]];


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
