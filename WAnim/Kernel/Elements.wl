(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Backdrop}]


(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{userDefinitions, restoreDefinitions, timeFunctionQ, elementOptions, toolOptions, drawOptions, $inheritedOptions, makeElement, ov, keystrokes, weightNum, layerFont, layerPoint, envelope, localU, typedCount, defaultFont}]


(* ::Section:: *)
(*Elements: the pieces a film is written in*)

(* Every creation tool (Typewriter, CaptionText, TerminalSession, NotebookSession, ...) returns an
   AnimatedGraphics holding one timed drawing: a span of time and a pure function drawing the element
   at time t in canvas coordinates.  A film is an AnimatedGraphics of them, so it is written as a list
   of tool calls, one line per segment.

   The tools share one set of conventions:
     span        {t0, t1} in the film's unit (cycles): the element enters at t0 and has left by t1
     Position    a canvas point {x, y} (pixels, y down), Center, or Scaled[{u, v}] of the canvas
     Font*       FontFamily, FontSize (px), FontWeight (CSS number or name), FontSlant, FontColor
     "Enter"     how it arrives: "Fade", "Rise", "Pop", "Cut" (tool-specific ones documented per tool)
     "Exit"      how it leaves: "Fade", "Drop", "Cut" (and tool-specific ones)
     "EnterTime", "ExitTime"   their durations
   Any option given as a function (a Function, an InterpolatingFunction, or a symbol with definitions)
   is a function of time and is evaluated at every frame -- ink that turns to bone as the film goes dark, a Spikey that walks.
   Options an enclosing AnimatedGraphics sets in its BaseStyle apply to every element in it that does
   not set them itself. *)

(* the options every tool shares, after its own: a tool's own defaults come first and win *)
$elementOptions = {Position -> Center, Alignment -> Left, FontFamily -> Automatic, FontSize -> 48, FontWeight -> 600, FontSlant -> Plain,
    FontColor -> Black, Opacity -> 1, "Enter" -> "Fade", "Exit" -> "Fade", "EnterTime" -> 0.25, "ExitTime" -> 0.25};
elementOptions[own_List] := Join[own, FilterRules[$elementOptions, Except[own]]];

(* options set by the enclosing AnimatedGraphics' BaseStyle while a frame is drawn *)
$inheritedOptions = {};

(* a tool's options while it is built (its own, then its defaults), and while it is drawn at time t (its
   own, then what it inherits, then its defaults, every function of time evaluated) *)
toolOptions[opts_List, tool_Symbol] := Join[opts, Options[tool]];
drawOptions[opts_List, tool_Symbol, t_] := atTime[Join[opts, $inheritedOptions, Options[tool]], t];

(* an option from a merged option list: the first one given wins *)
ov[o_List, name_] := FirstCase[o, (Rule | RuleDelayed)[name, v_] :> v, Missing["NoOption", name]];

(* options that take functions of something other than time *)
$untimedOptions = {"Format"};
atTime[o_List, t_] := Replace[Flatten[o], (r : Rule | RuleDelayed)[k_, f_ ? timeFunctionQ] /; ! MemberQ[$untimedOptions, k] :> r[k, f[t]], {1}];
(* a function of time: a Function, an InterpolatingFunction, or a symbol defined as one (camera[t_] := ...) *)
timeFunctionQ[f_] := MatchQ[f, _Function | _InterpolatingFunction] || (MatchQ[f, _Symbol] && ! StringStartsQ[Context[f], "System`"] && DownValues[f] =!= {});

(* an element: an AnimatedGraphics drawing draw[t] over its span, named after its tool, carrying
   whatever else the tool knows (its foley, the places of a wall's words, a session's screen) *)
makeElement[name_String, {t0_, t1_}, draw_, extra_Association : <||>] :=
    AnimatedGraphics[<|"Primitives" -> {{t0, t1} -> draw}, "Directive" -> {}, "Effects" -> {}, "Options" -> {Background -> GrayLevel[0.95]}, "Name" -> name, "Span" -> {t0, t1}, extra|>];

(* Backdrop[colour, {t0, t1}] fills the whole canvas; the colour may be a function of time, and like
   any element it can fade in and out ("Enter" -> "Fade", "EnterTime" -> ...) *)
Options[Backdrop] = elementOptions[{"Enter" -> "Cut", "Exit" -> "Cut"}];
Backdrop[c_, span : {_, _} : {-Infinity, Infinity}, opts : OptionsPattern[]] := makeElement["Backdrop", span,
    Function[t, backdropDraw[c, t, span, drawOptions[{opts}, Backdrop, t]]]];
backdropDraw[c_, t_, span_, o_] := CanvasRectangle[{0, 0, $canvasSize[[1]], $canvasSize[[2]]}, If[ColorQ[c] || StringQ[c], c, c[t]],
    Opacity -> ov[o, Opacity] envelope[t, span, o]["Alpha"]];


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
layerPoint[p_] := Switch[p, Center, $canvasSize / 2, Scaled[{_, _}], First[p] $canvasSize, _, p];

(* how far into its life an element is: 0 -> 1 over [a, b] *)
localU[t_, a_, b_] := Clip[(t - a) / (b - a), {0, 1}];
(* enter/exit envelope -> <|"Alpha", "Offset" (px, y), "Scale"|> for the named styles *)
envelope[t_, {t0_, t1_}, opts_List] := Module[{enter = First[Flatten[{ov[opts, "Enter"]}]], exit = First[Flatten[{ov[opts, "Exit"]}]],
    et = ov[opts, "EnterTime"], xt = ov[opts, "ExitTime"], u, v, a = 1., dy = 0., s = 1.},
    u = If[enter === "Cut" || et == 0 || t0 === -Infinity, 1., Easing["OutExpo"][localU[t, t0, t0 + et]]];
    v = If[exit === "Cut" || xt == 0 || t1 === Infinity, 0., Easing["InCubic"][localU[t, t1 - xt, t1]]];
    Switch[enter, "Fade", a = u, "Rise", a = u; dy = 22 (1 - u), "Pop", a = Clip[u, {0, 1}]; s = Easing["OutBack", 1.8][localU[t, t0, t0 + et]], _, Null];
    Switch[exit, "Fade", a *= 1 - v, "Drop", a *= 1 - v; dy += 16 v, _, Null];
    <|"Alpha" -> a, "Offset" -> dy, "Scale" -> s|>];

(* the key presses of typing n characters from at over dur, as foley: {time, "Tick", velocity}, quantized
   to 1/64 of a cycle and at least 1/40 apart, each a little louder or softer than the last *)
keystrokes[at_, dur_, n_Integer] := Module[{last = -1, b, out = {}},
    Do[b = Round[(at + k / n dur) 64] / 64; If[b - last >= 1/40, last = b; AppendTo[out, {b, "Tick", 0.55 + 0.45 FractionalPart[0.618 k]}]], {k, 0, n - 1}];
    out];

(* characters of an n-character text shown u of the way through typing *)
typedCount[n_, u_] := Floor[Clip[u, {0, 1}] n + 10^-6];


(* ::Section:: *)
(*Live outputs that keep working*)

(* A live output (a player, an editable track) is saved with the definitions of the notebook's own
   functions it uses, and restores them when it is opened in a new session, after loading WAnim --
   what SaveDefinitions does, but leaving out the package and its shared state. *)
userDefinitions[expr_] := Language`ExtendedFullDefinition[expr,
    ExcludedContexts -> Join[Language`$InternalContexts, # <> "*" & /@ Contexts["WolframInstitute`WAnim`*"]]];
restoreDefinitions[Language`DefinitionList[rs___]] := Scan[restoreSymbol, {rs}];
restoreDefinitions[_] := Null;
restoreSymbol[HoldForm[s_Symbol] -> vals_List] := (Quiet[Unprotect[s]]; Scan[restoreValues[s, #] &, vals]);
restoreSymbol[_] := Null;
SetAttributes[restoreValues, HoldFirst];
restoreValues[s_, (OwnValues | DownValues | SubValues | NValues | FormatValues | Messages) -> v_] :=
    Scan[Replace[#, (HoldPattern[lhs_] :> rhs_) :> SetDelayed[lhs, rhs]] &, Flatten[{v}]];
restoreValues[s_, UpValues -> v_] := Scan[Replace[#, (HoldPattern[lhs_] :> rhs_) :> TagSetDelayed[s, lhs, rhs]] &, Flatten[{v}]];
restoreValues[s_, DefaultValues -> v_] := Scan[Replace[#, (HoldPattern[lhs_] :> rhs_) :> Set[lhs, rhs]] &, Flatten[{v}]];
restoreValues[s_, Attributes -> a_List] := If[a =!= {}, SetAttributes[s, a]];
restoreValues[_, _] := Null;
