(* ::Package:: *)

(* ::Section:: *)
(*Evaluations before loading*)


(* Nothing yet *)


(* ::Section:: *)
(*PackageInitialize*)


(* StructuredPackageFormat entry point: loads every .wl under Kernel/ (except this file),
   wiring PackageExported / PackageScoped declarations into the WolframInstitute`WAnim` context.
   - HiddenImports: GeneralUtilities` for the format itself, Wolfram`Parser` so MiniNotation's
     grammar symbols (ParseRegex, LeafNode, ...) resolve when the file is read.
   - InitialEvaluations loads first (graceful MaTeX setup); Strudel.wl, the opt-in lowercase shortcuts,
     is a package of its own, loaded by Needs["WolframInstitute`WAnim`Strudel`"]. *)
PackageInitialize["WolframInstitute`WAnim`",
  <|
    "HiddenImports"  -> {"GeneralUtilities`", "Wolfram`Parser`"},
    "LoadFirstFiles" -> {"InitialEvaluations.wl"},
    "LoadLastFiles"  -> {},
    "IgnoreFiles"    -> {"Strudel.wl"}
  |>
]


(* ::Section:: *)
(*Evaluations after loading*)


(* Expose the cross-file shared (PackageScoped) symbols as an importable package, so tests and
   downstream code can Needs["WolframInstitute`WAnim`PackageScope`"] instead of the full-name forms.
   BeginPackage/EndPackage leaves the context on $ContextPath, so drop it back off: the import
   stays opt-in. *)
BeginPackage["WolframInstitute`WAnim`PackageScope`"]
EndPackage[]
$ContextPath = DeleteCases[$ContextPath, "WolframInstitute`WAnim`PackageScope`"];

