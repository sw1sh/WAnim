(* Strudel`  --  optional lowercase, Strudel-style shortcuts for the WolfAnim` pattern DSL.

   These short names (s, n, note, fast, rev, stack, seq, …) deliberately do NOT live in the
   WolfAnim` paclet context -- `s` and `n` are common variable names and shouldn't be forced
   onto every WolfAnim user.  Opt in explicitly, AFTER loading WolfAnim:

       Get[FileNameJoin[{wolfAnimSrcDir, "Strudel.wl"}]]      (* or Needs["Strudel`"] *)

   Then:  stack[s["bd*4"], note["<c4 e4 g4>"] // fast[2] // every[4, rev]]
   Chain transforms postfix with //  (x // f  ==  f[x]).
   Loading this also registers s/note/n/sound as LiveCode atom heads so they highlight. *)

BeginPackage["Strudel`", {"WolfAnim`"}]

s::usage          = "s[str] = CyclicPattern[str] -- a sample/sound pattern.";
sound::usage      = "sound[str] = CyclicPattern[str].";
note::usage       = "note[str] = CyclicPattern[str] -- a melodic pattern.";
n::usage          = "n[str] = CyclicPattern[str].";
fast::usage       = "fast = Fast (compress time).";
slow::usage       = "slow = Slow (stretch time).";
rev::usage        = "rev = Reverse (a pattern within each cycle).";
stack::usage      = "stack = Layer (play together as one voice).";
cat::usage        = "cat = Alternate (one sub-pattern per cycle).";
seq::usage        = "seq = Fastcat (a sequence within one cycle).";
every::usage      = "every = Every.";
euclid::usage     = "euclid = Euclidean.";
degrade::usage    = "degrade = Degrade.";
off::usage        = "off = Stagger (a time-shifted, transformed copy).";
superimpose::usage = "superimpose = Superimpose.";
late::usage       = "late = Late.";
early::usage      = "early = Early.";
gain::usage       = "gain = Gain.";
silence::usage    = "silence = Silence.";

(* atom constructors: down-values so the heads stay introspectable for LiveCode highlighting *)
s[a_]     := CyclicPattern[a]
sound[a_] := CyclicPattern[a]
note[a_]  := CyclicPattern[a]
n[a_]     := CyclicPattern[a]

(* combinator aliases *)
fast        = Fast
slow        = Slow
rev         = Reverse
stack       = Layer
cat         = Alternate
seq         = Fastcat
every       = Every
euclid      = Euclidean
degrade     = Degrade
off         = Stagger
superimpose = Superimpose
late        = Late
early       = Early
gain        = Gain
silence     = Silence

(* let LiveCode treat these atom heads as highlightable single-token leaves *)
WolfAnim`$LiveAtomHeads = DeleteDuplicates @ Join[WolfAnim`$LiveAtomHeads, {s, sound, note, n}]

EndPackage[]
