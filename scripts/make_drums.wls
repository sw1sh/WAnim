#!/usr/bin/env wolframscript
(* wolframscript -f scripts/make_drums.wls: synthesize WAnim's built-in drum kit into the paclet's
   "Drums" asset (WAnim/Assets/Drums/*.wav).  Every sound is made here from oscillators and seeded
   noise, so the kit is deterministic and WAnim owns it outright (MIT, like the paclet). *)

sr = 44100;
out = FileNameJoin[{DirectoryName[$InputFileName], "..", "WAnim", "Assets", "Drums"}];
Quiet @ CreateDirectory[out, CreateIntermediateDirectories -> True];

times[d_] := Range[0, d, 1. / sr];
noise[d_, seed_] := BlockRandom[RandomReal[{-1, 1}, Length[times[d]]], RandomSeeding -> seed];
env[d_, k_] := Exp[-k times[d]];
(* a sine whose frequency glides exponentially from f0 to f1 with time constant tau *)
sweep[d_, f0_, f1_, tau_] := With[{t = times[d]}, Sin[2 Pi (f1 t + (f0 - f1) tau (1 - Exp[-t / tau]))]];
toAudio[x_] := AudioNormalize[Audio[x, SampleRate -> sr]];
hp[x_, f_, d_] := AudioData[HighpassFilter[Audio[x, SampleRate -> sr], f]][[1]][[;; Length[times[d]]]];
bp[x_, {f0_, f1_}, d_] := AudioData[BandpassFilter[Audio[x, SampleRate -> sr], {f0, f1}]][[1]][[;; Length[times[d]]]];

kit = <|
    (* kick: a sine dropping 150 -> 48 Hz, a short click on top *)
    "bd" -> With[{d = 0.55}, sweep[d, 150, 48, 0.035] env[d, 7.5] + 0.35 bp[noise[d, 1], {1500, 6000}, d] env[d, 220]],
    (* snare: two drum-head tones and band-passed noise for the wires *)
    "sd" -> With[{d = 0.35}, 0.55 (Sin[2 Pi 185 times[d]] + 0.6 Sin[2 Pi 330 times[d]]) env[d, 22] + bp[noise[d, 2], {1800, 9000}, d] env[d, 13]],
    (* clap: three hand-claps 11 ms apart, then the room *)
    "cp" -> With[{d = 0.32}, With[{n = bp[noise[d, 3], {900, 3200}, d], t = times[d]},
        n (Total[UnitStep[t - #] Exp[-(t - #) 140] & /@ {0, 0.011, 0.022}] + 0.6 UnitStep[t - 0.033] Exp[-(t - 0.033) 16])]],
    (* hats: bright noise, closed and open *)
    "hh" -> With[{d = 0.14}, hp[noise[d, 4], 7500, d] env[d, 42]],
    "oh" -> With[{d = 0.55}, hp[noise[d, 5], 6500, d] env[d, 6.5]],
    (* crash: high-passed noise with a few inharmonic partials, long decay *)
    "cr" -> With[{d = 2.2}, With[{t = times[d]}, (hp[noise[d, 6], 4200, d] + 0.08 Total[Sin[2 Pi # t] & /@ {3160, 4870, 6230, 7990}]) env[d, 2.1]]],
    (* rimshot and a low tom *)
    "rim" -> With[{d = 0.08}, (Sin[2 Pi 1700 times[d]] + 0.7 bp[noise[d, 7], {2500, 6000}, d]) env[d, 75]],
    "lt" -> With[{d = 0.45}, sweep[d, 140, 92, 0.08] env[d, 8]]
|>;
KeyValueMap[Export[FileNameJoin[{out, #1 <> ".wav"}], toAudio[#2], "WAV"] &, kit];
Print["wrote ", Length[kit], " drums to ", ExpandFileName[out], ": ", StringRiffle[Keys[kit], " "]];
