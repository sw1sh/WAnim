#!/usr/bin/env wolframscript
(* wolframscript -f scripts/build_docs.wls [pattern]
   Build the paclet's documentation from the markdown in docs/, in two stages.
   1. MarkdownToNotebook turns each page into an authoring notebook under build/DocSource/English:
        docs/en/Guides/**/<Name>.md                  -> Guides/<Name>.nb
        docs/en/ReferencePages/Symbols/**/<Name>.md  -> ReferencePages/Symbols/<Name>.nb
        docs/en/Tutorials/**/<Name>.md               -> Tutorials/<Name>.nb
      Examples are evaluated against this checkout of the paclet; tutorials thread state across
      sections.  An optional pattern (e.g. "Typewriter") rebuilds only the matching pages.
   2. DocumentationBuild turns all of build/DocSource into WAnim/Documentation: the pages with their
      navigation and the Index, SearchIndex and SpellIndex, without which a published paclet shows
      only its landing page.
   docs/ResourceDefinition.md becomes WAnim/ResourceDefinition.nb, the Paclet Repository submission
   (see scripts/submit.wls).  The converter is the deployed MarkdownToNotebook resource function in
   the cloud.  Notebooks are artifacts (gitignored); the markdown is the source.  Exits 1 if a page
   fails. *)

repoRoot = ParentDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repoRoot, "scripts", "cloud.wl"}]];
cloudConnect[FileNameJoin[{repoRoot, ".env"}]];
PacletDirectoryLoad[repoRoot];
Needs["WolframInstitute`WAnim`"];
Needs["DocumentationBuild`"];
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"];

(* the converter is the deployed MarkdownToNotebook resource function; wrapping the URL in
   ResourceObject makes it resolve on parallel subkernels too *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];

srcOut = FileNameJoin[{repoRoot, "build", "DocSource"}];
docOut = FileNameJoin[{repoRoot, "WAnim", "Documentation"}];
kinds = {{"Guides", Automatic}, {FileNameJoin[{"ReferencePages", "Symbols"}], Automatic}, {"Tutorials", None}};
pattern = If[Length[$ScriptCommandLine] >= 2, $ScriptCommandLine[[2]], "*"];

buildPage[md_, out_, sep_] := With[{nb = FileNameJoin[{out, FileBaseName[md] <> ".nb"}]},
    Print["building ", FileNameTake[md]];
    Quiet @ DeleteFile[nb];
    TimeConstrained[mtn[md, nb, "UseCache" -> False, "EvaluateSeparator" -> sep], 900];
    If[FileExistsQ[nb], {md, True}, Print["  FAILED: ", FileNameTake[md]]; {md, False}]];
results = Flatten[Reap[Do[
    With[{src = FileNameJoin[{repoRoot, "docs", "en", k[[1]]}], out = FileNameJoin[{srcOut, "English", k[[1]]}]},
        Quiet @ CreateDirectory[out, CreateIntermediateDirectories -> True];
        Do[Sow[buildPage[md, out, k[[2]]]], {md, Select[FileNames["*.md", src, Infinity], StringMatchQ[FileBaseName[#], pattern] &]}]],
    {k, kinds}]][[2]], 1];
Print["build_docs: ", Count[results, {_, True}], " built, ", Count[results, {_, False}], " failed"];

Print["DocumentationBuild: build/DocSource -> WAnim/Documentation"];
Quiet @ DeleteDirectory[docOut, DeleteContents -> True];
UsingFrontEnd @ DocumentationBuildNotebooks[srcOut, docOut, "LinkBase" -> "WolframInstitute/WAnim"];
Print["  ", Length @ FileNames["*.nb", FileNameJoin[{docOut, "English"}], Infinity], " documentation notebooks"];

(* the submission notebook: independent examples, so each resets the context *)
If[pattern === "*" || StringMatchQ["ResourceDefinition", pattern],
    mtn[FileNameJoin[{repoRoot, "docs", "ResourceDefinition.md"}], FileNameJoin[{repoRoot, "WAnim", "ResourceDefinition.nb"}],
        "UseCache" -> False, "EvaluateSeparator" -> Automatic];
    Print["  ResourceDefinition.md -> WAnim/ResourceDefinition.nb"]];

If[MemberQ[results, {_, False}], Exit[1]];
