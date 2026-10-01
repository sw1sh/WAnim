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
    "Credit" -> None, "Subtitle" -> None, "Volume" -> 1, "Duck" -> 0.2, "Sound" -> True, "FrameRate" -> 15, "Grain" -> 0,
    "Paper" -> RGBColor["#EDE9E0"], "Enter" -> "Fade", "Exit" -> "Fade", "EnterTime" -> 0.15, "ExitTime" -> 0.15}];

(* ArchiveClip[video, {t0, t1}] plays an archival film -- a lecture, an interview, an experiment -- over its
   span: its picture in the frame, its sound in the film's soundtrack, the music ducked beneath it ("Duck",
   the music's gain while it speaks; "Sound" -> False for a silent clip, "Volume" for its level).  video is a
   Video, a file or a URL; "From" and "To" pick the moment, in seconds of the source.  The span maps onto
   that moment, so for the picture to keep pace with the sound give it the moment's length in cycles.
   "Style" -> "Frame" shows it as a print on the page at Position (top-left) within "Size"; "Full" fills the
   canvas.  "Credit" is the small line beneath it (who, where, when, whose film), "Subtitle" the words said,
   set at the foot of the frame.  The frames are read from the source once per kernel, at "FrameRate". *)
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
clipFrames[file_, {in_, out_}, fps_, px_] := clipFrames[file, {in, out}, fps, px] = Module[{v = Video[file], times = Range[N[in] + 0.5 / fps, N[out], 1. / fps], n, frames = $Failed},
    (* each frame is read at the middle of its moment: a video track often starts a little after its
       container and ends a little before; the last times that cannot be read repeat the last frame that can *)
    n = Length[times];
    While[n > 0 && ! ListQ[frames = Quiet[VideoExtractFrames[v, Take[times, n]]]], n = Floor[0.9 n]];
    If[n == 0, {}, PadRight[ImageResize[#, px] & /@ frames, Length[times], ImageResize[Last[frames], px]]]];

(* the moment's sound, as a voice: clipVoice[audio, duck], the gain the film's music ducks to under it *)
clipAudio[file_, {in_, out_}, vol_, duck_] := clipVoice[AudioTrim[Audio[file], {in, out}] vol, duck];

clipDraw[file_, {in_, out_}, t_, {t0_, t1_}, o_] := Module[{full = ov[o, "Style"] === "Full", fps = ov[o, "FrameRate"], env = envelope[t, {t0, t1}, o],
        box, p, d, w, h, k, frames, frame, sub = ov[o, "Subtitle"], credit = ov[o, "Credit"]},
    box = Replace[ov[o, "Size"], Automatic :> If[full, $canvasSize, {640, 480}]];
    p = If[full, {0, 0}, Replace[ov[o, Position], Automatic | Center :> ($canvasSize - box) / 2]];
    frames = clipFrames[file, {in, out}, fps, Round[box[[1]]]];
    If[frames === {} || ! ListQ[frames], Return[{}]];
    d = ImageDimensions[First[frames]]; {w, h} = d Min[box[[1]] / d[[1]], box[[2]] / d[[2]]];
    k = Clip[1 + Floor[Length[frames] (t - t0) / (t1 - t0)], {1, Length[frames]}];
    frame = frames[[k]];
    CanvasOpacity[env["Alpha"], {
        If[full, {CanvasRectangle[{0, 0, $canvasSize[[1]], $canvasSize[[2]]}, Black], CanvasImage[frame, {(box[[1]] - w) / 2, (box[[2]] - h) / 2, w, h}]},
            {CanvasRectangle[{p[[1]] - 14, p[[2]] - 14, w + 28, h + 28}, ov[o, "Paper"]], CanvasImage[frame, {p[[1]], p[[2]], w, h}]}],
        If[StringQ[credit], CanvasText[credit, If[full, {48, $canvasSize[[2]] - 40}, {p[[1]] - 14, p[[2]] + h + 50}], CanvasFont[defaultFont["Sans"], 24, 400], RGBColor["#8E8B84"]], {}],
        If[StringQ[sub], clipSubtitle[sub, If[full, {$canvasSize[[1]] / 2, $canvasSize[[2]] - 110}, {p[[1]] + w / 2, p[[2]] + h - 36}]], {}]}]];

(* subtitles as film subtitles: white on a shadow, centred *)
clipSubtitle[s_, {cx_, y_}] := With[{f = CanvasFont[defaultFont["Sans"], 38, 500]}, With[{w = CanvasTextWidth[s, f]},
    {CanvasRectangle[{cx - w / 2 - 16, y - 40, w + 32, 54}, Black, Opacity -> 0.55, "Radius" -> 6], CanvasText[s, {cx - w / 2, y}, f, White]}]];
