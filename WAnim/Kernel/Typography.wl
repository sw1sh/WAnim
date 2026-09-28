(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Typewriter, Title, Caption}]


(* ::Section:: *)
(*Kinetic typography*)

(* The words on screen, as layers.  All three share the layer conventions ($LayerOptions: span,
   Position, Font*, Enter/Exit) and add their own motion:
     Typewriter  text typed on the clock behind a blinking cursor; words can light up afterwards
     Title       display type that arrives whole, rises, pops, or letter by letter
     Caption     a sentence that arrives word by word on a beat grid, wrapped to a column *)

cursorBlink[t_] := EvenQ[Floor[4 t]];
collapse[t_, t1_, xt_] := Easing["InExpo"][localU[t, t1 - xt, t1]];


(* ::Subsection:: *)
(*Typewriter*)

Options[Typewriter] = Join[{FontFamily -> Automatic, FontSize -> 64, FontWeight -> 400, FontColor -> RGBColor["#E9E6DF"], Alignment -> Center,
    "TypingTime" -> Automatic, "Cursor" -> "Block", "CursorColor" -> RGBColor["#FF3B1F"],
    "Highlight" -> {}, "HighlightColor" -> RGBColor["#FF3B1F"], "HighlightTime" -> Automatic, "Exit" -> "Fade"}, $LayerOptions];

(* Typewriter["text", {t0, t1}] types text from t0 over "TypingTime" (default: a brisk rate, at most
   half the span), with a blinking "Cursor" ("Block", "Bar" or None).  "Highlight" -> {"word", ...}
   lights words up once typing is done.  "Exit" -> "Collapse" folds the line into its cursor. *)
Typewriter[s_String, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Typewriter]]},
    makeLayer["Typewriter", {t0, t1}, Function[t, typewriterDraw[s, t, {t0, t1}, o]]]];

typewriterDraw[s_, t_, {t0_, t1_}, o_] := Module[{f = layerFont[o, "Mono"], tt, u, shown, full, p, x, y, k, env, cur, hl, hlt},
    tt = Replace[ov[o, "TypingTime"], Automatic -> Min[0.5 (t1 - t0), 0.05 StringLength[s]]];
    u = localU[t, t0, t0 + tt]; shown = TypedText[s, u];
    full = CanvasTextWidth[s, f]; p = layerPoint[ov[o, Position]];
    x = Switch[ov[o, Alignment], Center, p[[1]] - full / 2, Right, p[[1]] - full, _, p[[1]]]; y = p[[2]] + 0.22 f["Size"];
    env = If[ov[o, "Exit"] === "Collapse", <|"Alpha" -> 1., "Offset" -> 0.|>, envelope[t, {t0, t1}, Join[{"Enter" -> "Cut"}, o]]];
    k = If[ov[o, "Exit"] === "Collapse", collapse[t, t1, ov[o, "ExitTime"]], 0];
    hl = Flatten[{ov[o, "Highlight"]}];
    hlt = Replace[ov[o, "HighlightTime"], Automatic -> t0 + tt + 0.2];
    cur = ov[o, "Cursor"];
    CanvasOpacity[env["Alpha"], {
        CanvasTransform[CanvasTranslate[{x + full, y}] . CanvasScale[{1 - k, 1 - 0.2 k}] . CanvasTranslate[{-x - full, -y}], {
            CanvasText[shown, {x, y + env["Offset"]}, f, ov[o, FontColor]],
            (* highlighted words fade to their colour once the line is typed *)
            If[t > hlt, Table[With[{pos = StringPosition[s, w]}, If[pos === {}, Nothing,
                CanvasText[w, {x + CanvasTextWidth[StringTake[s, pos[[-1, 1]] - 1], f], y + env["Offset"]}, f,
                    Blend[{ov[o, FontColor], ov[o, "HighlightColor"]}, Easing["OutCubic"][localU[t, hlt, hlt + 0.3]]]]]], {w, hl}], {}]}],
        If[cur =!= None && (cursorBlink[t] || 0 < u < 1),
            With[{cx = x + CanvasTextWidth[shown, f] (1 - k) + 0.1 f["Size"], h = f["Size"]},
                If[cur === "Bar", CanvasRectangle[{cx, y - 0.8 h, 0.08 h, h}, ov[o, "CursorColor"]],
                    CanvasRectangle[{cx, y - 0.8 h, 0.46 h, h}, ov[o, "CursorColor"]]]], {}]
    }]];


(* ::Subsection:: *)
(*Title*)

Options[Title] = Join[{FontSize -> 120, FontWeight -> 700, Alignment -> Center, "Enter" -> "Rise", "EnterTime" -> 0.3,
    "LetterInterval" -> 1/8, "Cursor" -> None, "CursorColor" -> RGBColor["#DD1100"], "CollapsePoint" -> Automatic}, $LayerOptions];

(* Title["text", {t0, t1}] sets display type at Position.  "Enter" -> "Rise" | "Fade" | "Pop" | "Cut", or
   "Letters": one letter per "LetterInterval", each popping up from its baseline (with "Cursor" -> True
   a bar follows the last letter).  "Exit" -> "Fade" | "Drop" | "Cut" | "Collapse" (shrinks into
   "CollapsePoint", default the text's centre). *)
Title[s_String, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Title]]},
    makeLayer["Title", {t0, t1}, Function[t, titleDraw[s, t, {t0, t1}, o]]]];

titleDraw[s_, t_, {t0_, t1_}, o_] := Module[{f = layerFont[o], p = layerPoint[ov[o, Position]], full, x, y, env, k, c, letters, n, cx},
    full = CanvasTextWidth[s, f, -2]; y = p[[2]];
    x = Switch[ov[o, Alignment], Center, p[[1]] - full / 2, Right, p[[1]] - full, _, p[[1]]];
    letters = ov[o, "Enter"] === "Letters";
    env = envelope[t, {t0, t1}, Join[If[letters, {"Enter" -> "Cut"}, {}], If[ov[o, "Exit"] === "Collapse", {"Exit" -> "Cut"}, {}], o]];
    k = If[ov[o, "Exit"] === "Collapse", 0.92 collapse[t, t1, ov[o, "ExitTime"]], 0];
    c = Replace[ov[o, "CollapsePoint"], Automatic -> {x + full / 2, y - 0.35 f["Size"]}];
    CanvasOpacity[env["Alpha"], CanvasTransform[CanvasScale[(1 - k) env["Scale"], c],
        If[! letters, CanvasText[s, {x, y + env["Offset"]}, f, ov[o, FontColor]],
            n = Clip[Floor[(t - t0) / ov[o, "LetterInterval"]] + 1, {0, StringLength[s]}]; cx = x;
            {Table[With[{ch = StringTake[s, {i}], age = t - t0 - (i - 1) ov[o, "LetterInterval"]},
                {CanvasTransform[CanvasTranslate[{cx, y}] . CanvasScale[{1, Easing["OutBack", 2][localU[age, 0, 0.12]]}] . CanvasTranslate[{-cx, -y}],
                    CanvasText[ch, {cx, y}, f, If[i == n && age < 0.1, ov[o, "CursorColor"], ov[o, FontColor]]]],
                 cx += CanvasTextWidth[ch, f] - 2}[[1]]], {i, n}],
             If[TrueQ[ov[o, "Cursor"]] && (n < StringLength[s] || cursorBlink[t]),
                CanvasRectangle[{cx + 0.05 f["Size"], y - 0.74 f["Size"], 0.06 f["Size"], 0.9 f["Size"]}, ov[o, "CursorColor"]], {}]}]]]];


(* ::Subsection:: *)
(*Caption*)

Options[Caption] = Join[{Position -> {1250, 720}, FontSize -> 52, "Width" -> 590, "LineHeight" -> 1.12, "WordInterval" -> 1/16,
    "Highlight" -> {}, "HighlightColor" -> RGBColor["#DD1100"], "Enter" -> "Rise", "Exit" -> "Drop"}, $LayerOptions];

(* Caption["text", {t0, t1}] sets a sentence into a column "Width" wide at Position (top-left of the
   first baseline), each word rising in on its own beat ("WordInterval" apart); "Highlight" words
   are drawn in "HighlightColor". *)
Caption[s_String, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = Join[{opts}, Options[Caption]]},
    makeLayer["Caption", {t0, t1 + ov[o, "ExitTime"]}, Function[t, captionDraw[s, t, {t0, t1}, o]]]];

captionDraw[s_, t_, {t0_, t1_}, o_] := Module[{f = layerFont[o], p = layerPoint[ov[o, Position]], lines, k = 0, di = ov[o, "WordInterval"],
    xt = ov[o, "ExitTime"], leave, hl = StringDelete[#, PunctuationCharacter] & /@ Flatten[{ov[o, "Highlight"]}]},
    lines = CanvasWrap[s, f, ov[o, "Width"]];
    leave = Easing["InCubic"][localU[t, t1, t1 + xt]];
    MapIndexed[Function[{ln, li}, Module[{cx = p[[1]]}, Table[
        With[{a = Easing["OutExpo"][localU[t, t0 + k di, t0 + k di + 0.2]]}, k++;
            {CanvasText[w, {cx, p[[2]] + (li[[1]] - 1) ov[o, "LineHeight"] f["Size"] + 22 (1 - a) + 16 leave}, f,
                If[MemberQ[hl, StringDelete[w, PunctuationCharacter]], ov[o, "HighlightColor"], ov[o, FontColor]],
                Opacity -> a (1 - leave)],
             cx += CanvasTextWidth[w <> " ", f]}[[1]]], {w, StringSplit[ln]}]]], lines]];
