#!/usr/bin/env wolframscript
(* wolframscript -f scripts/submit.wls [--check]
   Submit WolframInstitute/WAnim to the Wolfram Paclet Repository.

   The submission is WAnim/ResourceDefinition.nb, built from docs/ResourceDefinition.md by
   scripts/build_docs.wls together with the paclet's Documentation; edit the markdown and rebuild,
   never the notebook.  The account in .env.publish (gitignored) must own the WolframInstitute
   publisher.  With --check it stops after the definition notebook's own checks.

   There is no front end dialog under -f, so instead of SubmitRepository (which asks for the
   version interactively) the notebook is scraped into a ResourceObject and given to ResourceSubmit
   with the version and publisher of PacletInfo.  A "version already exists" error means an earlier
   submission of this version is still being processed: bump the version in PacletInfo.wl. *)

repoRoot  = ParentDirectory[DirectoryName[$InputFileName]];
pacletDir = FileNameJoin[{repoRoot, "WAnim"}];
nbFile    = FileNameJoin[{pacletDir, "ResourceDefinition.nb"}];
checkOnly = MemberQ[$ScriptCommandLine, "--check"];

If[! FileExistsQ[nbFile], Print["FATAL: ", nbFile, " does not exist; run scripts/build_docs.wls first."]; Exit[1]];
If[! DirectoryQ[FileNameJoin[{pacletDir, "Documentation", "English"}]], Print["FATAL: no built Documentation; run scripts/build_docs.wls first."]; Exit[1]];

(* resolve the paclet to this checkout, not an installed copy *)
PacletDirectoryLoad[pacletDir];
Needs["DefinitionNotebookClient`"];
Needs["ResourceSystemClient`"];
(* ScrapeResource lists the Documentation files with PacletTools; unloaded, a $Failed ends up in the
   listing and the repository rejects it ("disallowed symbols {System`$Failed}") *)
Needs["PacletTools`"];

(* show the endpoint, status and body of a rejected request: the client reports "Unknown error" for
   anything it cannot parse.  The condition always fails, so the usual handling still runs. *)
ResourceSystemClient`Private`handleError[head_, endpoint_, code_, chars_, params_, rbase_] /;
    (Print["API error ", code, " from ", endpoint, ": ", StringTake[Quiet @ Check[FromCharacterCode[chars], ToString[chars]], UpTo[1500]]]; False) := Null;

paclet    = PacletObject[File[pacletDir]];
version   = paclet["Version"];
publisher = paclet["PublisherID"];

Get[FileNameJoin[{repoRoot, "scripts", "cloud.wl"}]];
cloudConnect[FileNameJoin[{repoRoot, ".env.publish"}]];
(* ResourceSubmit checks the PublisherID option against $PublisherID *)
$PublisherID = publisher;
Print["submitting ", paclet["Name"], " ", version, " (publisher ", publisher, ") as ", $WolframID];

(* the repository refuses a submission with Error-level issues, so check first.  NoPacletInfoFileCell
   is expected: the paclet is attached from the loaded directory, not from a file cell. *)
issues = Normal @ UsingFrontEnd @ Block[{nb, r},
    nb = NotebookOpen[nbFile, Visible -> False];
    r = DefinitionNotebookClient`CheckDefinitionNotebook[nb];
    NotebookClose[nb];
    r];
Scan[Print["  [", #Level, "] ", #Tag] &, issues];
If[Select[issues, #Level === "Error" && #Tag =!= "NoPacletInfoFileCell" &] =!= {},
    Print["FATAL: the definition notebook has blocking errors."]; Exit[1]];
If[checkOnly, Print["check passed"]; Exit[0]];

(* the scrape packs whatever WolframInstitute__WAnim* it finds in WAnim/build: build it fresh every
   time, with PacletBuild, so a stale stage is never published under a new version *)
buildDir = FileNameJoin[{pacletDir, "build"}];
Scan[If[DirectoryQ[#], DeleteDirectory[#, DeleteContents -> True], DeleteFile[#]] &, FileNames["WolframInstitute__WAnim*", buildDir]];
built = PacletTools`PacletBuild[pacletDir, buildDir];
If[! MatchQ[built, _Success], Print["FATAL: PacletBuild failed: ", built]; Exit[1]];
Print["built ", FileNameTake[built["PacletArchive"]], " (", Round[FileByteCount[built["PacletArchive"]] / 2^20, 0.1], " MB)"];

(* scrape and submit with the notebook open: the scraped record reads from it *)
result = UsingFrontEnd @ Block[{nb, res, pf, r},
    nb = NotebookOpen[nbFile, Visible -> False];
    res = Quiet[DefinitionNotebookClient`ScrapeResource[DefinitionNotebookClient`NotebookResourceType[nb], nb, "IncludeNotebookData" -> True], {KeyDrop::invrl}];
    pf = Replace[Lookup[First[res], "PacletFile", None], File[f_] :> f];
    Print["artifact: ", If[StringQ[pf], FileNameTake[pf], "(none)"]];
    If[StringQ[pf] && ! StringContainsQ[FileNameTake[pf], version],
        NotebookClose[nb]; Print["FATAL: the artifact is not version ", version, "; not submitting."]; Exit[1]];
    r = ResourceSubmit[ResourceObject[res], "Version" -> version, PublisherID -> publisher];
    NotebookClose[nb];
    r];

Which[
    MatchQ[result, _Success], Print["SUBMITTED: ", Lookup[Last[result], "Message", ""]]; KeyValueMap[Print["  ", #1, ": ", #2] &, KeyDrop[Last[result], "Message"]],
    MatchQ[result, _ResourceObject], Print["SUBMITTED ", result["Name"], " ", result["Version"]],
    True, Print["NOT SUBMITTED: ", ToString[Short[result, 25], InputForm]]; Exit[1]];
