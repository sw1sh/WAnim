(* ::Package:: *)

(* ::Section:: *)
(*Evaluations before loading*)


(* Nothing yet *)


(* ::Section:: *)
(*PackageInitialize*)


(* StructuredPackageFormat entry point: loads every .wl under Kernel/ (except this file),
   wiring PackageExported / PackageScoped declarations into the WolfAnim` context.
   - HiddenImports: GeneralUtilities` for the format itself, Wolfram`Parser` so MiniNotation's
     grammar symbols (ParseRegex, LeafNode, ...) resolve when the file is read.
   - InitialEvaluations loads first (graceful MaTeX setup); MiniNotation loads last so its
     CyclicPattern[_String] (AST) constructor overrides Pattern's plain one. *)
PackageInitialize["WolfAnim`",
  <|
    "HiddenImports"  -> {"GeneralUtilities`", "Wolfram`Parser`"},
    "LoadFirstFiles" -> {"InitialEvaluations.wl"},
    "LoadLastFiles"  -> {"MiniNotation.wl"},
    "IgnoreFiles"    -> {}
  |>
]


(* ::Section:: *)
(*Evaluations after loading*)


(* Expose the cross-file shared (PackageScoped) symbols as an importable package, so tests and
   downstream code can Needs["WolfAnim`PackageScope`"] instead of the full-name forms.
   BeginPackage/EndPackage leaves the context on $ContextPath, so drop it back off: the import
   stays opt-in. *)
BeginPackage["WolfAnim`PackageScope`"]
EndPackage[]
$ContextPath = DeleteCases[$ContextPath, "WolfAnim`PackageScope`"];
