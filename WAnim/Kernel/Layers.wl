(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{TimelineLayer, Backdrop, $LayerOptions}]


(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{ov, atTime, keystrokes, weightNum, makeLayer, layerFont, layerPoint, envelope, localU, typedCount, defaultFont}]


(* ::Section:: *)
(*Layers: the unit a timeline is written in*)

(* Every creation tool (Typewriter, Caption, Terminal, NotebookSession, ...) returns a TimelineLayer:
   a span of time and a pure function drawing the layer at time t on the canvas.  A Timeline is a
   list of them, so a film is written as a list of tool calls, one line per segment.

   The tools share one set of conventions:
     span        {t0, t1} in the timeline's unit: the layer enters at t0 and has left by t1
     Position    a canvas point {x, y} (pixels, y down), Center, or Scaled[{u, v}] of the canvas
     Font*       FontFamily, FontSize (px), FontWeight (CSS number or name), FontSlant, FontColor
     "Enter"     how it arrives: "Fade", "Rise", "Pop", "Cut" (tool-specific ones documented per tool)
     "Exit"      how it leaves: "Fade", "Drop", "Cut" (and tool-specific ones)
     "EnterTime", "ExitTime"   their durations, in timeline units
     colours     FontColor and every other *Color option may also be a function of time *)

$LayerOptions = {Position -> Center, Alignment -> Left, FontFamily -> Automatic, FontSize -> 48, FontWeight -> 600, FontSlant -> Plain,
    FontColor -> Black, Opacity -> 1, "Enter" -> "Fade", "Exit" -> "Fade", "EnterTime" -> 0.25, "ExitTime" -> 0.25};

(* an option from a tool's merged option list (user options first, then the tool's defaults) *)
ov[o_List, name_] := FirstCase[o, (Rule | RuleDelayed)[name, v_] :> v, Missing["NoOption", name]];

(* a tool's options at time t: any colour option (FontColor, "Color", "HeadColor", ...) may be a
   function of time -- ink that turns to bone as the film goes dark -- and is evaluated here *)
atTime[o_List, t_] := Replace[Flatten[o], (r : Rule | RuleDelayed)[k_, f : (_Function | _InterpolatingFunction)] /; StringContainsQ[ToString[k], "Color" | "Ink"] :> r[k, f[t]], {1}];

makeLayer[name_String, {t0_, t1_}, draw_, extra_Association : <||>] :=
    TimelineLayer[<|"Name" -> name, "Span" -> {t0, t1}, "Draw" -> draw, extra|>];

layerQ[a_] := AssociationQ[a] && KeyExistsQ[a, "Span"] && KeyExistsQ[a, "Draw"];
TimelineLayer[a_ ? layerQ][key : "Span" | "Draw" | "Name"] := a[key];
(* what a creation tool knows about its layer, e.g. where a WordWall put its words *)
TimelineLayer[a_ ? layerQ]["Properties"] := Complement[Keys[a], {"Draw", "Screen", "Foley"}];
TimelineLayer[a_ ? layerQ][key_String] /; KeyExistsQ[a, key] && ! MemberQ[{"Draw", "Screen", "Foley"}, key] := a[key];
TimelineLayer[a_ ? layerQ][t_ ? NumericQ] := If[a["Span"][[1]] <= t < a["Span"][[2]], a["Draw"][t], {}];
(* a layer on its own: its frame at time t on a canvas (default 1920 x 1080, background from the
   Background option), as Graphics or a rasterized Image; Graphics options such as ImageSize go through *)
TimelineLayer[a_ ? layerQ]["Graphics", t_, opts___] := Timeline[{TimelineLayer[a]}, "Size" -> Lookup[{opts}, "Size", {1920, 1080}],
    Background -> Lookup[{opts}, Background, GrayLevel[0.95]], "Duration" -> Max[1, a["Span"][[2]] /. Infinity -> 1]]["Graphics", t, Sequence @@ FilterRules[{opts}, Except["Size" | Background]]];
TimelineLayer[a_ ? layerQ]["Image", t_, opts___] := Rasterize[TimelineLayer[a]["Graphics", t, opts], "Image", ImageResolution -> 72];
(* a layer moved in time: layer["Shift", dt] *)
TimelineLayer[a_ ? layerQ]["Shift", dt_] := TimelineLayer[<|a, "Span" -> a["Span"] + dt, "Draw" -> With[{f = a["Draw"]}, Function[t, f[t - dt]]]|>];

TimelineLayer /: MakeBoxes[l : TimelineLayer[a_ ? layerQ], StandardForm] := BoxForm`ArrangeSummaryBox[
    TimelineLayer, l,
    (* the icon plays the layer over its span, looping, a few frames a second *)
    With[{span = a["Span"] /. {-Infinity -> 0, Infinity -> 1}, draw = a["Draw"]},
        DynamicModule[{}, Dynamic[Refresh[Graphics[CanvasBlock[{1920, 1080}, draw[Clock[span, Max[2, span[[2]] - span[[1]]]]]], PlotRange -> {{0, 1920}, {0, 1080}},
            ImageSize -> 96, Background -> GrayLevel[0.9], PlotRangePadding -> None, ImagePadding -> None], UpdateInterval -> 0.2], SynchronousUpdating -> False],
            SaveDefinitions -> True, Initialization :> Needs["WolframInstitute`WAnim`"]]],
    {{BoxForm`SummaryItem[{"Name: ", a["Name"]}]}, {BoxForm`SummaryItem[{"Span: ", a["Span"]}]}},
    {}, StandardForm, "Interpretable" -> Automatic];

(* a solid fill of the whole canvas; the colour can be a function of time *)
Backdrop[c_, span : {_, _} : {-Infinity, Infinity}] := makeLayer["Backdrop", span,
    Function[t, CanvasRectangle[{0, 0, $CanvasSize[[1]], $CanvasSize[[2]]}, If[ColorQ[c] || StringQ[c], c, c[t]]]]];


(* ::Section:: *)
(*Shared helpers*)

defaultFont["Sans"] = "Source Sans 3"; defaultFont["Serif"] = "Source Serif 4"; defaultFont["Mono"] = "Source Code Pro"; defaultFont["Terminal"] = "VT323";
weightNum[w_ ? NumericQ] := w;
weightNum[w_String] := Lookup[<|"Light" -> 300, "Plain" -> 400, "Regular" -> 400, "Medium" -> 500, "SemiBold" -> 600, "Bold" -> 700, "Black" -> 900|>, w, 400];
weightNum[Bold] := 700; weightNum[Plain] := 400;
(* the CanvasFont a tool's options describe; a size factor lets a tool derive a smaller/larger face *)
layerFont[opts_List, default_String : "Sans", k_ : 1] := CanvasFont[
    Replace[ov[opts, FontFamily], Automatic -> defaultFont[default]],
    k ov[opts, FontSize], weightNum[ov[opts, FontWeight]],
    MatchQ[ov[opts, FontSlant], "Italic" | Italic]];
layerPoint[p_] := Switch[p, Center, $CanvasSize / 2, Scaled[{_, _}], First[p] $CanvasSize, _, p];

(* how far into its life a layer is: 0 -> 1 over [a, b] *)
localU[t_, a_, b_] := Clip[(t - a) / (b - a), {0, 1}];
(* enter/exit envelope -> <|"Alpha", "Offset" (px, y), "Scale"|> for the named styles *)
envelope[t_, {t0_, t1_}, opts_List] := Module[{enter = ov[opts, "Enter"], exit = ov[opts, "Exit"],
    et = ov[opts, "EnterTime"], xt = ov[opts, "ExitTime"], u, v, a = 1., dy = 0., s = 1.},
    u = If[enter === "Cut" || et == 0, 1., Easing["OutExpo"][localU[t, t0, t0 + et]]];
    v = If[exit === "Cut" || xt == 0 || t1 === Infinity, 0., Easing["InCubic"][localU[t, t1 - xt, t1]]];
    Switch[enter, "Fade", a = u, "Rise", a = u; dy = 22 (1 - u), "Pop", a = Clip[u, {0, 1}]; s = Easing["OutBack", 1.8][localU[t, t0, t0 + et]], _, Null];
    Switch[exit, "Fade", a *= 1 - v, "Drop", a *= 1 - v; dy += 16 v, _, Null];
    <|"Alpha" -> a, "Offset" -> dy, "Scale" -> s|>];

(* the key presses of typing n characters from at over dur, as foley: {time, "Tick", velocity}, quantized
   to 1/64 of a unit and at least 1/40 apart, each a little louder or softer than the last *)
keystrokes[at_, dur_, n_Integer] := Module[{last = -1, b, out = {}},
    Do[b = Round[(at + k / n dur) 64] / 64; If[b - last >= 1/40, last = b; AppendTo[out, {b, "Tick", 0.55 + 0.45 FractionalPart[0.618 k]}]], {k, 0, n - 1}];
    out];

(* characters of an n-character text shown u of the way through typing *)
typedCount[n_, u_] := Floor[Clip[u, {0, 1}] n + 10^-6];
