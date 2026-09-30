#!/usr/bin/env wolframscript
(* wolframscript -f scripts/build_docs.wls [pattern]
   Convert the markdown in docs/ into the paclet's documentation authoring notebooks with
   MarkdownToNotebook:
     docs/en/Guides/**/<Name>.md                  -> WAnim/Documentation/English/Guides/<Name>.nb
     docs/en/ReferencePages/Symbols/**/<Name>.md  -> WAnim/Documentation/English/ReferencePages/Symbols/<Name>.nb
     docs/en/Tutorials/**/<Name>.md               -> WAnim/Documentation/English/Tutorials/<Name>.nb
   Examples are evaluated against this checkout of the paclet; tutorials thread state across
   sections.  An optional pattern (e.g. "Typewriter") rebuilds only the matching pages.
   The paclet ships these authoring notebooks; PacletBuild (build.wls, scripts/submit.wls) turns them
   into the built pages with their index and navigation.
   docs/ResourceDefinition.md becomes WAnim/ResourceDefinition.nb, the Paclet Repository submission,
   its list of paclet files filled in so its Check covers every page.  The converter is the deployed
   MarkdownToNotebook resource function in the cloud.  Notebooks are artifacts (gitignored); the
   markdown is the source.  Exits 1 if a page fails. *)

repoRoot = ParentDirectory[DirectoryName[$InputFileName]];
Get[FileNameJoin[{repoRoot, "scripts", "cloud.wl"}]];
cloudConnect[FileNameJoin[{repoRoot, ".env"}]];
PacletDirectoryLoad[repoRoot];
Needs["WolframInstitute`WAnim`"];
Needs["PacletResource`DefinitionNotebook`"];
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"];

(* the converter is the deployed MarkdownToNotebook resource function; wrapping the URL in
   ResourceObject makes it resolve on parallel subkernels too *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];

docOut = FileNameJoin[{repoRoot, "WAnim", "Documentation"}];
kinds = {{"Guides", Automatic}, {FileNameJoin[{"ReferencePages", "Symbols"}], Automatic}, {"Tutorials", None}};
pattern = If[Length[$ScriptCommandLine] >= 2, $ScriptCommandLine[[2]], "*"];

buildPage[md_, out_, sep_] := With[{nb = FileNameJoin[{out, FileBaseName[md] <> ".nb"}]},
    Print["building ", FileNameTake[md]];
    Quiet @ DeleteFile[nb];
    TimeConstrained[mtn[md, nb, "UseCache" -> False, "EvaluateSeparator" -> sep], 900];
    If[FileExistsQ[nb], {md, True}, Print["  FAILED: ", FileNameTake[md]]; {md, False}]];
results = Flatten[Reap[Do[
    With[{src = FileNameJoin[{repoRoot, "docs", "en", k[[1]]}], out = FileNameJoin[{docOut, "English", k[[1]]}]},
        Quiet @ CreateDirectory[out, CreateIntermediateDirectories -> True];
        Do[Sow[buildPage[md, out, k[[2]]]], {md, Select[FileNames["*.md", src, Infinity], StringMatchQ[FileBaseName[#], pattern] &]}]],
    {k, kinds}]][[2]], 1];
Print["build_docs: ", Count[results, {_, True}], " built, ", Count[results, {_, False}], " failed"];

(* a Video an example rendered (a Track's or an AnimatedGraphics') is a local file; it goes to the cloud,
   public, named by its page, so the page plays it anywhere -- the Paclet Repository's cloud pages too *)
cloudVideos[nbFile_] := Module[{nb = Get[nbFile], k = 0, name = FileBaseName[nbFile], new},
    new = nb /. Cell[BoxData[b_], "Output", o___] /; StringContainsQ[ToString[b, InputForm], "wanim-" ~~ Shortest[__] ~~ ".mp4"] :>
        With[{file = First[StringCases[ToString[b, InputForm], p : (("/" | "\\") ~~ Shortest[Except["\""] ..] ~~ "wanim-" ~~ Shortest[Except["\""] ..] ~~ ".mp4") :> p, 1]]},
            Cell[BoxData[ToBoxes[Video[CopyFile[file, CloudObject["WAnim/Docs/" <> name <> "-" <> IntegerString[++k, 10, 2] <> ".mp4", Permissions -> "Public"],
                OverwriteTarget -> True]]]], "Output", o]];
    If[k > 0, Put[new, nbFile]; Print["  ", name, ": ", k, " videos in the cloud"]]];
Scan[cloudVideos, FileNames["*.nb", docOut, Infinity]];

(* the submission notebook: independent examples, so each resets the context *)
If[pattern === "*" || StringMatchQ["ResourceDefinition", pattern],
    mtn[FileNameJoin[{repoRoot, "docs", "ResourceDefinition.md"}], FileNameJoin[{repoRoot, "WAnim", "ResourceDefinition.nb"}],
        "UseCache" -> False, "EvaluateSeparator" -> Automatic];
    (* list the paclet's files in the notebook, as its file manager would *)
    UsingFrontEnd @ With[{nbo = NotebookOpen[FileNameJoin[{repoRoot, "WAnim", "ResourceDefinition.nb"}], Visible -> False]},
        (* the Check finds each file by its cell's ID: cells need IDs *)
        SetOptions[nbo, CreateCellID -> True];
        PacletResource`DefinitionNotebook`RefreshNotebookPacletFiles[nbo]; NotebookSave[nbo]; NotebookClose[nbo]];
    Print["  ResourceDefinition.md -> WAnim/ResourceDefinition.nb"]];

If[MemberQ[results, {_, False}], Exit[1]];
