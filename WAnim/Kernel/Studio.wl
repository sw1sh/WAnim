(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{Instrument, Mixer}]

PackageScoped[{instrumentVoiceQ, studioQ, studioRender}]


(* ::Section:: *)
(*Studio: instruments played sample by sample, mixed through buses*)

(* A small offline studio.  An Instrument renders each note of a Track into its dry sound, routed to
   the drums, music or bass bus, and its sends to a shared reverb and a shared ping-pong delay.  The
   mixer sums the buses, filters the music bus through an automated low-pass, ducks the music, bass
   and reverb under a sidechain, runs the sends through the delay and reverb, and masters the result:
   a rumble high-pass, soft saturation, a limiter and a fade.  The recursive parts (filters,
   oscillators, reverb, delay, limiter) are compiled with FunctionCompile on first use; everything
   else is array arithmetic. *)

studioRate[] := 44100;
cycleSecondsNow[] := 1 / $CyclesPerSecond;


(* ::Subsection:: *)
(*Compiled kernels*)

(* a state-variable filter (Zavalishin's TPT) over a signal with a cutoff per sample: {lp, bp, hp} *)
svfKernel := svfKernel = FunctionCompile[Function[{Typed[x, "PackedArray"::["Real64", 1]], Typed[fc, "PackedArray"::["Real64", 1]], Typed[q, "Real64"], Typed[sr, "Real64"]},
    Module[{n = Length[x], lp = ConstantArray[0., Length[x]], bp = ConstantArray[0., Length[x]], hp = ConstantArray[0., Length[x]],
            ic1 = 0., ic2 = 0., g = 0., k = 1. / q, a1 = 0., a2 = 0., a3 = 0., v1 = 0., v2 = 0., v3 = 0., f = 0., last = -1.},
        Do[
            f = Min[Max[fc[[i]], 10.], 0.45 sr];
            If[f != last, g = Tan[Pi f / sr]; a1 = 1. / (1. + g (g + k)); a2 = g a1; a3 = g a2; last = f];
            v3 = x[[i]] - ic2; v1 = a1 ic1 + a2 v3; v2 = ic2 + a2 ic1 + a3 v3;
            ic1 = 2. v1 - ic1; ic2 = 2. v2 - ic2;
            lp[[i]] = v2; bp[[i]] = v1; hp[[i]] = x[[i]] - k v1 - v2,
            {i, n}];
        {lp, bp, hp}]]];

(* a band-limited (PolyBLEP) sawtooth with a phase increment per sample *)
sawKernel := sawKernel = FunctionCompile[Function[{Typed[inc, "PackedArray"::["Real64", 1]], Typed[ph0, "Real64"]},
    Module[{n = Length[inc], out = ConstantArray[0., Length[inc]], ph = ph0, t = 0., v = 0., d = 0., y = 0.},
        Do[
            t = ph; d = inc[[i]]; ph = ph + d; If[ph >= 1., ph = ph - 1.];
            v = 2. t - 1.;
            If[t < d, y = t / d; v = v - (y + y - y y - 1.), If[t > 1. - d, y = (t - 1.) / d; v = v - (y y + y + y + 1.)]];
            out[[i]] = v,
            {i, n}];
        out]]];

(* Freeverb: eight damped combs and four allpasses per channel, fed the mono sum after a predelay;
   all the delay lines live in one flat buffer, each at its own offset *)
reverbKernel := reverbKernel = FunctionCompile[Function[{Typed[l, "PackedArray"::["Real64", 1]], Typed[r, "PackedArray"::["Real64", 1]],
        Typed[room, "Real64"], Typed[damp, "Real64"], Typed[pd, "MachineInteger"], Typed[spread, "MachineInteger"]},
    Module[{n = Length[l], lens, starts, pos, store, buf, outL = ConstantArray[0., Length[l]], outR = ConstantArray[0., Length[l]],
            x = 0., y = 0., yl = 0., yr = 0., b = 0., p = 0, total = 0},
        (* lines 1-8 left combs, 9-16 right combs, 17-20 left allpasses, 21-24 right allpasses *)
        lens = Join[{1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617}, {1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617} + spread,
            {556, 441, 341, 225}, {556, 441, 341, 225} + spread];
        starts = ConstantArray[0, 24];
        Do[starts[[j]] = total; total = total + lens[[j]], {j, 24}];
        buf = ConstantArray[0., total]; pos = ConstantArray[0, 24]; store = ConstantArray[0., 16];
        Do[
            x = If[i > pd, (l[[i - pd]] + r[[i - pd]]) 0.015, 0.];
            yl = 0.; yr = 0.;
            Do[
                p = starts[[j]] + pos[[j]] + 1;
                y = buf[[p]];
                store[[j]] = y (1. - damp) + store[[j]] damp;
                buf[[p]] = x + store[[j]] room;
                pos[[j]] = If[pos[[j]] + 1 >= lens[[j]], 0, pos[[j]] + 1];
                If[j <= 8, yl = yl + y, yr = yr + y],
                {j, 16}];
            Do[
                p = starts[[j]] + pos[[j]] + 1;
                b = buf[[p]];
                If[j <= 20, buf[[p]] = yl + b 0.5; yl = b - yl, buf[[p]] = yr + b 0.5; yr = b - yr];
                pos[[j]] = If[pos[[j]] + 1 >= lens[[j]], 0, pos[[j]] + 1],
                {j, 17, 24}];
            outL[[i]] = yl; outR[[i]] = yr,
            {i, n}];
        {outL, outR}]]];

(* a ping-pong delay whose feedback runs through a low-pass *)
delayKernel := delayKernel = FunctionCompile[Function[{Typed[l, "PackedArray"::["Real64", 1]], Typed[r, "PackedArray"::["Real64", 1]],
        Typed[m, "MachineInteger"], Typed[fb, "Real64"], Typed[lpHz, "Real64"], Typed[sr, "Real64"]},
    Module[{n = Length[l], bl = ConstantArray[0., m], br = ConstantArray[0., m], outL = ConstantArray[0., Length[l]], outR = ConstantArray[0., Length[l]],
            g = Tan[Pi lpHz / sr], k = Sqrt[2.], a1 = 0., a2 = 0., a3 = 0., p1 = 0., p2 = 0., q1 = 0., q2 = 0., dl = 0., dr = 0., v1 = 0., v2 = 0., v3 = 0., fl = 0., fr = 0., j = 1},
        a1 = 1. / (1. + g (g + k)); a2 = g a1; a3 = g a2;
        Do[
            dl = bl[[j]]; dr = br[[j]];
            v3 = dr - p2; v1 = a1 p1 + a2 v3; v2 = p2 + a2 p1 + a3 v3; p1 = 2. v1 - p1; p2 = 2. v2 - p2; fl = v2;
            v3 = dl - q2; v1 = a1 q1 + a2 v3; v2 = q2 + a2 q1 + a3 v3; q1 = 2. v1 - q1; q2 = 2. v2 - q2; fr = v2;
            bl[[j]] = (l[[i]] + r[[i]]) 0.5 + fl fb;
            br[[j]] = fr fb;
            outL[[i]] = dl; outR[[i]] = dr;
            j = If[j >= m, 1, j + 1],
            {i, n}];
        {outL, outR}]]];

(* a look-ahead limiter with a smooth release: the gain for each sample *)
limiterKernel := limiterKernel = FunctionCompile[Function[{Typed[peak, "PackedArray"::["Real64", 1]], Typed[ceiling, "Real64"], Typed[la, "MachineInteger"], Typed[rel, "Real64"]},
    Module[{n = Length[peak], need = ConstantArray[1., Length[peak]], gmin = ConstantArray[1., Length[peak]], out = ConstantArray[1., Length[peak]], m = 1., g = 1., tg = 1.},
        Do[need[[i]] = If[peak[[i]] > ceiling, ceiling / peak[[i]], 1.], {i, n}];
        Do[m = 1.; Do[If[need[[j]] < m, m = need[[j]]], {j, i, Min[n, i + la]}]; gmin[[i]] = m, {i, n}];
        Do[tg = gmin[[i]]; g = If[tg < g, tg, tg + (g - tg) rel]; out[[i]] = g, {i, n}];
        out]]];


(* ::Subsection:: *)
(*Building blocks*)

svf[x_, fc_, q_ : 0.707] := svfKernel[Developer`ToPackedArray[N[x]], Developer`ToPackedArray[N[If[ListQ[fc], fc, ConstantArray[fc, Length[x]]]]], N[q], N[studioRate[]]];
(* a cutoff that moves, set every m samples as a synthesizer's control rate would *)
stepped[f_, n_, m_ : 16] := Developer`ToPackedArray[N[Flatten[ConstantArray[#, m] & /@ (f /@ N[Range[0, Ceiling[n / m] - 1] m / studioRate[]])]][[;; n]]];
sawWave[freq_, n_, ph0_ : 0.] := sawKernel[Developer`ToPackedArray[N[If[ListQ[freq], freq, ConstantArray[freq, n]] / studioRate[]]], N[ph0]];
noise[n_, seed_] := BlockRandom[SeedRandom[seed]; RandomReal[{-1, 1}, n]];
times[n_] := N[Range[0, n - 1] / studioRate[]];
samples[sec_] := Max[1, Round[sec studioRate[]]];
(* equal-power panning of a mono signal *)
panned[x_, pan_] := With[{a = (pan + 1) Pi / 4}, {x Cos[a], x Sin[a]}];
mono[x_] := panned[x, 0];
adsr[t_, hold_, a_, d_, s_, r_] := With[{e = Function[tt, Piecewise[{{tt / a, tt < a}, {1. - (1. - s) (tt - a) / d, tt < a + d}}, s]]},
    If[t < hold, e[t], Max[0., e[hold] (1. - (t - hold) / r)]]];
(* the same envelope over a whole array at once: attack and decay are the smaller of the rising ramp and
   the falling one (never below the sustain), and past the hold the release ramps down from where it was *)
adsrArray[ts_, hold_, a_, d_, s_, r_] := With[{held = UnitStep[ts - hold]},
    With[{rise = ts / a, fall = s + Ramp[1 - (1 - s) (ts - a) / d - s]},   (* Min and Max elementwise: x - Ramp[x - y], y + Ramp[x - y] *)
        Developer`ToPackedArray[N[(rise - Ramp[rise - fall]) (1 - held) + adsr[hold, hold + 1, a, d, s, r] Clip[1 - (ts - hold) / r, {0, 1}] held]]]];
midiFreq[m_] := 440. 2^((m - 69) / 12.);

(* a note: {bus, dry {L, R}, reverb send {L, R}, delay send {L, R}} *)
note[bus_, dry_, verb_ : Automatic, delay_ : Automatic] := <|"Bus" -> bus, "Dry" -> dry,
    "Verb" -> Replace[verb, Automatic -> 0 dry], "Delay" -> Replace[delay, Automatic -> 0 dry]|>;


(* ::Subsection:: *)
(*The instruments*)

(* instrument[name, f, v, hold, onset, seed]: f in Hz, v the velocity (0-1), hold the note's length
   and onset its start in seconds (some instruments pan or voice by the onset) *)
instrument["Kick" | "SoftKick", name_][f_, v_, hold_, onset_, seed_] := Module[{soft = name === "SoftKick", n, ts, freq, x},
    n = samples[If[soft, 0.35, 0.5]]; ts = times[n];
    freq = 44 + If[soft, 90, 170] Exp[-28 ts];
    x = Tanh[1.6 Sin[2 Pi Accumulate[freq] / studioRate[]] Exp[-ts If[soft, 9, 6.5]]];
    If[! soft, With[{m = samples[0.004]}, x[[;; m]] += 0.35 noise[m, seed] (1 - Range[0, m - 1] / m)]];
    note["Drums", mono[svf[x, If[soft, 900, 4000]][[1]] v If[soft, 0.55, 0.95]]]];
instrument["Clap", _][f_, v_, hold_, onset_, seed_] := Module[{n = samples[0.35], ts, env, x},
    ts = times[n];
    env = MapThread[Max, {Max @@@ Transpose[Table[UnitStep[ts - k] Exp[-(ts - k) 180], {k, {0, 0.011, 0.022}}]], 0.6 UnitStep[ts - 0.03] Exp[-(ts - 0.03) 16]}];
    x = svf[svf[noise[n, seed], 1300, 1.2][[2]], 600][[3]] env v 0.9;
    note["Drums", {x, 0.95 x}, mono[0.35 x]]];
instrument["Hat" | "OpenHat", name_][f_, v_, hold_, onset_, seed_] := Module[{open = name === "OpenHat", n, ts},
    n = samples[If[open, 0.3, 0.06]]; ts = times[n];
    note["Drums", panned[svf[noise[n, seed], If[open, 7000, 8500], 0.9][[3]] Exp[-ts If[open, 11, 70]] v If[open, 0.28, 0.3], If[open, 0.25, -0.2]]]];
instrument["Crash", _][f_, v_, hold_, onset_, seed_] := Module[{n = samples[2.6], ts, env, l, r},
    ts = times[n]; env = Exp[-1.6 ts] (1 - Exp[-400 ts]);
    l = svf[noise[n, seed], 3500][[3]] env v; r = svf[noise[n, seed + 1], 3600][[3]] env v;
    note["Drums", {0.22 l, 0.22 r}, mono[0.05 (l + r)]]];
instrument["Riser", _][f_, v_, hold_, onset_, seed_] := Module[{n = samples[hold], u, fc, l, r, env},
    u = N[Range[0, n - 1] / n]; fc = 250 40^(32 Floor[Range[0, n - 1] / 32] / n);
    l = svf[noise[n, seed], fc, 2.5][[2]]; r = svf[noise[n, seed + 1], 1.03 fc, 2.5][[2]];
    env = u^2.2 v 0.55;
    note["Drums", {l env, r env}, mono[0.3 (l + r) env]]];
snare[v_, seed_] := Module[{n = samples[0.16], ts, x},
    ts = times[n];
    x = (svf[noise[n, seed], 2500, 0.8][[2]] Exp[-22 ts] + 0.5 Sin[2 Pi 190 ts] Exp[-30 ts]) v 0.35;
    {panned[x, 0.05], mono[0.3 x]}];
(* an accelerating snare roll, eighths to thirty-seconds of a cycle, swelling *)
instrument["Roll", _][f_, v_, hold_, onset_, seed_] := Module[{bar = cycleSecondsNow[], hits = {}, t = 0., u, n, dry, verb, k = 0},
    While[t < hold, u = t / hold; AppendTo[hits, {t, v (0.25 + 0.75 u^2)}]; t += bar / Which[u < 0.5, 8, u < 0.75, 16, True, 32]];
    n = samples[hold] + samples[0.16] + 1; dry = ConstantArray[0., {2, n}]; verb = ConstantArray[0., {2, n}];
    Do[With[{s = snare[h[[2]], seed + k++], i0 = samples[h[[1]]] + 1}, With[{m = Length[s[[1, 1]]]},
        dry[[All, i0 ;; i0 + m - 1]] += s[[1]]; verb[[All, i0 ;; i0 + m - 1]] += s[[2]]]], {h, hits}];
    note["Drums", dry, verb]];
instrument["Impact", _][f_, v_, hold_, onset_, seed_] := Module[{n = samples[2.2], ts, sub, boom, x},
    ts = times[n];
    sub = Sin[2 Pi Accumulate[30 + 60 Exp[-3 ts]] / studioRate[]] Exp[-1.8 ts];
    boom = 1.5 svf[noise[n, seed], 300][[1]] Exp[-5 ts];
    x = Tanh[1.3 (sub + boom)] v 0.7;
    note["Drums", mono[x], mono[0.25 boom v]]];
(* a key press: a short bright click with a little body *)
instrument["Tick", _][f_, v_, hold_, onset_, seed_] := Module[{n = samples[0.03], ts},
    ts = times[n];
    note["Drums", panned[(svf[noise[n, seed], 2800, 0.8][[3]] Exp[-420 ts] + 0.3 Sin[2 Pi 1900 ts] Exp[-300 ts]) v 0.22, -0.25 + 0.5 FractionalPart[977 onset / cycleSecondsNow[]]]]];
instrument["Blip", _][f_, v_, hold_, onset_, seed_] := Module[{n = samples[0.12], ts, x},
    ts = times[n]; x = Sin[2 Pi If[f > 0, f, 1568] ts] Exp[-38 ts] v 0.12;
    note["Music", panned[x, 0.15], mono[0.4 x]]];
instrument["Pluck" | "Arp", name_][f_, v_, hold_, onset_, seed_] := Module[{arp = name === "Arp", n, ts, x, y, bar = onset / cycleSecondsNow[]},
    n = samples[If[arp, 0.35, 0.9]]; ts = times[n];
    x = 0.6 sawWave[f, n] + 0.4 sawWave[1.004 f, n, 0.37];
    y = svf[x, stepped[350 + 5200 Exp[-# If[arp, 18, 11]] &, n], 1.1][[1]] Exp[-ts If[arp, 9, 4.2]] Clip[400 ts, {0, 1}] v 0.32;
    note["Music", panned[y, If[arp, 0.6 Sin[37 bar], 0.35 Sin[13.7 bar]]], mono[0.45 y], mono[If[arp, 0.35, 0.55] y]]];
instrument["Pad", _][f_, v_, hold_, onset_, seed_] := Module[{rel = 0.9, n, ts, det = {-0.11, -0.05, 0, 0.05, 0.11}, l, r, s, g},
    n = samples[hold + rel]; ts = times[n];
    s = Table[sawWave[f 2^(det[[k]] / 12), n, Mod[(k - 1) 0.237, 1]], {k, 5}];
    l = Total[Table[s[[k]] (1 - ((k - 1) / 2 - 1)) / 2, {k, 5}]]; r = Total[Table[s[[k]] (1 + ((k - 1) / 2 - 1)) / 2, {k, 5}]];
    g = adsrArray[ts, hold, 0.35, 0.5, 0.8, rel] v 0.075;
    With[{yl = svf[l, 2200, 0.6][[1]] g, yr = svf[r, 2200, 0.6][[1]] g}, note["Music", {yl, yr}, 0.6 {yl, yr}]]];
instrument["Bass" | "LongBass", name_][f_, v_, hold_, onset_, seed_] := Module[{long = name === "LongBass", n, ts, env, y},
    n = samples[hold + If[long, 1.2, 0.05]]; ts = times[n];
    env = If[long, adsrArray[ts, hold, 0.01, 0.3, 0.8, 1.2], adsrArray[ts, hold, 0.003, 0.08, 0.7, 0.04]];
    y = (0.55 svf[sawWave[f, n], If[long, 400, stepped[180 + 1400 Exp[-22 #] &, n]], 1.2][[1]] + 0.6 Sin[2 Pi Accumulate[ConstantArray[f, n]] / studioRate[]]) env v 0.42;
    note["Bass", mono[Tanh[1.5 y] / 1.5]]];
instrument["Stab" | "Lead", name_][f_, v_, hold_, onset_, seed_] := Module[{lead = name === "Lead", rel, n, ts, det = {-0.19, -0.12, -0.05, 0, 0.05, 0.12, 0.19}, vib, s, l, r, fc, env, g, yl, yr},
    rel = If[lead, 0.25, 0.12]; n = samples[hold + rel]; ts = times[n];
    vib = If[lead, 1 + 0.004 Sin[2 Pi 5.5 ts] Clip[3 ts, {0, 1}], 1];
    s = Table[sawWave[f vib 2^(det[[k]] / 12), n, Mod[(k - 1) 0.1713, 1]], {k, 7}];
    l = Total[Table[s[[k]] (1 - 0.9 ((k - 1) / 3 - 1)) / 2, {k, 7}]]; r = Total[Table[s[[k]] (1 + 0.9 ((k - 1) / 3 - 1)) / 2, {k, 7}]];
    fc = stepped[If[lead, 2600 + 5000 Exp[-6 #], 1200 + 6000 Exp[-25 #]] &, n];
    env = If[lead, adsrArray[ts, hold, 0.008, 0.2, 0.75, rel], adsrArray[ts, hold, 0.002, 0.06, 0.4, rel]];
    g = env v If[lead, 0.085, 0.05];
    yl = svf[l, fc, 0.8][[1]] g; yr = svf[r, fc, 0.8][[1]] g;
    note["Music", {yl, yr}, 0.35 {yl, yr}, If[lead, 0.35 {yl, yr}, Automatic]]];
(* a two-operator FM electric bell *)
instrument["Bell", _][f_, v_, hold_, onset_, seed_] := Module[{n = samples[hold + 1.6], ts, x, y},
    ts = times[n];
    x = Sin[2 Pi f ts + 2.2 Exp[-5 ts] Sin[2 Pi 3.5 f ts]] + 0.25 Sin[2 Pi 2 f ts] Exp[-3 ts];
    y = x Exp[-ts (1.6 + 2.4 UnitStep[ts - hold])] Clip[800 ts, {0, 1}] v 0.16;
    note["Music", panned[y, 0.1], mono[0.5 y], mono[0.45 y]]];
(* a machine singing vowels: a sawtooth through three formant filters gliding from vowel to vowel *)
instrument["Voice", _][f_, v_, hold_, onset_, seed_] := Module[{rel = 0.3, n, ts, vowels = {{800, 1150, 2900}, {400, 1700, 2600}, {350, 2000, 2800}, {450, 800, 2830}, {325, 700, 2530}},
        vi, va, vb, src, y, env},
    n = samples[hold + rel]; ts = times[n];
    vi = Mod[Floor[4 onset / cycleSecondsNow[]], 5] + 1; va = vowels[[vi]]; vb = vowels[[Mod[vi, 5] + 1]];
    src = sawWave[f (1 + 0.006 Sin[2 Pi 5.2 ts] Clip[2 ts, {0, 1}]), n] + 0.04 noise[n, seed];
    y = Total[Table[svf[src, stepped[va[[k]] + (vb[[k]] - va[[k]]) Clip[# / Max[0.2, hold], {0, 1}] &, n, 32], 9][[2]] (1 / 9) {1, 0.5, 0.25}[[k]], {k, 3}]];
    env = adsrArray[ts, hold, 0.06, 0.2, 0.85, rel];
    y = y env v 0.9;
    note["Music", panned[y, -0.1], mono[0.55 y], mono[0.4 y]]];
instrument[name_, _][___] := (Message[Instrument::unknown, name]; note["Music", {{0.}, {0.}}]);

Instrument::unknown = "`1` is not an instrument; Instrument[] lists them.";
Instrument[] = {"Kick", "SoftKick", "Clap", "Hat", "OpenHat", "Crash", "Riser", "Roll", "Impact", "Tick", "Blip",
    "Pluck", "Arp", "Pad", "Bass", "LongBass", "Stab", "Lead", "Bell", "Voice"};


(* ::Subsection:: *)
(*Voices and the mix*)

(* Instrument[name][track] is a voice playing track's events on the instrument: notes are MIDI numbers
   (or names), an event's velocity is its fourth element in an EventTrack (default 1). *)
Instrument[name_String][p_] := Instrument[name, p];
instrumentVoiceQ[v_] := MatchQ[stripGain[v], Instrument[_String, _]];
stripGain[v_] := v //. HoldPattern[GainVoice[_, x_]] :> x;
voiceGain[v_] := Times @@ Cases[{v}, HoldPattern[GainVoice[g_, _]] :> g, Infinity];

(* Mixer[opts][track] sets how a track of instruments is mixed:
     "Sidechain" -> kickTrack    duck the music (0.55), bass (0.8) and reverb (0.35) under its onsets
     "Cutoff" -> f               the music bus runs through a low-pass at f[cycle] Hz
     "DelayTime" -> 3/16         the ping-pong delay, in cycles; "DelayFeedback" -> 0.42
     "Master" -> True            rumble high-pass, soft saturation, limiter; "FadeOut" -> seconds *)
Options[Mixer] = {"Sidechain" -> None, "Cutoff" -> None, "DelayTime" -> 3/16, "DelayFeedback" -> 0.42, "Master" -> True, "FadeOut" -> 2.5};
Mixer[opts : OptionsPattern[]][Track[vs_List, m_Association : <||>]] := Track[vs, Append[m, "Mixer" -> {opts}]];
studioQ[t_] := MatchQ[t, Track[vs_List, ___] /; AnyTrue[vs, instrumentVoiceQ] || MatchQ[t, Track[_, KeyValuePattern["Mixer" -> _]]]];
mixerOption[t_, name_] := OptionValue[Mixer, Replace[t, {Track[_, m_Association] :> Lookup[m, "Mixer", {}], _ -> {}}], name];

(* render every voice into the buses, then mix *)
studioRender[t : Track[vs_List, ___], nCycles_] := Module[{sr = studioRate[], cs = cycleSecondsNow[], n, drums, music, bass, verb, delay, addAt},
    n = samples[nCycles cs];
    {drums, music, bass, verb, delay} = ConstantArray[0., {5, 2, n}];
    SetAttributes[addAt, HoldFirst];
    addAt[b_, i0_, x_] := With[{m = Min[Length[x[[1]]], n - i0 + 1]}, If[m > 0, b[[All, i0 ;; i0 + m - 1]] += x[[All, ;; m]]]];
    Do[If[instrumentVoiceQ[v],
        With[{name = stripGain[v][[1]], p = stripGain[v][[2]], g = voiceGain[v]},
            Do[With[{onset = ev["Whole"][[1]] cs, vel = g Lookup[ev, "Velocity", 1]},
                Do[With[{nt = instrument[name, name][midiFreq[m], vel, (ev["Whole"][[2]] - ev["Whole"][[1]]) cs, onset, Mod[Hash[{name, onset, m}], 2^31]], i0 = samples[onset] + 1},
                    Switch[nt["Bus"], "Drums", addAt[drums, i0, nt["Dry"]], "Bass", addAt[bass, i0, nt["Dry"]], _, addAt[music, i0, nt["Dry"]]];
                    addAt[verb, i0, nt["Verb"]]; addAt[delay, i0, nt["Delay"]]],
                    {m, Replace[valuePitches[ev["Value"]], {} -> {0}]}]],
                {ev, Select[p["Query", 0, nCycles], hasOnset]}]],
        (* any other voice (a Synth, samples, an Audio) is rendered as usual and joins the music bus *)
        With[{a = voiceRendered[v, nCycles]},
            If[Head[a] === Audio, With[{d = AudioData[AudioResample[a, sr]]}, addAt[music, 1, If[Length[d] == 1, {d[[1]], d[[1]]}, d[[;; 2]]]]]]]],
        {v, vs}];
    mixBuses[<|"Drums" -> drums, "Music" -> music, "Bass" -> bass, "Verb" -> verb, "Delay" -> delay|>, n, t]];

mixBuses[bus0_, n_, t_] := Module[{bus = bus0, sr = studioRate[], cs = cycleSecondsNow[], duck, kicks, cutoff, del, verb, mix, pre, peak, gain, fade},
    (* the sidechain envelope: under each kick the gain dips and recovers *)
    duck = ConstantArray[1., n];
    kicks = Replace[mixerOption[t, "Sidechain"], {None -> {}, k_ :> (#["Whole"][[1]] cs & /@ Select[k["Query", 0, n / sr / cs], hasOnset])}];
    Do[With[{i0 = samples[k] + 1, len = samples[0.28]}, With[{m = Min[len, n - i0 + 1]},
        If[m > 0, duck[[i0 ;; i0 + m - 1]] = MapThread[Min, {duck[[i0 ;; i0 + m - 1]], 1 - Exp[-times[m] / 0.085]}]]]], {k, kicks}];
    (* the music bus through its automated low-pass *)
    cutoff = mixerOption[t, "Cutoff"];
    If[cutoff =!= None, With[{fc = stepped[cutoff[# / cs] &, n, 32]}, bus["Music"] = svf[#, fc, 0.9][[1]] & /@ bus["Music"]]];
    bus["Music"] = (1 - 0.55 (1 - duck)) # & /@ bus["Music"];
    bus["Bass"] = (1 - 0.8 (1 - duck)) # & /@ bus["Bass"];
    del = delayKernel[bus["Delay"][[1]], bus["Delay"][[2]], samples[mixerOption[t, "DelayTime"] cs], N[mixerOption[t, "DelayFeedback"]], 3200., N[sr]];
    verb = reverbKernel[bus["Verb"][[1]] + 0.25 del[[1]], bus["Verb"][[2]] + 0.25 del[[2]], 0.88, 0.3, samples[0.025], 23];
    verb = (1 - 0.35 (1 - duck)) # & /@ verb;
    mix = bus["Drums"] + bus["Music"] + bus["Bass"] + 0.45 del + 0.9 verb;
    If[TrueQ[mixerOption[t, "Master"]],
        mix = svf[#, 28][[3]] & /@ mix;
        peak = MapThread[Max, Abs[mix]];
        pre = 1. / Max[Quantile[peak, 0.995], 10.^-6];
        mix = Tanh[1.4 pre mix] / 1.4;
        gain = limiterKernel[Developer`ToPackedArray[MapThread[Max, Abs[mix]]], 0.891, samples[0.005], Exp[-1. / (0.12 sr)]];
        mix = gain # & /@ mix];
    fade = mixerOption[t, "FadeOut"];
    If[NumericQ[fade] && fade > 0, With[{m = Min[n, samples[fade]]}, mix[[All, n - m + 1 ;;]] = (Cos[Range[0, m - 1] / m Pi / 2] #) & /@ mix[[All, n - m + 1 ;;]]]];
    Audio[mix, SampleRate -> sr]];
