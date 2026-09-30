(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{themeData, themeInset}]


(* ::Section:: *)
(*Themes*)

(* A theme is how a scene looks when it says nothing: its background, its ink (text, axes), and the colours
   its plots draw in.  AnimatedGraphics takes one as PlotTheme ("Manim" by default); each is also a
   PlotTheme for any plot, so Plot[..., PlotTheme -> "Manim"] draws as Manim's axes do.
     "Manim"   Manim's look: black, white ink, Manim's blue, red, green, yellow, ...
     "Paper"   warm paper and near-black ink, a red accent
     "Night"   near-black and bone ink, the red accent *)
themeData["Manim"] = <|"Background" -> Black, "Ink" -> White,
    "Palette" -> RGBColor /@ {"#58C4DD", "#FC6255", "#83C167", "#FFFF00", "#F0AC5F", "#9A72AC", "#5CD0B3", "#C55F73", "#FF862F", "#D147BD"}|>;
themeData["Paper"] = <|"Background" -> RGBColor["#F4F1EA"], "Ink" -> RGBColor["#2A2825"],
    "Palette" -> RGBColor /@ {"#DD1100", "#1D5FAE", "#2E8B57", "#D98C00", "#6A4C93", "#0F7C80", "#A0522D", "#C2185B", "#5B6770", "#8A9A00"}|>;
themeData["Night"] = <|"Background" -> RGBColor["#0E0F11"], "Ink" -> RGBColor["#E8E4DA"],
    "Palette" -> RGBColor /@ {"#FF5A43", "#58C4DD", "#83C167", "#F4D345", "#F0AC5F", "#9A72AC", "#5CD0B3", "#D147BD", "#FF862F", "#B9B3A7"}|>;
themeData[_] := themeData["Manim"];

(* each also a PlotTheme *)
Scan[With[{th = themeData[#]}, Themes`AddThemeRules[#,
    DefaultPlotStyle -> (Directive[#, AbsoluteThickness[2]] & /@ th["Palette"]), Background -> th["Background"],
    AxesStyle -> th["Ink"], FrameStyle -> th["Ink"], TicksStyle -> th["Ink"], LabelStyle -> th["Ink"]]] &, {"Manim", "Paper", "Night"}];

(* a plot inset in a scene, in the scene's theme: the default colours become the theme's, axes, ticks and
   labels take its ink unless the plot sets them, and it fills its inset with no padding or background.
   Sizes are pixels of the scene's canvas, as everywhere in it. *)
$defaultPlotColors = Table[ColorData[97, i], {i, 10}];
themeInset[gr_Graphics, th_] := With[{given = Keys[Options[gr]], ink = th["Ink"]},
    Show[gr /. Thread[$defaultPlotColors -> th["Palette"]],
        Sequence @@ Select[{AxesStyle -> Directive[ink, AbsoluteThickness[2]], FrameStyle -> Directive[ink, AbsoluteThickness[2]],
            TicksStyle -> Directive[ink, FontSize -> 30], LabelStyle -> Directive[ink, FontSize -> 40]}, ! MemberQ[given, First[#]] &],
        Background -> None, PlotRangePadding -> None, AspectRatio -> Full]];
