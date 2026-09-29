(* ::Package:: *)

(* ::Section:: *)
(*Usage messages for every exported symbol*)

(* ::Subsection:: *)
(*Timelines and layers*)

Timeline::usage = "Timeline[{layer1, layer2, \[Ellipsis]}] is a film: layers stacked in time and drawn in order.
Timeline[\[Ellipsis]][\"Graphics\", t] and Timeline[\[Ellipsis]][\"Image\", t] give the frame at time t; Timeline[\[Ellipsis]][\"Dynamic\"] plays it live, clocked by its soundtrack; Timeline[\[Ellipsis]][\"Video\", file] renders it to a Video; Timeline[\[Ellipsis]][\"AnimatedImage\"] makes an AnimatedImage; Timeline[\[Ellipsis]][\"Audio\"] is its soundtrack.";
TimelineLayer::usage = "TimelineLayer[\[LeftAssociation]\"Span\" -> {t0, t1}, \"Draw\" -> f\[RightAssociation]] is one segment of a Timeline, drawing f[t] while t0 <= t < t1; every creation tool returns one.
TimelineLayer[\[Ellipsis]][\"Graphics\", t] shows it alone at time t; TimelineLayer[\[Ellipsis]][\"Shift\", dt] moves it in time.";
Backdrop::usage = "Backdrop[colour] fills the canvas with colour; Backdrop[colour, {t0, t1}] only between t0 and t1. The colour may be a function of time.";
$LayerOptions::usage = "$LayerOptions is the list of options every creation tool accepts: Position, Alignment, the font options, Opacity, \"Enter\", \"Exit\", \"EnterTime\" and \"ExitTime\".";
Easing::usage = "Easing[name] is an easing curve on [0, 1], such as \"Linear\", \"Smooth\", \"InOutCubic\", \"OutExpo\" or \"OutBack\".
Easing[name, s] gives a curve with parameter s; Easing[\"Names\"] lists them.";
EventTrack::usage = "EventTrack[{{onset, duration, value}, \[Ellipsis]}] is a Track of written-out events: notes (MIDI numbers or names) or drum sounds, times in cycles.";
TrackPulse::usage = "TrackPulse[track, decay][t] is 1 at each onset of track and decays exponentially by decay per cycle until the next, to lock motion to sound.";
CanvasScreen::usage = "CanvasScreen[{x, y, w, h}, f] draws f[lw, lh] on an old display placed in a canvas rectangle, at its own logical resolution (\"Pixel\") and colour depth (\"Depth\").";
RasterScreen::usage = "RasterScreen[primitives, {{x0, y0}, {x1, y1}}] draws primitives, given in the screen's logical pixels, into a rectangle as an old display would.";

(* ::Subsection:: *)
(*The stage*)

Stage::usage = "Stage[f, {t0, t1}] is a layer drawing f[t], ordinary graphics in math coordinates (Manim's 14.2 by 8 frame by default), over the canvas.
Stage[{obj1, obj2, \[Ellipsis]}, {t0, t1}] draws a fixed scene whose AnimatedObjects play their effects from t0.";
Tween::usage = "Tween[{a, b}] is a function of time going from 0 to 1 between a and b along an easing curve.
Tween[{a, b}, {x, y}] goes from x to y, numbers, points or colours.
Tween[{{t1, v1}, {t2, v2}, \[Ellipsis]}] moves through keyframes, holding between them.";
Morph::usage = "Morph[a, b] is a function of u giving shape a at u = 0 turning into shape b at u = 1, as a Polygon.
Morph[a, b, u] is that shape at u.";
PartialPath::usage = "PartialPath[shape, u] is the first fraction u of the outline of shape, as a Line.";

(* ::Subsection:: *)
(*Typography*)

Typewriter::usage = "Typewriter[\"text\", {t0, t1}] types text behind a blinking cursor from t0, then lights up its \"Highlight\" words.";
Title::usage = "Title[\"text\", {t0, t1}] sets display type that rises, fades, pops or arrives letter by letter, and can collapse away.";
Caption::usage = "Caption[\"text\", {t0, t1}] is a sentence arriving word by word on a beat grid, wrapped to a column, its \"Highlight\" words in red.";
DictionaryCard::usage = "DictionaryCard[\"name\", {t0, t1}] is a dictionary entry for a Wolfram Language symbol: its name, usage and the version that introduced it, looked up live.";
TypedText::usage = "TypedText[\"text\", u] is the part of text typed by a fraction u of the way through.";

(* ::Subsection:: *)
(*Screens and eras*)

Terminal::usage = "Terminal[{{t, \"line\"}, \[Ellipsis]}, {t0, t1}] is a green-phosphor terminal that powers on, types the lines on the clock, prints and powers off.";
NotebookSession::usage = "NotebookSession[{{t, \"In\", \"code\"}, {t, \"Out\", output}, \[Ellipsis]}, {t0, t1}] is a notebook window of its \"Era\", typing and evaluating the cells on the clock; \"ChatInput\" and \"ChatOutput\" cells and a \"ChatBar\" make it a chat notebook.";
NotebookEra::usage = "NotebookEra[\"name\"] is the look of the notebook in one era, its chrome, display and cell style, as an association.
NotebookEra[\"name\", key -> value, \[Ellipsis]] changes some of it; NotebookEra[] lists the eras.";
OrderedDither::usage = "OrderedDither[image, {w, h}] reduces image to one bit at w by h pixels with 4 by 4 Bayer dithering.";

(* ::Subsection:: *)
(*Cards, instruments, characters, diagrams*)

PhotoPrint::usage = "PhotoPrint[image, \"caption\", {t0, t1}] pins a photo like a print, tilted, with a kicker above and a caption below.";
Counter::usage = "Counter[f, {t0, t1}] shows the number f[t], flashing while it changes, with a \"Label\".";
YearRuler::usage = "YearRuler[{{t, year}, \[Ellipsis]}, {t0, t1}] is a ruler of years along the bottom of the frame whose marker jumps from date to date.";
WordWall::usage = "WordWall[{{\"word\", weight, t}, \[Ellipsis]}, {t0, t1}] lays a whole vocabulary out like a dictionary page, each word sized by its weight and popping in at its time t; \"Camera\" moves the page, \"Emphasis\" picks words out, and wall[\"Places\"] says where each word sits.";
Spikey::usage = "Spikey[{t0, t1}] is the Wolfram mascot, dancing, in the \"Form\" and \"Style\" of an era, squashing on the onsets of a \"Pulse\" track; with \"Face\" -> True it has eyes, arms and legs, and can \"Raise\" a hand.";
AutomatonTape::usage = "AutomatonTape[rule, track, {t0, t1}] feeds a cellular automaton sideways into a read head and names the notes track plays from it.";
TreeDiagram::usage = "TreeDiagram[Hold[expr], {t0, t1}] grows the tree of expr from its head down, level by level.";
TileGrid::usage = "TileGrid[{{\"label\", content, \"note\"}, \[Ellipsis]}, {t0, t1}] deals out cards on the beat, each showing content, a plot or a picture, or a function u |-> expr played as a loop.";
WordScroll::usage = "WordScroll[{\"word\", \[Ellipsis]}, {t0, t1}] rolls the words up the frame in faint columns, like credits.";

(* ::Subsection:: *)
(*The canvas kit*)

CanvasBlock::usage = "CanvasBlock[{w, h}, body] evaluates body on a fresh canvas of w by h pixels, y down, with identity transform and full opacity.";
CanvasTransform::usage = "CanvasTransform[m, body] draws body under the 3 by 3 transform matrix m, composed with the current one, like a canvas context.";
CanvasTranslate::usage = "CanvasTranslate[{dx, dy}] is a translation matrix for CanvasTransform.";
CanvasScale::usage = "CanvasScale[s] and CanvasScale[{sx, sy}] are scaling matrices for CanvasTransform; CanvasScale[s, {cx, cy}] scales about a point.";
CanvasRotate::usage = "CanvasRotate[angle] is a rotation matrix for CanvasTransform, clockwise on screen.";
CanvasOpacity::usage = "CanvasOpacity[a, body] draws body at opacity a times the current one.";
$CanvasSize::usage = "$CanvasSize is the size in pixels of the canvas being drawn.";
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
$CanvasFixedAdvance::usage = "$CanvasFixedAdvance gives the pinned advance, per pixel of size, of monospaced faces that are drawn glyph by glyph.";

(* ::Subsection:: *)
(*Animated objects*)

AnimatedObject::usage = "AnimatedObject[primitives] is a graphics object that plays animation effects in sequence: obj[\"Play\", effect, \[Ellipsis]], obj[\"Wait\"], then obj[\"Dynamic\"], obj[\"Video\"] or obj[\"Update\", t].
AnimatedObject[\"tex\"] typesets TeX with MaTeX; AnimatedObject[{\"tex1\", \"tex2\", \[Ellipsis]}] typesets one formula whose parts are obj[\"Part\", i].";
AnimationEffect::usage = "AnimationEffect[name, args, opts] is an effect an AnimatedObject can play, such as \"Scale\", \"Rotate\", \"Translate\", \"Transform\" or \"Creation\" (Method -> \"Write\", \"Create\", \"FadeIn\", \[Ellipsis]). AnimationEffect[] lists them.";
Brace::usage = "Brace[obj] is a curly brace under an AnimatedObject, typeset as a TeX brace and stretched to its width; Brace[obj, dir, label] adds a label, and \"Direction\" sets the side.";

(* ::Subsection:: *)
(*Music*)

Track::usage = "Track[\"mini-notation\"] is a cyclic pattern of events, such as Track[\"bd [~ bd] sd, hh*8\"]; Track[{voice1, voice2, \[Ellipsis]}] stacks voices; Track[f] queries f[{start, end}] for events.
Audio[track, n] renders n cycles; track[\"Query\", a, b] gives the events between a and b.";
Silence::usage = "Silence is the empty Track.";
Steady::usage = "Steady[value] is a Track playing value once every cycle.";
Fast::usage = "Fast[r][track] plays track r times faster.";
Slow::usage = "Slow[r][track] plays track r times slower.";
Late::usage = "Late[t][track] shifts track t cycles later.";
Early::usage = "Early[t][track] shifts track t cycles earlier.";
Fastcat::usage = "Fastcat[track1, track2, \[Ellipsis]] plays the tracks one after another within each cycle.";
Layer::usage = "Layer[track1, track2, \[Ellipsis]] plays the tracks together.";
Alternate::usage = "Alternate[track1, track2, \[Ellipsis]] plays one track per cycle, in turn.";
Every::usage = "Every[n, f][track] applies f to track every nth cycle.";
Euclidean::usage = "Euclidean[k, n][track] plays track on k of n steps, spread as evenly as possible; Euclidean[k, n, rot] rotates the rhythm.";
Degrade::usage = "Degrade[track] drops half of the events at random, the same way every time; Degrade[fraction][track] drops that fraction.";
Superimpose::usage = "Superimpose[f][track] plays track together with f[track].";
Stagger::usage = "Stagger[t, f][track] plays track together with f[track] shifted t cycles later.";
Beat::usage = "Beat[positions, steps][track] plays track at the given step positions of a cycle divided into steps.";
Struct::usage = "Struct[\"1 ~ 1 1\"][track] plays track on the steps marked 1.";
InScale::usage = "InScale[\"C:minor\"][track] maps scale degrees in track to notes of the scale.";
Synth::usage = "Synth[wave][track] plays the notes of track on an oscillator: \"Sine\", \"Triangle\", \"Sawtooth\", \"Square\", \"Supersaw\", \"Pluck\", \"Bell\", \"Riser\" or \"Impact\".";
Gain::usage = "Gain[g][track] scales the level of track by g.";
Pan::usage = "Pan[x][track] places track in the stereo field, from -1 (left) to 1 (right).";
Delay::usage = "Delay[t][track] adds an echo t seconds later; Delay[t, feedback] sets its feedback.";
Room::usage = "Room[m][track] adds reverb, m from 0 to 1.";
Dec::usage = "Dec[d][track] shortens each sound to d seconds.";
Duck::usage = "Duck[trigger][track] dips track on every onset of the trigger track, a sidechain pump; Duck[trigger, depth, attack] sets its depth and recovery.";
Bars::usage = "Bars[n][track] shows and plays n cycles of track.";
Solo::usage = "Solo[track] plays only this track among those playing live.";
TrackPlay::usage = "TrackPlay[] starts the live clock of playing tracks.";
TrackPause::usage = "TrackPause[] pauses the live clock.";
TrackReset::usage = "TrackReset[] rewinds the live clock to the start.";
TrackSeek::usage = "TrackSeek[pos] moves the live clock to cycle pos.";
LoadSamples::usage = "LoadSamples[\"dir\"] loads every .wav file of a directory into the sample bank, named by file.";
LiveCode::usage = "LiveCode[expr] shows the code of a Track with each mini-notation atom lighting up as it plays.";
PianoRoll::usage = "PianoRoll[track] shows track as a piano roll while it plays; PianoRoll[opts][track] sets its look.";
Punchcard::usage = "Punchcard[track] shows track as a punch card of its events while it plays.";
Oscilloscope::usage = "Oscilloscope[track] shows the waveform of track while it plays.";
$CyclesPerSecond::usage = "$CyclesPerSecond is the tempo of live tracks, in cycles per second.";
$DefaultWave::usage = "$DefaultWave is the oscillator pitched tracks play on unless Synth says otherwise.";
$DefaultVisual::usage = "$DefaultVisual is the visual a playing track shows unless one is chosen.";
$DrumKit::usage = "$DrumKit is WAnim's own synthesized drum kit: bd, sd, hh, oh, cp, cr, lt and rim.";
$SampleBank::usage = "$SampleBank holds the samples loaded with LoadSamples, by name.";
$Scales::usage = "$Scales gives the scales InScale knows, as semitone steps.";
$AudioLatency::usage = "$AudioLatency is the delay, in seconds, between the live clock and the sound.";
$LiveAtomHeads::usage = "$LiveAtomHeads lists the heads whose string arguments LiveCode treats as mini-notation.";

(* ::Subsection:: *)
(*The studio*)

Instrument::usage = "Instrument[name][track] is a voice playing the events of track on an instrument synthesized sample by sample: \"Kick\", \"SoftKick\", \"Clap\", \"Hat\", \"OpenHat\", \"Crash\", \"Riser\", \"Roll\", \"Impact\", \"Tick\", \"Blip\", \"Pluck\", \"Arp\", \"Pad\", \"Bass\", \"LongBass\", \"Stab\", \"Lead\", \"Bell\" or \"Voice\". Instrument[] lists them.
A track of Instruments is mixed through drums, music and bass buses with a shared reverb and delay.";
Mixer::usage = "Mixer[opts][track] sets how a track of Instruments is mixed: \"Sidechain\" -> a track to duck under, \"Cutoff\" -> f for a low-pass on the music bus at f[cycle] Hz, \"DelayTime\", \"DelayFeedback\", \"Master\" and \"FadeOut\".";
