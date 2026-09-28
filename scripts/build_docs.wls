#!/usr/bin/env wolframscript
(* wolframscript -f scripts/build_docs.wls [pattern]
   Convert the markdown documentation sources to notebooks with MarkdownToNotebook:
     docs/en/Guides/**/<Name>.md                  -> WAnim/Documentation/English/Guides/<Name>.nb
     docs/en/ReferencePages/Symbols/**/<Name>.md  -> WAnim/Documentation/English/ReferencePages/Symbols/<Name>.nb
     docs/en/Tutorials/**/<Name>.md               -> WAnim/Documentation/English/Tutorials/<Name>.nb
   Output is flat by basename (the documentation system resolves guide/ref URIs in a flat namespace).
   Examples are evaluated against this checkout of the paclet; tutorials thread state across sections.
   The converter is the local MarkdownToNotebook checkout next to this repo (or $WAnimMTN / WANIM_MTN).
   An optional pattern (e.g. "Typewriter") rebuilds only the matching pages.  Built notebooks are
   artifacts (notebooks are gitignored); the markdown is the source.  Exits 1 if a page fails. *)

repoRoot = ParentDirectory[DirectoryName[$InputFileName]];
PacletDirectoryLoad[repoRoot];
Needs["WolframInstitute`WAnim`"];
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"];

mtnSource = SelectFirst[{Environment["WANIM_MTN"], FileNameJoin[{ParentDirectory[repoRoot], "MarkdownToNotebook", "MarkdownToNotebook.wl"}]},
    StringQ[#] && FileExistsQ[#] &, None];
If[mtnSource === None, Print["build_docs: MarkdownToNotebook.wl not found next to this repo (set WANIM_MTN)."]; Exit[1]];
Get[mtnSource];

docOut = FileNameJoin[{repoRoot, "WAnim", "Documentation", "English"}];
kinds = {{"Guides", "Guides", Automatic}, {FileNameJoin[{"ReferencePages", "Symbols"}], FileNameJoin[{"ReferencePages", "Symbols"}], Automatic}, {"Tutorials", "Tutorials", None}};
pattern = If[Length[$ScriptCommandLine] >= 2, $ScriptCommandLine[[2]], "*"];

buildPage[md_, out_, sep_] := With[{nb = FileNameJoin[{out, FileBaseName[md] <> ".nb"}]},
    Print["building ", FileNameTake[md]];
    Quiet @ DeleteFile[nb];
    TimeConstrained[MarkdownToNotebook[md, nb, "UseCache" -> False, "EvaluateSeparator" -> sep], 600];
    If[FileExistsQ[nb], {md, True}, Print["  FAILED: ", FileNameTake[md]]; {md, False}]];
results = Flatten[Reap[Do[
    With[{src = FileNameJoin[{repoRoot, "docs", "en", k[[1]]}], out = FileNameJoin[{docOut, k[[2]]}]},
        Quiet @ CreateDirectory[out, CreateIntermediateDirectories -> True];
        Do[Sow[buildPage[md, out, k[[3]]]], {md, Select[FileNames["*.md", src, Infinity], StringMatchQ[FileBaseName[#], pattern] &]}]],
    {k, kinds}]][[2]], 1];
Print["build_docs: ", Count[results, {_, True}], " built, ", Count[results, {_, False}], " failed"];
If[MemberQ[results, {_, False}], Exit[1]];
