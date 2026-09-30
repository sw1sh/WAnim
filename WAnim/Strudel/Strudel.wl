(* ::Package:: *)

(* WolframInstitute`WAnim`Strudel`  --  optional lowercase, Strudel-style shortcuts for the WolframInstitute`WAnim` pattern
   DSL.  These short names (s, n, note, fast, rev, stack, seq, ...) deliberately do NOT live in
   the WolframInstitute`WAnim` context -- `s` and `n` are common variable names and shouldn't be forced onto
   every WAnim user.  Opt in explicitly, after loading WAnim:

       Needs["WolframInstitute`WAnim`Strudel`"]

   Then:  stack[s["bd*4"], note["<c4 e4 g4>"] // fast[2] // every[4, rev]]
   Chain transforms postfix with //  (x // f  ==  f[x]). *)

BeginPackage["WolframInstitute`WAnim`Strudel`", {"WolframInstitute`WAnim`"}]

s::usage = "s[str] is Track[str], a pattern of sounds.";
sound::usage = "sound[str] is Track[str].";
note::usage = "note[str] is Track[str], a pattern of notes.";
n::usage = "n[str] is Track[str].";
fast::usage = "fast[r] is TrackSpeed[r].";
slow::usage = "slow[r] is TrackSpeed[1/r].";
rev::usage = "rev is Reverse.";
stack::usage = "stack[a, b, ...] is Track[{a, b, ...}].";
cat::usage = "cat is TrackAlternate.";
seq::usage = "seq is TrackSequence.";
every::usage = "every is TrackEvery.";
euclid::usage = "euclid is TrackEuclid.";
degrade::usage = "degrade is TrackDegrade[0.5]; degrade[x] is TrackDegrade[x].";
off::usage = "off[t, f] is TrackSuperimpose[f, t].";
superimpose::usage = "superimpose is TrackSuperimpose.";
late::usage = "late[t] is TrackShift[t].";
early::usage = "early[t] is TrackShift[-t].";
struct::usage = "struct is TrackStruct.";
beat::usage = "beat[positions, steps] is TrackStruct[positions, steps].";
sc::usage = "sc is TrackScale.";
scale::usage = "scale is TrackScale.";
silence::usage = "silence is Track[].";
punchcard::usage = "punchcard is TrackView[\"Punchcard\"].";
gain::usage = "gain[g] is Instrument[\"Gain\" -> g].";
pan::usage = "pan[x] is Instrument[\"Pan\" -> x].";
room::usage = "room[r] is Instrument[\"Reverb\" -> r].";
dly::usage = "dly[d] is Instrument[\"Delay\" -> d].";
dec::usage = "dec[d] is Instrument[\"Decay\" -> d], in cycles.";
instrument::usage = "instrument[name] is Instrument[name].";

s[a_] := Track[a];
sound[a_] := Track[a];
note[a_] := Track[a];
n[a_] := Track[a];
fast[r_] := TrackSpeed[r];
slow[r_] := TrackSpeed[1 / r];
rev = Reverse;
stack[ps__] := Track[{ps}];
cat = TrackAlternate;
seq = TrackSequence;
every = TrackEvery;
euclid = TrackEuclid;
degrade[p_Track] := TrackDegrade[0.5][p];
degrade[x_] := TrackDegrade[x];
off[t_, f_] := TrackSuperimpose[f, t];
superimpose = TrackSuperimpose;
late[t_] := TrackShift[t];
early[t_] := TrackShift[-t];
struct = TrackStruct;
beat = TrackStruct;
sc = TrackScale;
scale = TrackScale;
silence = Track[];
punchcard = TrackView["Punchcard"];
gain[g_] := Instrument["Gain" -> g];
pan[x_] := Instrument["Pan" -> x];
room[r_] := Instrument["Reverb" -> r];
dly[d_] := Instrument["Delay" -> d];
dec[d_] := Instrument["Decay" -> d];
instrument[name_] := Instrument[name];

EndPackage[]
