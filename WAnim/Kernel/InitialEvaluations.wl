(* ::Package:: *)

(* ::Section:: *)
(*MaTeX*)


(* LaTeX primitives (AnimatedObject's maTeXPrimitives) render via the MaTeX paclet.  Load it
   when present; the LaTeX path degrades gracefully if it is absent, so a missing MaTeX never
   blocks WAnim from loading. *)
If[PacletFind["MaTeX"] =!= {}, Quiet @ Needs["MaTeX`"]]
