#!/usr/bin/env wolframscript
(* wolframscript -f scripts/build_gallery.wls: Notebooks/Gallery.md -> Notebooks/Gallery.nb, evaluated in one
   context against the installed WAnim paclet, with the deployed MarkdownToNotebook converter. *)
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"];
root = ParentDirectory[DirectoryName[$InputFileName]];
(* the converter is the deployed MarkdownToNotebook resource function; wrapping the URL in
   ResourceObject makes it resolve on parallel subkernels too *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
Print[mtn[FileNameJoin[{root, "Notebooks", "Gallery.md"}], FileNameJoin[{root, "Notebooks", "Gallery.nb"}], "UseCache" -> False, "EvaluateSeparator" -> None]];
