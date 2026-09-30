(* Tests for AnimatedGraphics, the canvas kit, the elements and the music.  Run: TestReport["WAnim/Tests/Toolkit.wlt"] after loading the paclet. *)

(* elements *)
VerificationTest[Head[Typewriter["abc", {0, 1}]], AnimatedGraphics, TestID -> "Typewriter-is-AnimatedGraphics"]
VerificationTest[Typewriter["abc", {0, 1}]["Span"], {0, 1}, TestID -> "Typewriter-span"]
VerificationTest[CaptionText["a b", {0, 1}]["Span"], {0, 1.25}, TestID -> "CaptionText-span-includes-exit"]
VerificationTest[AnimatedGraphics[{Backdrop[Red], TitleCard["x", {0, 3}]}]["Duration"], 3, TestID -> "Duration-from-spans"]
VerificationTest[AnimatedGraphics[{{2, 5} -> TitleCard["x", {0, 3}]}]["Duration"], 5, TestID -> "Duration-nested-span"]
VerificationTest[ImageDimensions[Rasterize[AnimatedGraphics[{Backdrop[Blue]}, "CanvasSize" -> {320, 180}, "Duration" -> 1][0.5, ImageSize -> 320], "Image", ImageResolution -> 72]], {320, 180}, TestID -> "Frame-size"]
VerificationTest[Head[AnimatedGraphics[{Backdrop[Blue]}, "Duration" -> 1][0.5]], Graphics, TestID -> "Frame-is-Graphics"]
VerificationTest[Head[Typewriter["abc", {0, 1}][0.5]], Graphics, TestID -> "Element-frame"]
VerificationTest[FreeQ[TitleCard["Wolfram Language", {0, 2}, "Highlight" -> "Wolfram"][1], RGBColor["#DD1100"]], False, TestID -> "TitleCard-highlight"]
VerificationTest[FreeQ[TitleCard["ink", {0, 2}, FontColor -> (If[# < 1, Red, Blue] &)][1.5], Blue], False, TestID -> "Option-as-function-of-time"]
VerificationTest[FreeQ[AnimatedGraphics[{TitleCard["ink", {0, 2}]}, BaseStyle -> {"Highlight" -> "ink", "HighlightColor" -> Green}][1], Green], False, TestID -> "BaseStyle-inherited"]
VerificationTest[Head[Backdrop[Red, {0, 1}, "Enter" -> "Fade", "EnterTime" -> 0.5][0.25]], Graphics, TestID -> "Backdrop-fades"]

(* the time model: functions read the enclosing clock, nested graphics under a span start their own *)
VerificationTest[Cases[AnimatedGraphics[{{1, 3} -> Function[t, Point[{t, 0}]]}, PlotRange -> {{0, 5}, {-1, 1}}]["Primitives", 2], Point[p_] :> p, Infinity], {{2, 0}}, TestID -> "Function-absolute-time"]
VerificationTest[Cases[AnimatedGraphics[{{1, 3} -> AnimatedGraphics[Function[t, Point[{t, 0}]]]}, PlotRange -> {{0, 5}, {-1, 1}}]["Primitives", 2], Point[p_] :> p, Infinity], {{1, 0}}, TestID -> "Nested-local-time"]

(* canvas primitives are symbolic until drawn, and follow the plot range *)
VerificationTest[Head[CanvasRectangle[{0, 0, 10, 10}, Red]], CanvasRectangle, TestID -> "Canvas-inert"]
VerificationTest[FreeQ[AnimatedGraphics[{Disk[], CanvasText["hi", {100, 100}, CanvasFont["Source Sans 3", 40], White]}, PlotRange -> {{-2, 2}, {-1, 1}}][0], _Inset], False, TestID -> "Canvas-over-plot-range"]
VerificationTest[Easing["OutCubic"][0.5], 0.875, TestID -> "Easing-outcubic"]
VerificationTest[Easing["Linear"] /@ {-1, 0.3, 2}, {0, 0.3, 1}, TestID -> "Easing-clamps"]
VerificationTest[TypedText["hello", 0.4], "he", TestID -> "TypedText"]
VerificationTest[CanvasTextWidth["abc", CanvasFont["Source Code Pro", 10]] > 0, True, TestID -> "CanvasTextWidth-positive"]
VerificationTest[Length[CanvasWrap["aaa bbb ccc ddd", CanvasFont["Source Code Pro", 10], 40]] > 1, True, TestID -> "CanvasWrap-wraps"]

(* shapes that play effects *)
VerificationTest[Length[AnimatedGraphics[{"a", "+", "b"}]["Primitives"]], 3, TestID -> "TeX-parts"]
VerificationTest[AnimatedGraphics[Disk[]]["Play", "Wait", "Duration" -> 2]["Play", "Rotate", Pi]["Duration"], 3, TestID -> "Effects-duration"]
VerificationTest[Head[AnimatedGraphics[{AnimatedGraphics[Disk[]]["Play", "Transform", AnimatedGraphics[Rectangle[]]]}, PlotRange -> {{-2, 2}, {-2, 2}}][0.5]], Graphics, TestID -> "Transform-plays"]
VerificationTest[Head[AnimatedGraphics[{Backdrop[Black], {0, 1} -> AnimatedGraphics[Function[t, {White, Disk[{t, 0}, 0.5]}], PlotRange -> {{-4, 4}, {-2, 2}}, "Screen" -> {100, 100, 800, 400}]}][0.5]], Graphics, TestID -> "Screen-inset"]
VerificationTest[Head[AnimatedImage[AnimatedGraphics[{Backdrop[Red]}, "Duration" -> 0.2, "CanvasSize" -> {160, 90}], FrameRate -> 10]], AnimatedImage, TestID -> "AnimatedImage"]
VerificationTest[Tween[{0, 1}] /@ {-1, 0.5, 2}, {0, 0.5, 1}, SameTest -> (Norm[N[#1 - #2]] < 10^-6 &), TestID -> "Tween-clamped"]
VerificationTest[Tween[{{1, 110}, {2, 40}, {3, 180}}] /@ {0, 2, 5}, {110, 40, 180}, TestID -> "Tween-keyframes"]
VerificationTest[Length[First[Morph[Rectangle[{-1, -1}, {1, 1}], Disk[]][0.5]]], 120, TestID -> "Morph-points"]
VerificationTest[Round[Total[Norm /@ Differences[First[PartialPath[Circle[], 1/2]]]], 0.01], Round[N[Pi], 0.01], TestID -> "PartialPath-half-circle"]

(* the elements *)
VerificationTest[Length[NotebookEra[]], 10, TestID -> "NotebookEra-names"]
VerificationTest[NotebookEra["BigSur2020", "Page" -> Black]["Page"], Black, TestID -> "NotebookEra-change"]
VerificationTest[AllTrue[NotebookEra[], FreeQ[NotebookSession[{{0, "In", "1 + 1"}}, {0, 1}, "Era" -> #, "Evaluate" -> True][0.9], _Missing | $Failed] &], True, TestID -> "NotebookEra-all-draw"]
VerificationTest[Head[NotebookSession[{{0, "In", "1 + 1"}}, {0, 1}, "Evaluate" -> True][0.9]], Graphics, TestID -> "NotebookSession-evaluates"]
VerificationTest[FreeQ[NotebookSession[{{0, "In", "1"}}, {0, 4}, "Hide" -> {{1, 2}}][1.5], _Inset], True, TestID -> "NotebookSession-hide"]
VerificationTest[With[{a = NotebookSession[{{0, "In", "1"}}, {0, 1}]}, Head[NotebookSession[{{1, "In", "2"}}, {1, 2}, "From" -> a, "Era" -> "NeXT1988"][1.05]]], Graphics, TestID -> "NotebookSession-wipe"]
VerificationTest[Head[Spikey[{0, 1}, "Version" -> 4][0.5]], Graphics, TestID -> "Spikey-version"]
VerificationTest[Head[Spikey[{0, 1}, "Face" -> True, "Raise" -> (# &), "Blink" -> (# > 0.5 &), Position -> ({100 + 50 #, 100} &)][0.7]], Graphics, TestID -> "Spikey-face"]
VerificationTest[Head[TreeDiagram[Hold[{x -> 1, f[y]}], {0, 2}][1.5]], Graphics, TestID -> "TreeDiagram-draws"]
VerificationTest[Head[TileGrid[{{"Plot", Plot[x, {x, 0, 1}], "1.0"}}, {0, 2}][1]], Graphics, TestID -> "TileGrid-draws"]
VerificationTest[Head[WordScroll[{"Plot", "ListPlot"}, {0, 2}][1]], Graphics, TestID -> "WordScroll-draws"]
VerificationTest[Head[TerminalSession[{{0.1, "1 + 1"}, {0.5, "2", "Output"}}, {0, 1}][0.7]], Graphics, TestID -> "TerminalSession-draws"]
VerificationTest[With[{w = WordWall[{{"alpha", 1., 0}, {"beta", 0.1, 0}}, {0, 1}]}, {Sort[Keys[w["Places"]]], Head[WordWall[{{"alpha", 1., 0}, {"beta", 0.1, 0}}, {0, 1},
    "Camera" -> (CanvasScale[3, w["Places"]["alpha"]] &), "Emphasis" -> ({# === "beta" &, 1} &)][0.5]]}], {{"alpha", "beta"}, Graphics}, TestID -> "WordWall-camera"]

(* sound *)
VerificationTest[Length[Track[{{0, 1/2, 60}, {1/2, 1/2, 64}, {1, 1, 67}}]["Query", 0, 1]], 2, TestID -> "Track-events-query"]
VerificationTest[TrackPulse[Track[{{0, 1/4, "bd"}}], 18][0], 1., TestID -> "TrackPulse-onset"]
VerificationTest[Track["bd sd, hh*4"]["Query", 0, 1][[All, "Value"]], {"bd", "sd", "hh", "hh", "hh", "hh"}, TestID -> "Track-top-level-stack"]
VerificationTest[Track["bd [sd"]["Query", 0, 1], {}, {Track::parse}, TestID -> "Track-parse-message"]
VerificationTest[Length[Track["bd sd/2"]["Query", 0, 2]], 4, TestID -> "Track-slow-modifier"]
VerificationTest[{TrackSpeed[2][Track["a b"]]["Source"], TrackSpeed[1/2][Track["a b"]]["Source"], TrackShift[-1/4][Track["a"]]["Source"]},
    {"a b // fast 2", "a b // slow 2", "a // early 1/4"}, TestID -> "Track-source-chain"]
VerificationTest[Track["c4 e4 // fast 2 // sound pluck // gain 0.5"]["Query", 0, 1] === TrackSpeed[2][Track["c4 e4"]]["Query", 0, 1], True, TestID -> "Track-source-parses-back"]
VerificationTest[Instrument["Pluck", "Gain" -> 0.5][Track["c4 e4"]]["Source"], "c4 e4 // sound pluck // gain 0.5", TestID -> "Instrument-source"]
VerificationTest[Lookup[WolframInstitute`WAnim`PackageScope`metaOf[Instrument["Gain" -> 0.5][Instrument["Gain" -> 0.5][Track["c4"]]]]["Instrument"], "Gain"], 0.25, TestID -> "Instrument-gain-multiplies"]
VerificationTest[Length[TrackEuclid[3, 8][Track["bd"]]["Onsets", 0, 1]], 3, TestID -> "TrackEuclid"]
VerificationTest[TrackScale["c:minor"][Track["0 2 4"]]["Query", 0, 1][[All, "Value"]], {60, 63, 67}, TestID -> "TrackScale"]
VerificationTest[Length[TrackStruct["1 ~ 1 1"][Track["c4"]]["Query", 0, 1]], 3, TestID -> "TrackStruct"]
VerificationTest[Length[Reverse[Track[{Track["a b"], Track["c"]}]]["Voices"]], 2, TestID -> "Reverse-stack"]
VerificationTest[Block[{$CyclesPerSecond = 1/2}, Max[Abs[AudioData[Audio[Track["bd sd, hh*4"], 1]]]] > 0.5], True, TestID -> "Track-stack-sounds"]
VerificationTest[Round[QuantityMagnitude[Duration[Audio[Track["bd*4"], 2, "CyclesPerSecond" -> 1/2]], "Seconds"], 0.01], 4., TestID -> "Audio-tempo-option"]
VerificationTest[Max[Abs[AudioData[Audio[Track["c4 e4"], 1]]]] > 0.1, True, TestID -> "Pitched-track-sounds"]
VerificationTest[Round[QuantityMagnitude[Duration[Audio[AnimatedGraphics[{Backdrop[Black], Track["bd*4"]}, "Duration" -> 1, "CyclesPerSecond" -> 1/2]]], "Seconds"], 0.01], 2., TestID -> "AnimatedGraphics-sound-tempo"]
VerificationTest[Length[Instrument[]], 26, TestID -> "Instrument-list"]
VerificationTest[With[{a = Audio[Mixer["Sidechain" -> Track[{{0, 1/4, "bd"}}]][Track[{Instrument["Kick"][Track[{{0, 1/4, "bd"}}]], Instrument["Pluck"][Track[{{1/2, 1/8, 69, 0.8}}]]}]], 1, "CyclesPerSecond" -> 1/2]},
    {AudioChannels[a], Round[QuantityMagnitude[Duration[a], "Seconds"], 0.01], AudioMeasurements[a, "Max"] > 0.1}], {2, 2., True}, TestID -> "Instrument-mix"]
VerificationTest[Block[{$CyclesPerSecond = 1}, With[{a = Audio[Track[{{0, 1/4, "bd", 1}, {1/2, 1/4, "bd", 0.1}}], 1, "CyclesPerSecond" -> 1]},
    With[{d = Abs[First[AudioData[a]]]}, Max[d[[;; 20000]]] > 3 Max[d[[22051 ;; 42000]]]]]], True, TestID -> "Kit-velocity"]
VerificationTest[With[{a = Audio[Instrument["Pan" -> -1][Track["c4"]], 1, "CyclesPerSecond" -> 1]}, Max[Abs[AudioData[a][[1]]]] > 2 Max[Abs[AudioData[a][[2]]]]], True, TestID -> "Instrument-pan"]
VerificationTest[Head[TrackView["Punchcard", "Cycles" -> 4][Track["bd*4"]]["Punchcard"]], Graphics, TestID -> "TrackView-punchcard"]
VerificationTest[TrackView["Cycles" -> 4][Track["bd*4"]]["Cycles"], 4, TestID -> "TrackView-cycles"]
VerificationTest[With[{v = Track["bd sd"]["Video", 1, FrameRate -> 4, ImageSize -> 200, "View" -> "Punchcard", "CyclesPerSecond" -> 1]},
    {Head[v], Round[QuantityMagnitude[Information[v, "Duration"], "Seconds"]]}], {Video, 1}, TestID -> "Track-video"]
VerificationTest[Length[Cases[WolframInstitute`WAnim`AnimatedGraphics`Private`foley[AnimatedGraphics[{Typewriter["abc", {0, 1}, "TypeTime" -> 0.5]}], 0], {_, "Tick", _}]], 3, TestID -> "Foley-keystrokes"]
