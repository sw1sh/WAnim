(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{AnimatedGraphics}]

PackageScoped[{directiveQ, summaryIcon, encodeVideo}]


(* ::Section:: *)
(*AnimatedGraphics: graphics with a time axis*)

(* AnimatedGraphics[content, opts] is Graphics in time.  Its content is ordinary graphics primitives
   and directives, and besides them:
     {t0, t1} -> x      x shown while t0 <= t < t1
     f                  a Function: f[t] is drawn at time t
     AnimatedGraphics   a nested one, on the same clock (under a span, on its own clock from t0)
     CanvasRectangle[...], TitleCard[...], ...   canvas primitives and elements, in frame pixels
     Track, Audio       the sound
   Functions read the clock of the AnimatedGraphics they are in; a nested AnimatedGraphics placed under
   a span starts its own clock at the span's start, which is also where its effects start playing.

   Like a Manim mobject it can also play effects in sequence: g["Play", "Creation"]["Wait"]["Play",
   "Rotate", Pi], each effect transforming the graphics at that moment of its own clock.

   Coordinates are the PlotRange's, as in Graphics (Automatic: the frame in canvas pixels when the
   content has canvas elements, otherwise the content's bounds).  Canvas primitives and elements are
   always drawn in canvas pixels, x right and y down, the "CanvasSize" canvas laid over the PlotRange.
   A nested AnimatedGraphics with a PlotRange of its own is drawn as an inset into its "Screen" (a canvas
   rectangle of the enclosing frame, the whole frame by default).  Sizes of lines and type given in
   pixels (AbsoluteThickness, FontSize, AbsolutePointSize) are pixels of the canvas, so a frame looks
   the same at any ImageSize.

   Time is in cycles: "CyclesPerSecond" is the tempo that turns it into seconds for sound and video
   (1 by default, a cycle a second).

   g[t] is the frame at time t as Graphics; Export["film.mp4", g] renders it, frames in parallel, with
   its sound; Video[g], AnimatedImage[g] and Audio[g] give it as those. *)

Options[AnimatedGraphics] = {
    PlotRange -> Automatic, "CanvasSize" -> {1920, 1080}, "Screen" -> Automatic, PlotTheme -> Automatic, Background -> Automatic, ImageSize -> Automatic,
    PlotRangePadding -> Automatic, BaseStyle -> {FontFamily -> "Source Sans 3", FontSize -> 72},
    "CyclesPerSecond" -> 1, FrameRate -> 60, "Foley" -> False, "Duration" -> Automatic
};

agDataQ[a_] := AssociationQ[a] && KeyExistsQ[a, "Primitives"] && KeyExistsQ[a, "Effects"];

(* directives: colours and the graphics directives, alone or in a list *)
$directivePattern = Alternatives @@ (Blank /@ {Directive, Opacity, Thickness, AbsoluteThickness, EdgeForm, FaceForm, PointSize, AbsolutePointSize, Dashing,
    AbsoluteDashing, Arrowheads, CapForm, JoinForm, Specularity, Glow, Lighting, LinearGradientFilling, RadialGradientFilling, ConicGradientFilling});
directiveQ[x_] := ColorQ[x] || MatchQ[x, $directivePattern] || (ListQ[x] && x =!= {} && AllTrue[x, directiveQ]);

AnimatedGraphics[s_String, dir : _ ? directiveQ : {White}, opts : OptionsPattern[]] :=
    AnimatedGraphics[texPrimitives[MaTeX`MaTeX[s], Flatten[{dir}]], dir, opts]["Apply", "Stretch", Automatic, 1]["Centralize"];
AnimatedGraphics[parts : {__String}, dir : _ ? directiveQ : {White}, opts : OptionsPattern[]] := texParts[parts, dir, {opts}];
AnimatedGraphics[g_Graphics, dir : _ ? directiveQ : {}, opts : OptionsPattern[]] := AnimatedGraphics[First[g], dir, opts];
(* (the condition keeps the definitions below, whose patterns look like content, from being rewritten) *)
AnimatedGraphics[content : Except[_Association ? agDataQ], dir : _ ? directiveQ : {}, opts : OptionsPattern[]] /; ! MatchQ[Unevaluated[content], _Pattern | _Blank | _BlankSequence | _BlankNullSequence | _PatternTest | _Condition] :=
    AnimatedGraphics[<|"Primitives" -> content, "Directive" -> dir, "Effects" -> {}, "Options" -> {opts}|>];

(* an option: as given, else the default *)
agOption[g_AnimatedGraphics, name_] := Replace[agGiven[g, name], _Missing :> OptionValue[AnimatedGraphics, name]];
agGiven[AnimatedGraphics[a_], name_] := FirstCase[a["Options"], (Rule | RuleDelayed)[name, v_] :> v, Missing[]];


(* ::Section:: *)
(*Properties and geometry*)

(g : AnimatedGraphics[a_ ? agDataQ])["Primitives"] := a["Primitives"];
(g : AnimatedGraphics[a_ ? agDataQ])["Directive"] := Replace[a["Directive"], {ds___} :> Directive[ds]];
(g : AnimatedGraphics[a_ ? agDataQ])["Effects"] := a["Effects"];
(g : AnimatedGraphics[a_ ? agDataQ])["Options"] := a["Options"];
(g : AnimatedGraphics[a_ ? agDataQ])["Properties"] := Join[{"Primitives", "Directive", "Effects", "Options", "Duration", "Bounds", "Center"},
    Complement[Keys[a], {"Primitives", "Directive", "Effects", "Options", "Draw", "Time"}]];
(* what an element knows about itself: its "Name", "Span", where a wall put its "Places", ... *)
(g : AnimatedGraphics[a_ ? agDataQ])[key_String] /; KeyExistsQ[a, key] := a[key];

(* the duration: the end of its last span or of its effects, whichever is later *)
(g : AnimatedGraphics[a_ ? agDataQ])["Duration"] := Replace[agGiven[g, "Duration"], _Missing :> Max[0, Total[#["Duration"] & /@ a["Effects"]], contentEnd[a["Primitives"]]]];
contentEnd[l_List] := Max[0, contentEnd /@ l];
contentEnd[(Rule | RuleDelayed)[{_, b_ ? NumericQ}, x_]] := b;
contentEnd[(Rule | RuleDelayed)[{a_ ? NumericQ, _}, g_AnimatedGraphics]] := a + g["Duration"];
contentEnd[g_AnimatedGraphics] := g["Duration"];
contentEnd[_] := 0;

setData[AnimatedGraphics[a_], key_, v_] := AnimatedGraphics[Append[a, key -> v]];
(g : AnimatedGraphics[a_ ? agDataQ])["SetPrimitives", p_] := setData[g, "Primitives", p];
(g : AnimatedGraphics[a_ ? agDataQ])["MapPrimitives", f_] := setData[g, "Primitives", f[a["Primitives"]]];
(g : AnimatedGraphics[a_ ? agDataQ])["SetDirective", d_] := setData[g, "Directive", d];
(g : AnimatedGraphics[a_ ? agDataQ])["Part", i_] := a["Primitives"][[i]];
(* the points of every primitive through f, nested ones too *)
(g : AnimatedGraphics[a_ ? agDataQ])["TransformPrimitives", f_] := g["MapPrimitives", ReplaceAll[{
    o_AnimatedGraphics :> o["TransformPrimitives", f],
    r_ /; RegionQ[r] && ! MatchQ[r, _List] :> TransformedRegion[r, f],
    points : {{__ ? NumericQ} ..} :> f[points]}]];
(g : AnimatedGraphics[a_ ? agDataQ])["Centralize"] := g["TransformPrimitives", TranslationTransform[-g["Center"]]];

$pointBasedQ[x_] := MatchQ[x, _FilledCurve | _JoinedCurve | _Line | _Polygon | _Point | _BezierCurve | _BSplineCurve | _Arrow];
primitiveBounds[x_] := Which[
    MatchQ[x, _AnimatedGraphics], x["Bounds"],
    directiveQ[x] || MatchQ[x, _Rule | _RuleDelayed | _Function | _String | _Text], Nothing,
    ListQ[x], With[{b = primitiveBounds /@ x}, If[b === {} || FreeQ[b, _ ? NumericQ], Nothing, combineBounds[Cases[b, {{_, _}, {_, _}} | {{_, _}, {_, _}, {_, _}}]]]],
    $pointBasedQ[x], CoordinateBounds[Cases[x, {Repeated[_ ? NumericQ, {2, 3}]}, Infinity]],
    RegionQ[x], RegionBounds[x],
    True, Quiet @ Check[RegionBounds[DiscretizeGraphics[x]], Nothing]];
combineBounds[{}] := {{-1, 1}, {-1, 1}};
combineBounds[bs_List] := Transpose[{Min /@ Transpose[bs[[All, All, 1]]], Max /@ Transpose[bs[[All, All, 2]]]}];
(* the bounds of what is drawn at the start (Manim's bounding box), from the point coordinates *)
(g : AnimatedGraphics[a_ ? agDataQ])["Bounds"] := Chop @ combineBounds[Cases[{primitiveBounds[at[a["Primitives"], 0]]}, {{_, _}, __}, {1}]];
(g : AnimatedGraphics[a_ ? agDataQ])["Center"] := Mean /@ g["Bounds"];
(g : AnimatedGraphics[a_ ? agDataQ])["Corners"] := With[{b = g["Bounds"]},
    <|{-1, -1} -> {b[[1, 1]], b[[2, 1]]}, {1, -1} -> {b[[1, 2]], b[[2, 1]]}, {1, 1} -> {b[[1, 2]], b[[2, 2]]}, {-1, 1} -> {b[[1, 1]], b[[2, 2]]}|>];
(g : AnimatedGraphics[a_ ? agDataQ])["Width"] := -Subtract @@ g["Bounds"][[1]];
(g : AnimatedGraphics[a_ ? agDataQ])["Height"] := -Subtract @@ g["Bounds"][[2]];
(* a rectangle around it, buff away from its bounds (Manim's SurroundingRectangle) *)
(g : AnimatedGraphics[a_ ? agDataQ])["SurroundingRectangle", buff_ : 0.1, dir_ : RGBColor["#FFFF00"]] := With[{b = g["Bounds"]},
    AnimatedGraphics[Line[{{b[[1, 1]] - buff, b[[2, 1]] - buff}, {b[[1, 2]] + buff, b[[2, 1]] - buff}, {b[[1, 2]] + buff, b[[2, 2]] + buff},
        {b[[1, 1]] - buff, b[[2, 2]] + buff}, {b[[1, 1]] - buff, b[[2, 1]] - buff}}], {dir, AbsoluteThickness[4]}]];


(* ::Section:: *)
(*TeX*)

(* MaTeX glyphs, each run keeping its colour (\color{red}{...}); runs with no colour of their own
   inherit the object's directive *)
maTeXColor[FaceForm[c_, ___]] := c;
maTeXColor[c_ ? ColorQ] := c;
maTeXStyleColor[s_Style, default_] := FirstCase[s, FaceForm[c_] :> c, FirstCase[Rest[List @@ s], _ ? ColorQ, default, Infinity], Infinity];
decodeCurve[curve_FilledCurve] := GeometricFunctions`DecodeFilledCurve[curve];
decodeCurve[curve_JoinedCurve] := GeometricFunctions`DecodeJoinedCurve[curve];
decodeCurve[p_] := p;
coloredPairs[expr_, color_] := Which[
    MatchQ[expr, _Style], coloredPairs[First[expr], maTeXStyleColor[expr, color]],
    ListQ[expr], Module[{c = color, acc = {}}, Scan[If[MatchQ[#, _FaceForm | _ ? ColorQ], c = maTeXColor[#], acc = Join[acc, coloredPairs[#, c]]] &, expr]; acc],
    MatchQ[expr, _FilledCurve | _JoinedCurve | _Polygon | _Line | _Rectangle | _Disk], {{color, expr}},
    True, {}];
texPrimitives[graphics_, default_] := Module[{prev = default, out = {}},
    Do[If[pair[[1]] =!= prev, out = Join[out, Flatten[{pair[[1]]}]]; prev = pair[[1]]]; AppendTo[out, decodeCurve[pair[[2]]]],
        {pair, coloredPairs[First[graphics], default]}];
    out];

(* AnimatedGraphics[{"tex", "tex", ...}] typesets the parts as ONE formula (Manim's MathTex with several
   strings), one nested object per part, in place: g["Part", i] is part i.  Each part is tagged with its
   own colour in the TeX, then the glyphs are grouped by it.  "FontSize" is Manim's font size (48 by
   default), in math units, centred at the origin. *)
texParts[parts_, dir_, opts_] := Module[{g, pairs, groups, all, tf, fs = Lookup[Association[opts], "FontSize", 48]},
    g = MaTeX`MaTeX[StringJoin[MapIndexed["{\\color[RGB]{" <> ToString[#2[[1]]] <> ",0,0}" <> #1 <> "}" &, parts]], "Preamble" -> {"\\usepackage{xcolor}"}];
    pairs = coloredPairs[First[g], None];
    groups = Table[decodeCurve /@ Cases[pairs, {c_ /; ColorQ[c] && Round[255 First[ColorConvert[c, "RGB"]]] == i, p_} :> p], {i, Length[parts]}];
    all = AnimatedGraphics[Flatten[groups]];
    tf = ScalingTransform[{1, 1} 0.06 fs / 48] @* TranslationTransform[-all["Center"]];
    AnimatedGraphics[AnimatedGraphics[#, dir]["TransformPrimitives", tf] & /@ groups, dir, Sequence @@ FilterRules[opts, Except["FontSize"]]]];


(* ::Section:: *)
(*Effects*)

(g : AnimatedGraphics[a_ ? agDataQ])["Play", eff_AnimationEffect] := setData[g, "Effects", Append[a["Effects"], eff]];
(g : AnimatedGraphics[a_ ? agDataQ])["Play", name_String, args___] := g["Play", AnimationEffect[name, args]];
(g : AnimatedGraphics[a_ ? agDataQ])["Wait", args___] := g["Play", "Wait", args];
(* an effect applied at once, as if it had played to its end *)
(g : AnimatedGraphics[a_ ? agDataQ])["Apply", name_String, args___] := With[{eff = AnimationEffect[name, args]},
    eff["Function"][<|"Object" -> g, "t" -> eff["Duration"], "T" -> g["Duration"] + eff["Duration"]|>]];
(* effect eff at time t of its run *)
(g : AnimatedGraphics[a_ ? agDataQ])[eff_AnimationEffect, t_ : 0, T_ : 0] := eff["Function"] @ <|
    "Object" -> g, "T" -> T, "t" -> If[eff["Reverse"], Max[eff["Duration"] - t, 0], Min[t, eff["Duration"]]]|>;

(* the graphics at time T of its own clock: what its content shows then, nested ones at their own
   times, then its effects played in order up to T *)
(* its content is evaluated with its own BaseStyle passed on to the elements, on its own canvas *)
(g : AnimatedGraphics[a_ ? agDataQ])["Update", T_] := Block[{
        $inheritedOptions = Join[Cases[Flatten[{Replace[agGiven[g, BaseStyle], _Missing -> {}]}], _[_String, _]], $inheritedOptions],
        $canvasSize = Replace[agGiven[g, "CanvasSize"], _Missing -> $canvasSize]},
    First @ FoldWhile[
        {#1[[1]][#2, T - #1[[2]], T], #1[[2]] + #2["Duration"]} &,
        {AnimatedGraphics[<|a, "Primitives" -> at[a["Primitives"], T], "Time" -> T|>], 0},
        a["Effects"], #[[2]] <= T &]];

at[l_List, T_] := at[#, T] & /@ l;
at[(Rule | RuleDelayed)[{t0_, t1_}, x_], T_] := If[t0 <= T < t1, If[MatchQ[x, _AnimatedGraphics], x["Update", T - t0], at[x, T]], Nothing];
at[f_Function, T_] := at[f[T], T];
at[g_AnimatedGraphics, T_] := g["Update", T];
at[_Track | _Audio, _] := Nothing;
at[x_, _] := x;


(* ::Section:: *)
(*The frame at time t*)

(* g[t] is the frame at time t as Graphics; Graphics options (ImageSize, Background, ...) may follow *)
(g : AnimatedGraphics[a_ ? agDataQ])[t_ ? NumericQ, opts : OptionsPattern[Graphics]] := frameGraphics[g["Update", t], t, {opts}];
(* the same, as primitives in its own coordinates *)
(g : AnimatedGraphics[a_ ? agDataQ])["Primitives", t_ ? NumericQ] := First[frameGraphics[g["Update", t], t, {}]];

(* the frame being drawn: its canvas and its plot range, for the elements that need them *)
$frame = <|"Canvas" -> {1920, 1080}, "PlotRange" -> {{0, 1920}, {0, 1080}}|>;

atT[f_ ? timeFunctionQ, t_] := f[t];
atT[x_, _] := x;

(* the plot range at time t: as given, else the canvas when there is anything to draw on it, else the
   bounds (the Manim frame when there is nothing to measure) *)
plotRange[g_, t_, content_] := With[{pr = atT[agOption[g, PlotRange], t], cs = agOption[g, "CanvasSize"]},
    Which[
        MatchQ[pr, {{_ ? NumericQ, _ ? NumericQ}, {_ ? NumericQ, _ ? NumericQ}}], pr,
        canvasPrimitiveQ[content], {{0, cs[[1]]}, {0, cs[[2]]}},
        True, With[{b = Quiet[g["Bounds"]]}, If[MatchQ[b, {{x0_, x1_}, {y0_, y1_}} /; x1 > x0 && y1 > y0], b, {{-64/9, 64/9}, {-4, 4}}]]]];

(* the frame of an updated object (g at time t of its own clock) *)
(* the theme: its own, else the enclosing one's, else "Manim" *)
$theme = "Manim";
frameGraphics[g : AnimatedGraphics[a_], t_, opts_List] := Block[{$theme = Replace[agGiven[g, PlotTheme], _Missing | Automatic :> $theme]},
    frameGraphics0[g, t, opts, themeData[$theme]]];
frameGraphics0[g : AnimatedGraphics[a_], t_, opts_List, th_] := Module[{cs = agOption[g, "CanvasSize"], content, pr, auto, bg, prims, w = agOption[g, "CanvasSize"][[1]],
        base = Join[Flatten[{Replace[agGiven[g, BaseStyle], _Missing -> {}]}], OptionValue[AnimatedGraphics, BaseStyle]]},
    (* string-named options in the BaseStyle are passed on to the elements *)
    Block[{$inheritedOptions = Join[Cases[base, _[_String, _]], $inheritedOptions], $canvasSize = cs},
        content = drawContent[g];
        auto = ! MatchQ[atT[agOption[g, PlotRange], t], {{_ ? NumericQ, _ ? NumericQ}, {_ ? NumericQ, _ ? NumericQ}}] && ! canvasPrimitiveQ[content];
        pr = plotRange[g, t, content];
        Block[{$frame = <|"Canvas" -> cs, "PlotRange" -> pr, "Theme" -> th|>},
            prims = placeCanvas[drawInsets[sizeRules[content, w, pr]], cs, pr]];
        bg = Replace[FirstCase[opts, (Rule | RuleDelayed)[Background, v_] :> v, agOption[g, Background]], Automatic :> th["Background"]];
        Graphics[{Replace[ov[base, FontColor], _Missing :> th["Ink"]], Thickness[4 / w], prims},
            Sequence @@ FilterRules[opts, Except[Background]],
            PlotRange -> pr, Background -> bg, ImageSize -> Replace[agOption[g, ImageSize], Automatic -> 480],
            AspectRatio -> (pr[[2, 2]] - pr[[2, 1]]) / (pr[[1, 2]] - pr[[1, 1]]),
            PlotRangePadding -> Replace[agOption[g, PlotRangePadding], Automatic -> If[auto, Scaled[0.1], None]],
            ImagePadding -> None, PlotRangeClipping -> True,
            BaseStyle -> Join[{FontSize -> Scaled[Replace[ov[base, FontSize], Except[_ ? NumericQ] -> 72] / w]}, DeleteDuplicatesBy[FilterRules[base, Except[FontSize | _String]], First]]]]];

(* the content of an updated object, as primitives: its directive, then what it holds, nested objects
   sharing its coordinates drawn in place and those with their own kept for drawInsets *)
drawContent[AnimatedGraphics[a_]] := {Sequence @@ Flatten[{a["Directive"]}], drawItem /@ Flatten[{a["Primitives"]}, 1]};
drawItem[l_List] := drawItem /@ l;
drawItem[c_AnimatedGraphics] := If[ownFrameQ[c], c, drawContent[c]];
drawItem[x_] := x;
ownFrameQ[c_AnimatedGraphics] := ! MissingQ[agGiven[c, PlotRange]] || ! MissingQ[agGiven[c, "Screen"]];

(* a nested object with coordinates of its own, drawn into its screen: a canvas rectangle of the
   enclosing frame (the whole frame by default), itself with a canvas of that many pixels *)
drawInsets[l_List] := drawInsets /@ l;
drawInsets[c_AnimatedGraphics] := childInset[c];
drawInsets[g3_Graphics3D] := fillInset[g3];
drawInsets[x_] := x;
childInset[c : AnimatedGraphics[a_]] := With[{T = Lookup[a, "Time", 0], canvas = $frame["Canvas"]},
    With[{r = Replace[atT[agOption[c, "Screen"], T], Automatic -> {0, 0, canvas[[1]], canvas[[2]]}]},
        With[{g = frameGraphics[AnimatedGraphics[<|a, "Options" -> Join[a["Options"], {"CanvasSize" -> r[[3 ;; 4]], Background -> None}]|>], T, {}]},
            screenInset[g, r]]]];
(* a 3D graphic fills the frame it is in *)
fillInset[g3_] := screenInset[Show[g3, AspectRatio -> $frame["Canvas"][[2]] / $frame["Canvas"][[1]], ImagePadding -> None], {0, 0, $frame["Canvas"][[1]], $frame["Canvas"][[2]]}];
(* a canvas rectangle {x, y, w, h} of the frame, in its plot coordinates *)
screenInset[g_, {x_, y_, w_, h_}] := With[{pr = $frame["PlotRange"], cs = $frame["Canvas"]},
    With[{sx = (pr[[1, 2]] - pr[[1, 1]]) / cs[[1]], sy = (pr[[2, 2]] - pr[[2, 1]]) / cs[[2]]},
        Inset[g, {pr[[1, 1]] + x sx, pr[[2, 2]] - (y + h) sy}, {Left, Bottom}, {w sx, h sy}]]];

(* canvas primitives drawn on the frame's canvas: in place when the plot range is the canvas itself,
   otherwise each run of them as an inset laid over the plot range *)
placeCanvas[prims_, cs_, pr_] /; pr == {{0, cs[[1]]}, {0, cs[[2]]}} := canvasResolve[cs, prims];
placeCanvas[prims_, cs_, pr_] := placeRun[prims, cs, pr];
placeRun[l_List, cs_, pr_] := Which[! canvasPrimitiveQ[l], l, AllTrue[l, canvasPrimitiveQ[#] || directiveQ[#] &], canvasInset[l, cs, pr], True, placeRun[#, cs, pr] & /@ l];
placeRun[x_, cs_, pr_] := If[canvasPrimitiveQ[x], canvasInset[x, cs, pr], x];
canvasInset[x_, cs_, pr_] := Inset[Graphics[canvasResolve[cs, x], PlotRange -> {{0, cs[[1]]}, {0, cs[[2]]}}, AspectRatio -> cs[[2]] / cs[[1]], PlotRangePadding -> None, ImagePadding -> None],
    {pr[[1, 1]], pr[[2, 1]]}, {Left, Bottom}, {pr[[1, 2]] - pr[[1, 1]], pr[[2, 2]] - pr[[2, 1]]}];

(* sizes in canvas pixels -> fractions of the frame's width, so a frame keeps its proportions at any
   size; an inset Graphics (a Plot, axes) gets the same treatment relative to its own width *)
sizeRules[prims_, w_, pr_] := prims /. Join[{c_AnimatedGraphics :> c,
    Inset[gr_Graphics, pos_, opos_, size : (_ ? NumericQ | {_ ? NumericQ, _}), rest___] :>
        With[{px = w First[Flatten[{size}]] / (pr[[1, 2]] - pr[[1, 1]]), gt = themeInset[gr, Lookup[$frame, "Theme", themeData["Manim"]]]},
            Inset[Show[gt /. sizeRuleList[px], BaseStyle -> Join[{FontSize -> Scaled[36 / px]}, Flatten[{Lookup[Options[gt /. sizeRuleList[px]], BaseStyle, {}]}]]],
                pos, opos, size, rest]]},
    sizeRuleList[w]];
sizeRuleList[w_] := {
    c_AnimatedGraphics :> c,
    (FontSize -> n_ ? NumericQ) :> (FontSize -> Scaled[n / w]),
    Style[x_, a___, n_ ? NumericQ, b___] :> Style[x, a, FontSize -> Scaled[n / w], b],
    Directive[a___, n_ ? NumericQ, b___] :> Directive[a, FontSize -> Scaled[n / w], b],
    AbsoluteThickness[n_ ? NumericQ] :> Thickness[n / w],
    AbsolutePointSize[n_ ? NumericQ] :> PointSize[n / w]};


(* ::Section:: *)
(*Sound*)

(* what it makes heard: {offset, sound} for every Track or Audio in it, nested ones shifted by their spans *)
sounds[l_List, off_] := Join @@ (sounds[#, off] & /@ l);
sounds[(Rule | RuleDelayed)[{t0_ ? NumericQ, _}, x_], off_] := sounds[x, off + t0];
sounds[s : _Track | _Audio, off_] := {{off, s}};
sounds[AnimatedGraphics[a_], off_] := sounds[a["Primitives"], off];
sounds[_, _] := {};
(* key presses and blips from the tools that type and evaluate *)
foley[l_List, off_] := Join @@ (foley[#, off] & /@ l);
foley[(Rule | RuleDelayed)[{t0_ ? NumericQ, _}, g_AnimatedGraphics], off_] := foley[g, off + t0];
foley[AnimatedGraphics[a_], off_] := Join[{#[[1]] + off, #[[2]], #[[3]]} & /@ Lookup[a, "Foley", {}], foley[a["Primitives"], off]];
foley[_, _] := {};

(* the foley as instrument voices: key clicks and evaluation blips *)
foleyVoices[ev_] := Join[
    If[FreeQ[ev, "Tick"], {}, {Instrument["Tick"][Track[Cases[ev, {t_, "Tick", v_} :> {t, 1/100, 1, v}]]]}],
    If[FreeQ[ev, "Blip"], {}, {Instrument["Blip"][Track[Cases[ev, {t_, "Blip", v_} :> {t, 1/20, 91, v}]]]}]];

(* Audio[g]: its sound over its duration, the foley mixed with the first Track that starts with it, through
   the same studio and mixer, when "Foley" -> True *)
AnimatedGraphics /: Audio[g : AnimatedGraphics[a_ ? agDataQ]] := Module[{cps = agOption[g, "CyclesPerSecond"], dur = g["Duration"], ss = sounds[g, 0], fv, k, rendered, mix},
    fv = If[TrueQ[agOption[g, "Foley"]], foleyVoices[foley[g, 0]], {}];
    If[fv =!= {}, k = FirstPosition[ss, {0, _Track}, None, {1}];
        ss = If[k === None, Append[ss, {0, Track[fv]}],
            MapAt[Replace[#, {0, t_Track} :> {0, Track[Join[{Track[First[t], KeyDrop[metaOf[t], "Mixer"]]}, fv], KeyTake[metaOf[t], "Mixer"]]}] &, ss, k]]];
    If[ss === {}, Return[None]];
    rendered = Map[With[{au = If[MatchQ[#[[2]], _Audio], #[[2]], Audio[#[[2]], Max[1, Ceiling[dur - #[[1]]]], "CyclesPerSecond" -> cps]]},
        If[#[[1]] > 0, AudioPad[au, {#[[1]] / cps, 0}], au]] &, ss];
    mix = AudioTrim[If[Length[rendered] == 1, First[rendered], AudioOverlay[rendered]], dur / cps];
    AudioPad[mix, {0, Max[0, dur / cps - QuantityMagnitude[Duration[mix], "Seconds"]]}]];


(* ::Section:: *)
(*Rendering: video, animated image, live player*)

(* a frame as an Image at the canvas size *)
(* a frame as an image: drawn on the GPU (GPUGraphics), or by the front end when it holds something the GPU
   renderer does not draw, or when told "Renderer" -> "FrontEnd" *)
frameImage[g_, t_, renderer_ : Automatic] := With[{gr = g[t, ImageSize -> agOption[g, "CanvasSize"][[1]]]},
    Replace[If[renderer === "FrontEnd", None, gpuRasterize[gr, Round[agOption[g, "CanvasSize"]]]], Except[_Image] :> Rasterize[gr, "Image", ImageResolution -> 72]]];

(* Export["film.mp4", g] renders the frames in parallel -- each subkernel loads WAnim, receives the
   definitions the content uses (a notebook's own functions just work) and runs any extra
   "KernelInitialization" -- then encodes them with ffmpeg together with the sound.  "From"/"To"
   select a range in cycles; a .gif is an AnimatedImage. *)
Options[agExport] = {"From" -> 0, "To" -> Automatic, FrameRate -> Automatic, "KernelInitialization" :> Null,
    "Parallel" -> True, "Kernels" -> 4, "Renderer" -> Automatic, "FrameDirectory" -> Automatic, "CRF" -> 18, "Chunk" -> 60};
AnimatedGraphics /: Export[file_String, g : AnimatedGraphics[_ ? agDataQ], opts___] /; ToLowerCase[FileExtension[file]] === "gif" :=
    Export[file, AnimatedImage[g, opts]];
AnimatedGraphics /: Export[file_String, g : AnimatedGraphics[_ ? agDataQ], opts : OptionsPattern[agExport]] := Module[{
    from = OptionValue[agExport, {opts}, "From"], to = Replace[OptionValue[agExport, {opts}, "To"], Automatic :> g["Duration"]],
    fps = Replace[OptionValue[agExport, {opts}, FrameRate], Automatic :> agOption[g, FrameRate]],
    cps = agOption[g, "CyclesPerSecond"], dir, n, times, wav},
    dir = Replace[OptionValue[agExport, {opts}, "FrameDirectory"], Automatic :> CreateDirectory[]];
    n = Round[(to - from) fps / cps];
    times = from + Range[0, n - 1] cps / fps;
    (* in parallel when kernels can be had; otherwise (none launched, none licensed) here, in order *)
    (* at most "Kernels" subkernels: each holds the whole film and a front end of its own, so a kernel per core
       can take all the memory there is *)
    If[TrueQ @ OptionValue[agExport, {opts}, "Parallel"] && (Length[Kernels[]] > 0 || Length[Quiet[LaunchKernels[Min[OptionValue[agExport, {opts}, "Kernels"], $ProcessorCount]]]] > 0),
        With[{root = ParentDirectory[PacletObject["WolframInstitute/WAnim"]["Location"]]},
            ParallelEvaluate[Block[{$Output = {}}, PacletDirectoryLoad[root]; Quiet @ Needs["WolframInstitute`WAnim`"]]; Null]];
        With[{init = Unevaluated @@ {OptionValue[agExport, {opts}, "KernelInitialization"]}}, ParallelEvaluate[ReleaseHold[Hold[init]]]];
        (* the film can be large (rasterized outputs, photos, a laid-out wall), so it goes to each kernel
           ONCE, inside the definition of a frame function made there directly; frames are then dealt out
           in contiguous chunks, so a kernel's caches (a wall's settled words) keep being reused *)
        With[{frame = Unique["WAnimVideoFrame"], sound = Unique["WAnimVideoSound"], times = times, dir = dir, from = from, to = to, renderer = OptionValue[agExport, {opts}, "Renderer"], chunks = Partition[Range[n], UpTo[OptionValue[agExport, {opts}, "Chunk"]]]},
            (* rasterizing needs a front end; subkernels do not always come with one *)
            ParallelEvaluate[frame[i_] := UsingFrontEnd[Export[FileNameJoin[{dir, "f" <> IntegerString[i, 10, 6] <> ".png"}], frameImage[g, times[[i]], renderer]]];
                sound[] := soundtrack[g, from, to, dir]];
            (* the content's own functions (a notebook's colours, tracks, helpers), and only those: the package
               and its caches (Spikey models, sprites, sounds) stay out, each kernel has WAnim of its own *)
            With[{defs = userDefinitions[g]}, ParallelEvaluate[restoreDefinitions[defs]]];
            (* the soundtrack (a minute for a whole film) is the first job, on one kernel while the others draw;
               a front end drawing the frames grows with every picture, so then each kernel starts a fresh one
               after every chunk, keeping memory bounded however long the film (with the GPU drawing them, the
               front end is hardly used, and restarting it only risks a start that hangs) *)
            wav = First @ ParallelMap[If[# === "Sound", sound[], Scan[frame, #]; If[renderer === "FrontEnd", Developer`UninstallFrontEnd[]]] &, Prepend[chunks, "Sound"], Method -> "FinestGrained"];
            ParallelEvaluate[Remove[frame, sound]]; Remove[frame, sound]],
        Do[Export[FileNameJoin[{dir, "f" <> IntegerString[i, 10, 6] <> ".png"}], frameImage[g, times[[i]], renderer]], {i, n}];
        wav = soundtrack[g, from, to, dir]];
    encodeVideo[dir, fps, wav, file, OptionValue[agExport, {opts}, "CRF"]]];
(* the film's sound from "From" to "To", as a WAV file in dir, or None for a silent film *)
soundtrack[g_, from_, to_, dir_] := With[{aud = Audio[g]},
    If[aud === None, None, Export[FileNameJoin[{dir, "soundtrack.wav"}], AudioTrim[aud, Quantity[{from, to} / agOption[g, "CyclesPerSecond"], "Seconds"]]]]];

(* frames f000001.png, ... in dir, and a sound or None, encoded by ffmpeg into file *)
encodeVideo[dir_, fps_, wav_, file_, crf_] := Module[{ffmpeg, res},
    ffmpeg = SelectFirst[{"/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"}, FileExistsQ, "ffmpeg"];
    res = RunProcess[Join[{ffmpeg, "-y", "-v", "error", "-framerate", ToString[fps], "-i", FileNameJoin[{dir, "f%06d.png"}]},
        If[wav === None, {}, {"-i", wav}],
        {"-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:v", "libx264", "-preset", "medium", "-crf", ToString[crf], "-pix_fmt", "yuv420p"},
        If[wav === None, {}, {"-c:a", "aac", "-b:a", "256k", "-shortest"}],
        {"-movflags", "+faststart", ExpandFileName[file]}]];
    If[res["ExitCode"] =!= 0, Failure["FFmpeg", <|"MessageTemplate" -> res["StandardError"]|>], ExpandFileName[file]]];
(* Video[g]: rendered to a temporary file *)
AnimatedGraphics /: Video[g : AnimatedGraphics[_ ? agDataQ], opts___] := With[{f = Export[FileNameJoin[{$TemporaryDirectory, CreateUUID["wanim-"] <> ".mp4"}], g, opts]},
    If[StringQ[f], Video[f], f]];

(* AnimatedImage[g]: small and self-contained, it plays in a notebook and in the cloud; frames at
   "Resolution" times the size they are shown at, so thin lines stay crisp *)
Options[agAnimatedImage] = {"From" -> 0, "To" -> Automatic, FrameRate -> 15, ImageSize -> 480, "Resolution" -> 2};
AnimatedGraphics /: AnimatedImage[g : AnimatedGraphics[_ ? agDataQ], opts : OptionsPattern[agAnimatedImage]] := Module[{
    from = OptionValue[agAnimatedImage, {opts}, "From"], to = Replace[OptionValue[agAnimatedImage, {opts}, "To"], Automatic :> Max[g["Duration"], 10^-3]],
    fps = OptionValue[agAnimatedImage, {opts}, FrameRate], cps = agOption[g, "CyclesPerSecond"], size = OptionValue[agAnimatedImage, {opts}, ImageSize],
    k = OptionValue[agAnimatedImage, {opts}, "Resolution"]},
    AnimatedImage[Table[Rasterize[g[t, ImageSize -> k size], "Image", ImageResolution -> 72], {t, from, to - 10^-6, cps / fps}],
        FrameRate -> fps, AnimationRepetitions -> Infinity, ImageSize -> size]];

(* g["Dynamic"]: a scrubbable player.  With sound, the AUDIO is the master clock: the picture follows
   the stream's true position, so it never drifts from what you hear; without, the wall clock.  Click
   the picture (or the button) to play or pause; drag the slider to scrub. *)
Options[agPlayer] = {ImageSize -> 960, UpdateInterval -> 1 / 30, "StartTime" -> 0};
(g : AnimatedGraphics[a_ ? agDataQ])["Dynamic", opts : OptionsPattern[agPlayer]] := With[{
    dur = g["Duration"], spc = 1 / agOption[g, "CyclesPerSecond"], aud = Audio[g],
    size = OptionValue[agPlayer, {opts}, ImageSize], dt = OptionValue[agPlayer, {opts}, UpdateInterval], t0 = OptionValue[agPlayer, {opts}, "StartTime"],
    defs = userDefinitions[g]},
    DynamicModule[{t = t0, playing = False, stream = None, begin = 0.},
        Column[{
            EventHandler[
                Dynamic[Refresh[
                    If[playing,
                        t = If[stream =!= None, QuantityMagnitude[stream["Position"], "Seconds"] / spc, (AbsoluteTime[] - begin) / spc];
                        If[t >= dur, t = dur; playing = False; If[stream =!= None, AudioStop[stream]]]];
                    g[Min[t, dur - 10^-6], ImageSize -> size],
                    TrackedSymbols :> {t, playing}, UpdateInterval -> If[playing, dt, Infinity]]],
                {"MouseClicked" :> togglePlay[Hold[t, playing, stream, begin], aud, spc, dur]}],
            Row[{
                Button[Dynamic[If[playing, "\[DoubleVerticalBar]", "\[RightTriangle]"]], togglePlay[Hold[t, playing, stream, begin], aud, spc, dur], Appearance -> "Frameless", ImageSize -> 28],
                Slider[Dynamic[t, (t = #; If[playing, seekTo[Hold[t, playing, stream, begin], aud, spc, #]]) &], {0, dur}, ImageSize -> size - 120],
                Dynamic[Row[{NumberForm[t, {4, 2}], " / ", dur}]]}, Spacer[6]]}],
        Deinitialization :> If[stream =!= None, Quiet[AudioStop[stream]; RemoveAudioStream[stream]]],
        Initialization :> (Needs["WolframInstitute`WAnim`"]; restoreDefinitions[defs])]];
SetAttributes[{togglePlay, seekTo}, HoldFirst];
togglePlay[Hold[t_, playing_, stream_, begin_], aud_, spc_, dur_] := If[playing,
    playing = False; If[stream =!= None, AudioStop[stream]],
    If[t >= dur, t = 0];
    If[aud =!= None,
        If[stream === None, stream = AudioStream[aud]];
        AudioPlay[stream]; stream["Position"] = Quantity[t spc, "Seconds"],   (* play, then seek: a seek before the stream rolls is ignored *)
        begin = AbsoluteTime[] - t spc];
    playing = True];
seekTo[Hold[t_, playing_, stream_, begin_], aud_, spc_, x_] := If[stream =!= None, stream["Position"] = Quantity[x spc, "Seconds"], begin = AbsoluteTime[] - x spc];


(* ::Section:: *)
(*Summary box*)

(* a summary box's icon: eight small frames across its time, looping as an AnimatedImage *)
summaryIcon[frame_, {t0_, t1_}] := AnimatedImage[Table[Rasterize[Show[frame[t], ImageSize -> 96], "Image", ImageResolution -> 144],
    {t, If[t1 > t0, t0 + (t1 - t0) Range[0, 7] / 8 + 10^-6, {t0}]}], FrameRate -> 4, AnimationRepetitions -> Infinity, ImageSize -> 96];

AnimatedGraphics /: MakeBoxes[g : AnimatedGraphics[a_ ? agDataQ], StandardForm] := With[{
    span = Replace[Lookup[a, "Span", {0, g["Duration"]}], {-Infinity -> 0, Infinity -> 1}, {1}]},
    BoxForm`ArrangeSummaryBox[AnimatedGraphics, g,
        Quiet @ Check[summaryIcon[g[#, Background -> If[KeyExistsQ[a, "Name"], GrayLevel[0.9], agOption[g, Background]]] &, span], ""],
        {If[KeyExistsQ[a, "Name"], {BoxForm`SummaryItem[{"Element: ", a["Name"]}]}, Nothing],
         {BoxForm`SummaryItem[{If[KeyExistsQ[a, "Span"], "Span: ", "Duration: "], If[KeyExistsQ[a, "Span"], a["Span"], g["Duration"]]}]}},
        {{BoxForm`SummaryItem[{"Effects: ", Length[a["Effects"]]}]}, {BoxForm`SummaryItem[{"Options: ", a["Options"]}]}},
        StandardForm, "Interpretable" -> Automatic]];
