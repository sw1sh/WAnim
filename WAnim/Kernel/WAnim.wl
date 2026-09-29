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
   - InitialEvaluations loads first (graceful MaTeX setup); MiniNotation loads last so its
     CyclicPattern[_String] (AST) constructor overrides Pattern's plain one. *)
PackageInitialize["WolframInstitute`WAnim`",
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
   downstream code can Needs["WolframInstitute`WAnim`PackageScope`"] instead of the full-name forms.
   BeginPackage/EndPackage leaves the context on $ContextPath, so drop it back off: the import
   stays opt-in. *)
BeginPackage["WolframInstitute`WAnim`PackageScope`"]
EndPackage[]
$ContextPath = DeleteCases[$ContextPath, "WolframInstitute`WAnim`PackageScope`"];

(* Every live output is saved with SaveDefinitions -> True and reloads WAnim when opened, so it keeps
   working in a fresh session.  The package's own symbols are ReadProtected: a saved output then
   carries only the notebook's definitions it uses, never the package's internals (nor its shared
   state, like the registry of playing streams, which a snapshot would overwrite on every display). *)
Scan[Quiet @ ToExpression[#, InputForm, Function[x, With[{p = MemberQ[Attributes[x], Protected]}, Unprotect[x]; SetAttributes[x, ReadProtected]; If[p, Protect[x]]], HoldAllComplete]] &,
    Select[Names["WolframInstitute`WAnim`*"] ~Join~ Names["WolframInstitute`WAnim`*`*"], ! StringContainsQ[#, "`Strudel`"] &]];
