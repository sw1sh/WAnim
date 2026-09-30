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
   - InitialEvaluations loads first (graceful MaTeX setup). *)
PackageInitialize["WolframInstitute`WAnim`",
  <|
    "HiddenImports"  -> {"GeneralUtilities`", "Wolfram`Parser`"},
    "LoadFirstFiles" -> {"InitialEvaluations.wl"},
    "LoadLastFiles"  -> {},
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
   working in a fresh session.  The package's contexts count as internal ones, which SaveDefinitions
   leaves out: a saved output carries only the notebook's definitions it uses, never the package's
   internals (nor its shared state, like the registry of playing streams, which a snapshot would
   overwrite on every display). *)
Unprotect[Language`$InternalContexts];
Language`$InternalContexts = DeleteDuplicates @ Join[Language`$InternalContexts, # <> "*" & /@ Contexts["WolframInstitute`WAnim`*"]];
Protect[Language`$InternalContexts];
