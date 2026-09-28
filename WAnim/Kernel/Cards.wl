(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{DictionaryCard, PhotoPrint, Counter, YearRuler}]


(* ::Section:: *)
(*Cards and instruments*)

(* ::Subsection:: *)
(*DictionaryCard*)

Options[DictionaryCard] = Join[{Position -> {1250, 330}, "Width" -> 590, "Usage" -> Automatic, "Note" -> Automatic, "Lines" -> 5,
    FontColor -> RGBColor["#0E0F11"], "NoteColor" -> RGBColor["#6B675F"], "RuleColor" -> RGBColor["#DD1100"], "Enter" -> "Rise", "EnterTime" -> 0.3}, $LayerOptions];

(* DictionaryCard["Symbol", {t0, t1}] presents a Wolfram Language symbol like a dictionary entry: the
   headword, a part-of-speech line with the version and year that coined it, and its usage, all looked
   up with WolframLanguageData (override with "Usage" / "Note"). *)
DictionaryCard[name_String, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[DictionaryCard]]},
    With[{usage = Replace[ov[o, "Usage"], Automatic :> symbolUsage[name]], note = Replace[ov[o, "Note"], Automatic :> symbolNote[name]]},
        makeLayer["DictionaryCard", {t0, t1 + ov[o, "ExitTime"]}, Function[t, dictionaryDraw[name, usage, note, t, {t0, t1}, o]]]]];

symbolUsage[name_] := With[{u = Quiet @ TimeConstrained[WolframLanguageData[name, "PlaintextUsage"], 10, $Failed]},
    If[StringQ[u], First @ StringSplit[u, "\n"], ""]];
symbolNote[name_] := With[{v = Quiet @ TimeConstrained[WolframLanguageData[name, {"VersionIntroduced", "DateIntroduced"}], 10, $Failed]},
    (* VersionIntroduced is a number (1, 10.2, ...) or a string; whole versions read "1.0" *)
    If[MatchQ[v, {_String | _ ? NumericQ, _DateObject}],
        "symbol \[CenterDot] since " <> With[{s = ToString[v[[1]]]}, If[StringContainsQ[s, "."], s, s <> ".0"]] <> ", " <> ToString[DateValue[v[[2]], "Year"]],
        "symbol"]];

dictionaryDraw[name_, usage_, note_, t_, {t0_, t1_}, o_] := Module[{p = layerPoint[ov[o, Position]], w = ov[o, "Width"], env, hf, uf, lines, lu},
    env = envelope[t, {t0, t1 + ov[o, "ExitTime"]}, o];
    hf = CanvasFont[$defaultFonts["Sans"], 70, 700];
    While[CanvasTextWidth[name, hf] > w && hf["Size"] > 30, hf["Size"] -= 2];
    uf = CanvasFont[$defaultFonts["Serif"], 30, 400];
    lines = Take[CanvasWrap[usage, uf, w], UpTo[ov[o, "Lines"]]];
    lu = localU[t, t0 + 0.15, t0 + 0.6];
    CanvasOpacity[env["Alpha"], CanvasTransform[CanvasTranslate[{0, env["Offset"]}], {
        CanvasRectangle[{p[[1]], p[[2]] - 70, 64 Min[1, env["Alpha"] + 0.001], 5}, ov[o, "RuleColor"]],
        CanvasText[name, p, hf, ov[o, FontColor]],
        CanvasText[note, p + {2, 46}, CanvasFont[$defaultFonts["Serif"], 30, 400, True], ov[o, "NoteColor"]],
        MapIndexed[CanvasText[#1, p + {2, 110 + 42 (#2[[1]] - 1)}, uf, ov[o, FontColor], Opacity -> Clip[lu Length[lines] - #2[[1]] + 1, {0, 1}]] &, lines]}]]];


(* ::Subsection:: *)
(*PhotoPrint*)

Options[PhotoPrint] = Join[{Position -> {1250, 150}, "Size" -> {590, 420}, "Tilt" -> -1.5, "Kicker" -> None, "KickerColor" -> RGBColor["#DD1100"],
    "Paper" -> RGBColor["#FBFAF6"], "Enter" -> "Pop", "EnterTime" -> 0.25}, $LayerOptions];

(* PhotoPrint[image, "caption", {t0, t1}] pins a photo or scan like a print: a white border, a soft
   shadow, a small "Kicker" line (e.g. "FROM THE ARCHIVE · 1981") and an italic caption, tilted by
   "Tilt" degrees.  The image is fitted inside "Size" at Position (top-left). *)
PhotoPrint[img_Image, cap_String, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[PhotoPrint]]},
    makeLayer["PhotoPrint", {t0, t1 + ov[o, "ExitTime"]}, Function[t, printDraw[img, cap, t, {t0, t1}, o]]]];

printDraw[img_, cap_, t_, {t0_, t1_}, o_] := Module[{p = layerPoint[ov[o, Position]], box = ov[o, "Size"], d = ImageDimensions[img], s, w, h, u, leave},
    s = Min[box[[1]] / d[[1]], box[[2]] / d[[2]]]; {w, h} = d s;
    u = Clip[Easing["OutBack", 1.3][localU[t, t0, t0 + ov[o, "EnterTime"]]], {0, 1}];
    leave = Easing["InCubic"][localU[t, t1, t1 + ov[o, "ExitTime"]]];
    CanvasOpacity[u (1 - leave), CanvasTransform[CanvasTranslate[{p[[1]] + w / 2, p[[2]] + h / 2 + 40 (1 - u)}] . CanvasRotate[ov[o, "Tilt"] Degree + 0.05 (1 - u)], {
        CanvasRectangle[{-w / 2 - 12, -h / 2 - 2, w + 24, h + 58}, Black, Opacity -> 0.12],
        CanvasRectangle[{-w / 2 - 12, -h / 2 - 12, w + 24, h + 58}, ov[o, "Paper"]],
        CanvasImage[img, {-w / 2, -h / 2, w, h}],
        If[StringQ[ov[o, "Kicker"]], CanvasText[ToUpperCase[ov[o, "Kicker"]], {-w / 2, h / 2 + 22}, CanvasFont[$defaultFonts["Sans"], 13, 700], ov[o, "KickerColor"], "Tracking" -> 2], {}],
        CanvasText[cap, {-w / 2, h / 2 + 40}, CanvasFont[$defaultFonts["Serif"], 16, 400, True], RGBColor["#3A3833"]]}]]];


(* ::Subsection:: *)
(*Counter*)

Options[Counter] = Join[{Position -> Automatic, Alignment -> Right, FontSize -> 88, FontWeight -> 700, FontColor -> RGBColor["#1B1B1B"],
    "Label" -> None, "LabelColor" -> RGBColor["#7C776E"], "ChangeColor" -> RGBColor["#DD1100"], "Format" -> Automatic, "Enter" -> "Fade", "EnterTime" -> 0.3}, $LayerOptions];

(* Counter[f, {t0, t1}] shows the number f[t], flushed right at Position (default: the top-right
   corner), turning "ChangeColor" while it is changing, with an optional tracked "Label" under it. *)
Counter[f_, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Counter]]},
    makeLayer["Counter", {t0, t1}, Function[t, counterDraw[f, t, {t0, t1}, o]]]];

counterDraw[f_, t_, {t0_, t1_}, o_] := Module[{p = Replace[ov[o, Position], Automatic :> {$CanvasSize[[1]] - 96, 118}], n = f[t], moving, al = ov[o, Alignment]},
    moving = n =!= f[t - 0.02];
    CanvasOpacity[envelope[t, {t0, t1}, o]["Alpha"], {
        CanvasText[Replace[ov[o, "Format"], Automatic -> (ToString[NumberForm[#, DigitBlock -> 3]] &)][n], layerPoint[p], layerFont[o],
            If[moving, Blend[{ov[o, FontColor], ov[o, "ChangeColor"]}, 0.85], ov[o, FontColor]], Alignment -> al],
        If[StringQ[ov[o, "Label"]], CanvasText[ToUpperCase[ov[o, "Label"]], layerPoint[p] + {0, 0.39 ov[o, FontSize]},
            CanvasFont[$defaultFonts["Sans"], 17, 600], ov[o, "LabelColor"], Alignment -> al, "Tracking" -> 3], {}]}]];


(* ::Subsection:: *)
(*YearRuler*)

Options[YearRuler] = Join[{"Range" -> {1978, 2027}, "Every" -> 5, "Marks" -> {}, Position -> Automatic, "Width" -> Automatic,
    "Pulse" -> None, "LineColor" -> RGBColor["#9A958C"], "MarkColor" -> RGBColor["#DD1100"], FontColor -> RGBColor["#1B1B1B"], "Enter" -> "Fade", "EnterTime" -> 0.5}, $LayerOptions];

(* YearRuler[{{t, year}, ...}, {t0, t1}] is a timeline of years along the bottom of the frame whose
   marker jumps to each key's year at its time.  "Marks" -> {{year, "label"}, ...} places release ticks
   that appear once the marker passes them; "Pulse" -> track makes the marker beat. *)
YearRuler[keys_List, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[YearRuler]]},
    makeLayer["YearRuler", {t0, t1}, Function[t, rulerDraw[keys, t, {t0, t1}, o]]]];

markerYear[keys_, t_] := Fold[If[t < #2[[1]], #1, #1 + (#2[[2]] - #1) Easing["OutExpo"][localU[t, #2[[1]], #2[[1]] + 0.4]]] &, keys[[1, 2]], keys];
rulerDraw[keys_, t_, {t0_, t1_}, o_] := Module[{W = $CanvasSize[[1]], y0, x0, x1, X, my, yr = ov[o, "Range"], lc = ov[o, "LineColor"], mc = ov[o, "MarkColor"]},
    {x0, y0} = Replace[ov[o, Position], Automatic -> {96, $CanvasSize[[2]] - 54}];
    x1 = x0 + Replace[ov[o, "Width"], Automatic -> W - 2 x0];
    X = x0 + (# - yr[[1]]) / (yr[[2]] - yr[[1]]) (x1 - x0) &;
    my = markerYear[keys, t];
    CanvasOpacity[envelope[t, {t0, t1}, o]["Alpha"], {
        CanvasLine[{{x0, y0}, {x1, y0}}, lc, "Thickness" -> 1.5],
        Table[{CanvasLine[{{X[y], y0 - 6}, {X[y], y0 + 6}}, lc, "Thickness" -> 1.5], CanvasText[ToString[y], {X[y], y0 + 26}, CanvasFont[$defaultFonts["Mono"], 15], lc, Alignment -> Center]},
            {y, ov[o, "Every"] Ceiling[yr[[1]] / ov[o, "Every"]], yr[[2]], ov[o, "Every"]}],
        CanvasLine[{{X[keys[[1, 2]]], y0}, {X[my], y0}}, mc, "Thickness" -> 3],
        Table[If[m[[1]] > my + 0.01, Nothing, {CanvasDisk[{X[m[[1]]], y0}, 4.5, mc], CanvasText[m[[2]], {X[m[[1]]], y0 - 14}, CanvasFont[$defaultFonts["Mono"], 14, 600], ov[o, FontColor], Alignment -> Center, Opacity -> 0.85]}], {m, ov[o, "Marks"]}],
        CanvasDisk[{X[my], y0}, 8 + If[ov[o, "Pulse"] === None, 0, 3 TrackPulse[ov[o, "Pulse"], 20][t]], mc]}]];
