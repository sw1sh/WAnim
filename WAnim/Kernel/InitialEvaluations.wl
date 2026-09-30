(* ::Package:: *)

(* ::Section:: *)
(*MaTeX*)


(* LaTeX primitives (AnimatedObject's maTeXPrimitives) render via the MaTeX paclet.  Load it
   when present; the LaTeX path degrades gracefully if it is absent, so a missing MaTeX never
   blocks WAnim from loading.  Parallel kernels ($KernelID > 0) skip it: formulas are typeset where
   objects are built, and many kernels starting MaTeX at once race on its configuration file. *)
If[PacletFind["MaTeX"] =!= {} && $KernelID == 0, Quiet @ Needs["MaTeX`"]]
