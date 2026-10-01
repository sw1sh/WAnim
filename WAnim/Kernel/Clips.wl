(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{ArchiveClip}]


(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{clipVoice}]


(* ::Section:: *)
(*ArchiveClip*)

Options[ArchiveClip] = elementOptions[{Position -> Automatic, "Size" -> Automatic, "From" -> 0, "To" -> Automatic, "Style" -> "Frame",
    "Credit" -> None, "Subtitle" -> None, "Show" -> All, "Zoom" -> 0, "Volume" -> Automatic, "Duck" -> 0.2, "Sound" -> True, "FrameRate" -> 12,
    "Paper" -> RGBColor["#EDE9E0"], "Enter" -> "Fade", "Exit" -> "Fade", "EnterTime" -> 0.15, "ExitTime" -> 0.15}];

(* ArchiveClip[video, {t0, t1}] plays an archival film -- a lecture, an interview, an experiment -- over its
   span: its picture in the frame, its sound in the film's soundtrack, the music ducked beneath it ("Duck",
   the music's gain while it speaks; "Sound" -> False for a silent clip, "Volume" for its level: Automatic
   brings every clip to one loudness, as old recordings differ widely).  video is a
   Video, a file or a URL; "From" and "To" pick the moment, in seconds of the source.  The span maps onto
   that moment, so for the picture to keep pace with the sound give it the moment's length in cycles.
   "Style" -> "Frame" shows it as a print on the page at Position (top-left) within "Size"; "Full" fills the
   canvas, pillarboxed, pushing in slowly by "Zoom" (a fraction over the clip).  "Show" -> {{ta, tb}, ...} shows
   the picture only then -- cut away while the voice goes on.  "Credit" names the speaker: a string, or
   {"name", "where and when"}, a lower third the first time the picture shows (under a print, a line beneath it).
   "Subtitle" is the words, at the foot of the canvas while they are said: a string, or {{s0, s1, "line"}, ...}
   in seconds from "From".  The frames are read from the source once per kernel, at "FrameRate". *)
ArchiveClip[src_, {t0_, t1_}, opts : OptionsPattern[]] := With[{o = toolOptions[{opts}, ArchiveClip]},
    With[{file = clipFile[src], in = ov[o, "From"]},
        With[{out = Replace[ov[o, "To"], Automatic :> clipDuration[file]]},
            AnimatedGraphics[<|"Primitives" -> {{t0, t1} -> Function[t, clipDraw[file, {in, out}, t, {t0, t1}, drawOptions[{opts}, ArchiveClip, t]]],
                    If[TrueQ[ov[o, "Sound"]], {t0, t1} -> clipAudio[file, {in, out}, ov[o, "Volume"], ov[o, "Duck"]], Nothing]},
                "Directive" -> {}, "Effects" -> {}, "Options" -> {}, "Name" -> "ArchiveClip", "Span" -> {t0, t1}, "Source" -> file, "Moment" -> {in, out}|>]]]];

(* a source as a local file: URLs are downloaded once, into the user's WAnim cache, so every kernel reads
   the same file *)
clipFile[v_Video] := clipFile[Information[v, "ResourcePath"]];
clipFile[File[f_]] := clipFile[f];
clipFile[u_URL] := clipFile[First[u]];
clipFile[s_String] /; StringStartsQ[s, "http"] := Module[{dir = FileNameJoin[{$UserBaseDirectory, "ApplicationData", "WAnim", "Clips"}], f},
    f = FileNameJoin[{dir, IntegerString[Hash[s, "CRC32"], 36] <> "." <> Replace[FileExtension[URLParse[s, "Path"] /. {} -> {""} // Last], "" -> "mp4"]}];
    If[! FileExistsQ[f], Quiet @ CreateDirectory[dir]; URLDownload[s, f]];
    f];
clipFile[s_String] := ExpandFileName[s];
clipDuration[file_] := QuantityMagnitude[Duration[Video[file]], "Seconds"];

(* the moment's frames, at the clip's frame rate and the size they are drawn at, read once per kernel *)
(* the moment's frames, at the clip's frame rate, no wider than drawn (nor than 960 pixels), read once per
   kernel; only the last two clips are kept, as a film's frames are drawn in order *)
clipFrames[file_, {in_, out_}, fps_, px0_] := With[{key = {file, in, out, fps, Min[px0, 960]}},
    Lookup[$clipCache, Key[key], With[{f = readFrames[file, {in, out}, fps, Min[px0, 960]]}, $clipCache = Append[KeyTake[$clipCache, Take[Keys[$clipCache], -1]], key -> f]; f]]];
$clipCache = <||>;
readFrames[file_, {in_, out_}, fps_, px_] := Module[{v = Video[file], times = Range[N[in] + 0.5 / fps, N[out], 1. / fps], n, frames = $Failed},
    (* each frame is read at the middle of its moment: a video track often starts a little after its
       container and ends a little before; the last times that cannot be read repeat the last frame that can *)
    n = Length[times];
    While[n > 0 && ! ListQ[frames = Quiet[VideoExtractFrames[v, Take[times, n]]]], n = Floor[0.9 n]];
    If[n == 0, {}, PadRight[If[ImageDimensions[#][[1]] > px, ImageResize[#, px], #] & /@ frames, Length[times], Last[frames]]]];

(* the moment's sound, as a voice: clipVoice[audio, duck], the gain the film's music ducks to under it *)
clipAudio[file_, {in_, out_}, vol_, duck_] := With[{a = AudioTrim[Audio[file], {in, out}]},
    clipVoice[a If[vol === Automatic, Min[8, 0.09 / Max[10^-4, AudioMeasurements[a, "RMSAmplitude"]]], vol], duck]];

clipDraw[file_, {in_, out_}, t_, {t0_, t1_}, o_] := Module[{full = ov[o, "Style"] === "Full", fps = ov[o, "FrameRate"], env = envelope[t, {t0, t1}, o],
        box, p, d, w, h, k, frames, frame, sec, show = ov[o, "Show"], shown, first, z, sub, credit = ov[o, "Credit"]},
    box = Replace[ov[o, "Size"], Automatic :> If[full, $canvasSize, {640, 480}]];
    p = If[full, {0, 0}, Replace[ov[o, Position], Automatic | Center :> ($canvasSize - box) / 2]];
    sec = in + (out - in) (t - t0) / (t1 - t0);
    shown = show === All || AnyTrue[show, #[[1]] <= t < #[[2]] &];
    first = If[show === All, t0, Min[show[[All, 1]]]];
    sub = Replace[ov[o, "Subtitle"], {l_List :> SelectFirst[l, #[[1]] <= sec - in < #[[2]] &, {0, 0, None}][[3]], s_String :> s, _ -> None}];
    frames = If[shown, clipFrames[file, {in, out}, fps, Round[box[[1]]]], {}];
    {If[shown && ListQ[frames] && frames =!= {}, (
        d = ImageDimensions[First[frames]]; {w, h} = d Min[box[[1]] / d[[1]], box[[2]] / d[[2]]];
        k = Clip[1 + Floor[Length[frames] (t - t0) / (t1 - t0)], {1, Length[frames]}];
        frame = frames[[k]]; z = 1 + ov[o, "Zoom"] (t - t0) / (t1 - t0);
        CanvasOpacity[env["Alpha"], {
            If[full, {CanvasRectangle[{0, 0, $canvasSize[[1]], $canvasSize[[2]]}, Black],
                    CanvasClip[{0, 0, $canvasSize[[1]], $canvasSize[[2]]}, CanvasImage[frame, {(box[[1]] - z w) / 2, (box[[2]] - z h) / 2, z w, z h}]]},
                {CanvasRectangle[{p[[1]] - 14, p[[2]] - 14, w + 28, h + 28}, ov[o, "Paper"]], CanvasImage[frame, {p[[1]], p[[2]], w, h}]}],
            Which[credit === None, {},
                full, If[first <= t < first + 4, lowerThird[credit, Clip[(t - first) / 0.3, {0, 1}] Clip[(first + 4 - t) / 0.3, {0, 1}]], {}],
                True, CanvasText[StringRiffle[Flatten[{credit}], " \[CenterDot] "], {p[[1]] - 14, p[[2]] + h + 50}, CanvasFont[defaultFont["Sans"], 24, 400], RGBColor["#8E8B84"]]]}]), {}],
     If[StringQ[sub], CanvasOpacity[env["Alpha"], clipSubtitle[sub, {$canvasSize[[1]] / 2, $canvasSize[[2]] - 70}]], {}]}];

(* the speaker's name, as a documentary sets it: bottom left, a red rule, name and occasion *)
lowerThird[credit_, a_] := With[{l = Flatten[{credit}], y = $canvasSize[[2]] - 210}, CanvasOpacity[a, {
    CanvasRectangle[{90, y - 52, 6, If[Length[l] > 1, 96, 56]}, RGBColor["#DD1100"]],
    CanvasText[l[[1]], {116, y - 10}, CanvasFont[defaultFont["Sans"], 44, 700], White],
    If[Length[l] > 1, CanvasText[l[[2]], {118, y + 32}, CanvasFont[defaultFont["Sans"], 28, 400], RGBColor["#D8D4CC"]], {}]}]];

(* subtitles as film subtitles: white on a shadow, centred *)
clipSubtitle[s_, {cx_, y_}] := With[{f = CanvasFont[defaultFont["Sans"], 36, 500]}, With[{w = CanvasTextWidth[s, f]},
    {CanvasRectangle[{cx - w / 2 - 16, y - 40, w + 32, 54}, Black, Opacity -> 0.55, "Radius" -> 6], CanvasText[s, {cx - w / 2, y}, f, White]}]];
