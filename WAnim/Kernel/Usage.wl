(* ::Package:: *)

(* ::Section:: *)
(*Usage messages for every exported symbol*)

(* ::Subsection:: *)
(*AnimatedGraphics and elements*)

AnimatedGraphics::usage = "AnimatedGraphics[{content, \[Ellipsis]}] is graphics in time: graphics primitives, {t0, t1} -> x shown from t0 to t1, functions of time, elements such as TitleCard and nested AnimatedGraphics, and Track or Audio for its sound.
AnimatedGraphics[\[Ellipsis]][t] is the frame at time t; Export[\"file.mp4\", g], Video[g], AnimatedImage[g] and Audio[g] render it; g[\"Play\", effect] plays an AnimationEffect after the ones before.
AnimatedGraphics[\"tex\"] and AnimatedGraphics[{\"tex1\", \"tex2\", \[Ellipsis]}] typeset TeX with MaTeX, the parts as g[\"Part\", i].";
Backdrop::usage = "Backdrop[colour] fills the canvas with colour; Backdrop[colour, {t0, t1}] only between t0 and t1. The colour may be a function of time, and it can fade in and out.";
Easing::usage = "Easing[name] is an easing curve on [0, 1], such as \"Linear\", \"Smooth\", \"InOutCubic\", \"OutExpo\" or \"OutBack\".
Easing[name, s] gives a curve with parameter s; Easing[\"Names\"] lists them.";
TrackPulse::usage = "TrackPulse[track, decay][t] is 1 at each onset of track and decays exponentially by decay per cycle until the next, to lock motion to sound.";
CanvasScreen::usage = "CanvasScreen[{x, y, w, h}, f] draws f[lw, lh] on an old display placed in a canvas rectangle, at its own logical resolution (\"Pixel\") and colour depth (\"Depth\").";

(* ::Subsection:: *)
(*Motion*)

Tween::usage = "Tween[{a, b}] is a function of time going from 0 to 1 between a and b along an easing curve.
Tween[{a, b}, {x, y}] goes from x to y, numbers, points or colours.
Tween[{{t1, v1}, {t2, v2}, \[Ellipsis]}] moves through keyframes, holding between them.";
Morph::usage = "Morph[a, b] is a function of u giving shape a at u = 0 turning into shape b at u = 1, as a Polygon.
Morph[a, b, u] is that shape at u.";
PartialPath::usage = "PartialPath[shape, u] is the first fraction u of the outline of shape, as a Line.";

(* ::Subsection:: *)
(*Typography*)

Typewriter::usage = "Typewriter[\"text\", {t0, t1}] types text behind a blinking cursor from t0, then lights up its \"Highlight\" words.";
TitleCard::usage = "TitleCard[\"text\", {t0, t1}] sets display type that rises, fades, pops or arrives letter by letter, and can collapse away.";
CaptionText::usage = "CaptionText[\"text\", {t0, t1}] is a sentence arriving word by word on a beat grid, wrapped to a column, its \"Highlight\" words in red.";
DictionaryCard::usage = "DictionaryCard[\"name\", {t0, t1}] is a dictionary entry for a Wolfram Language symbol: its name, usage and the version that introduced it, looked up live.";
TypedText::usage = "TypedText[\"text\", u] is the part of text typed by a fraction u of the way through.";

(* ::Subsection:: *)
(*Screens and eras*)

TerminalSession::usage = "TerminalSession[{{t, \"line\"}, \[Ellipsis]}, {t0, t1}] is a green-phosphor terminal that powers on, types the lines on the clock, prints and powers off.";
NotebookSession::usage = "NotebookSession[{{t, \"In\", \"code\"}, {t, \"Out\", output}, \[Ellipsis]}, {t0, t1}] is a notebook window of its \"Era\", typing and evaluating the cells on the clock; \"ChatInput\" and \"ChatOutput\" cells and a \"ChatBar\" make it a chat notebook.";
NotebookEra::usage = "NotebookEra[\"name\"] is the look of the notebook in one era, its chrome, display and cell style, as an association.
NotebookEra[\"name\", key -> value, \[Ellipsis]] changes some of it; NotebookEra[] lists the eras.";
OrderedDither::usage = "OrderedDither[image, {w, h}] reduces image to one bit at w by h pixels with 4 by 4 Bayer dithering.";

(* ::Subsection:: *)
(*Cards, instruments, characters, diagrams*)

PhotoPrint::usage = "PhotoPrint[image, \"caption\", {t0, t1}] pins a photo like a print, tilted, with a kicker above and a caption below.";
NumberCounter::usage = "NumberCounter[f, {t0, t1}] shows the number f[t], flashing while it changes, with a \"Label\".";
YearRuler::usage = "YearRuler[{{t, year}, \[Ellipsis]}, {t0, t1}] is a ruler of years along the bottom of the frame whose marker jumps from date to date.";
WordWall::usage = "WordWall[{{\"word\", weight, t}, \[Ellipsis]}, {t0, t1}] lays a whole vocabulary out like a dictionary page, each word sized by its weight and popping in at its time t; \"Camera\" moves the page, \"Emphasis\" picks words out, and wall[\"Places\"] says where each word sits.";
Spikey::usage = "Spikey[{t0, t1}] is the Wolfram mascot as the \"Version\" of an era drew it, turning about its centre and pulsing on the onsets of a \"Pulse\" track; with \"Face\" -> True it wears the glasses and smile of the personified Spikey, and can \"Raise\" a hand.";
AutomatonTape::usage = "AutomatonTape[rule, track, {t0, t1}] feeds a cellular automaton sideways into a read head and names the notes track plays from it.";
TreeDiagram::usage = "TreeDiagram[Hold[expr], {t0, t1}] grows the tree of expr from its head down, level by level.";
TileGrid::usage = "TileGrid[{{\"label\", content, \"note\"}, \[Ellipsis]}, {t0, t1}] deals out cards on the beat, each showing content, a plot or a picture, or a function u |-> expr played as a loop.";
WordScroll::usage = "WordScroll[{\"word\", \[Ellipsis]}, {t0, t1}] rolls the words up the frame in faint columns, like credits.";

(* ::Subsection:: *)
(*The canvas kit*)

CanvasTransform::usage = "CanvasTransform[m, body] draws body under the 3 by 3 transform matrix m, composed with the current one, like a canvas context.";
CanvasTranslate::usage = "CanvasTranslate[{dx, dy}] is a translation matrix for CanvasTransform.";
CanvasScale::usage = "CanvasScale[s] and CanvasScale[{sx, sy}] are scaling matrices for CanvasTransform; CanvasScale[s, {cx, cy}] scales about a point.";
CanvasRotate::usage = "CanvasRotate[angle] is a rotation matrix for CanvasTransform, clockwise on screen.";
CanvasOpacity::usage = "CanvasOpacity[a, body] draws body at opacity a times the current one.";
CanvasRectangle::usage = "CanvasRectangle[{x, y, w, h}, colour] fills a canvas rectangle; \"Stroke\" -> width outlines it and \"Radius\" rounds its corners.";
CanvasPolygon::usage = "CanvasPolygon[{{x1, y1}, \[Ellipsis]}, colour] fills a polygon in canvas coordinates, or outlines it with \"Stroke\" -> width.";
CanvasLine::usage = "CanvasLine[{{x1, y1}, \[Ellipsis]}, colour] draws a line in canvas coordinates, \"Thickness\" pixels wide.";
CanvasDisk::usage = "CanvasDisk[{x, y}, r, colour] fills a disk of radius r pixels, or outlines it with \"Stroke\" -> width.";
CanvasImage::usage = "CanvasImage[image, {x, y, w, h}] draws image into a canvas rectangle; \"Fit\" -> \"Contain\" letterboxes it.";
CanvasGradient::usage = "CanvasGradient[{x, y, w, h}, dir, colour, {{u, opacity}, \[Ellipsis]}] fades a colour across a rectangle; CanvasGradient[{x, y, w, h}, dir, {{u, colour}, \[Ellipsis]}] blends colours. dir is \"Horizontal\", \"Vertical\" or \"Diagonal\".";
CanvasClip::usage = "CanvasClip[{x, y, w, h}, body] draws body only inside a canvas rectangle.";
CanvasFont::usage = "CanvasFont[family, size, weight, italic] is a font for CanvasText, with a CSS numeric weight.";
CanvasText::usage = "CanvasText[\"text\", {x, y}, font, colour] draws text with its alphabetic baseline at a canvas point.";
CanvasTextWidth::usage = "CanvasTextWidth[\"text\", font] is the width of text in canvas pixels, as a canvas measures it.";
CanvasWrap::usage = "CanvasWrap[\"text\", font, width] breaks text into lines no wider than width pixels.";

(* ::Subsection:: *)
(*Effects*)


AnimationEffect::usage = "AnimationEffect[name, args, opts] is an effect an AnimatedGraphics can play, such as \"Scale\", \"Rotate\", \"Translate\", \"Transform\" or \"Creation\" (Method -> \"Write\", \"Create\", \"FadeIn\", \[Ellipsis]), along an \"Easing\" curve. AnimationEffect[] lists them.";
BraceLabel::usage = "BraceLabel[g] is a curly brace under an AnimatedGraphics, typeset as a TeX brace and stretched to its width; BraceLabel[g, dir, label] adds a label, and \"Direction\" turns it.";

(* ::Subsection:: *)
(*Music*)

Track::usage = "Track[\"mini-notation\"] is a cyclic pattern of events, such as Track[\"bd [~ bd] sd, hh*8\"].
Track[{{onset, duration, value}, \[Ellipsis]}] plays exactly those events, a fourth element being the velocity; Track[{track1, track2, \[Ellipsis]}] stacks voices; Track[] is silence.
Audio[track, n] renders n cycles; track[\"Query\", a, b] gives the events between a and b; it shows itself as a live player.";
TrackSpeed::usage = "TrackSpeed[r][track] plays track r times faster; r < 1 plays it slower.";
TrackShift::usage = "TrackShift[t][track] plays track t cycles later; t < 0 plays it earlier.";
TrackSequence::usage = "TrackSequence[track1, track2, \[Ellipsis]] plays the tracks one after another within each cycle.";
TrackAlternate::usage = "TrackAlternate[track1, track2, \[Ellipsis]] plays one track per cycle, in turn.";
TrackEvery::usage = "TrackEvery[n, f][track] applies f to track on every nth cycle.";
TrackEuclid::usage = "TrackEuclid[k, n][track] plays track on k of n steps spread as evenly as possible; TrackEuclid[k, n, rot] rotates the rhythm.";
TrackDegrade::usage = "TrackDegrade[x][track] drops a fraction x of the events, the same ones every time.";
TrackSuperimpose::usage = "TrackSuperimpose[f][track] plays track together with f[track]; TrackSuperimpose[f, t] shifts f[track] t cycles later.";
TrackStruct::usage = "TrackStruct[\"1 ~ 1 1\"][track] plays the value of track on the steps marked 1; TrackStruct[positions, steps][track] on the given step positions of a cycle cut into steps.";
TrackScale::usage = "TrackScale[\"C:minor\"][track] reads integer values of track as degrees of the scale; TrackScale[] lists the scales.";
TrackPulse::usage = "TrackPulse[track, decay][t] is 1 at each onset of track and decays exponentially by decay per cycle until the next, to lock motion to sound.";
TrackView::usage = "TrackView[view, \[Ellipsis], opts][track] sets what track shows while it plays: \"PianoRoll\", \"Punchcard\", \"Oscilloscope\" or \"Bar\"; \"Cycles\" -> n shows and loops n cycles, \"Solo\" -> True silences the other tracks.
track[\"PianoRoll\", n] and track[\"Punchcard\", n] are still views.";
TrackPlay::usage = "TrackPlay[] starts the shared clock of the tracks playing live.";
TrackPause::usage = "TrackPause[] pauses the shared clock.";
TrackSeek::usage = "TrackSeek[pos] moves the shared clock to cycle pos.";
$CyclesPerSecond::usage = "$CyclesPerSecond is the tempo of live tracks, in cycles per second.";
$AudioLatency::usage = "$AudioLatency is the delay, in seconds, between the live clock and the sound.";

(* ::Subsection:: *)
(*The studio*)

Instrument::usage = "Instrument[name][track] plays track on an instrument synthesized sample by sample: \"Kit\" (drum samples by name), \"Kick\", \"Clap\", \"Hat\", \"Pluck\", \"Pad\", \"Bass\", \"Lead\", \"Bell\", \"Voice\", \"Sawtooth\", \[Ellipsis]; Instrument[] lists them. Instrument[<|name -> audio, \[Ellipsis]|>] and Instrument[File[dir]] play your own samples.
Instrument[opts][track] sets how it sounds: \"Gain\", \"Pan\", \"Reverb\" and \"Delay\" sends, and \"Decay\" in cycles.";
Mixer::usage = "Mixer[opts][track] sets how track is mixed: \"Sidechain\" -> a track to duck under, \"Cutoff\" -> f for a low-pass on the music bus at f[cycle] Hz, \"DelayTime\", \"DelayFeedback\", \"Master\" and \"FadeOut\", times in cycles.";
GPUGraphics::usage = "GPUGraphics[graphics] draws a Graphics on the GPU, without the front end, into an Image; GPUGraphics[primitives, options] takes what Graphics takes.";
