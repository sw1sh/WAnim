Needs["PacletManager`"];

$repoRoot = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], ".."}]];
pacletName = "WAnim";   (* the paclet directory; its full name is WolframInstitute/WAnim *)
$pacletRoot = FileNameJoin[{$repoRoot, pacletName}];

deleteBuildDirectory[] := Quiet @ DeleteDirectory[FileNameJoin[{$repoRoot, "build", "paclet"}], DeleteContents -> True];

(* PacletBuild builds the documentation authoring notebooks into their pages and packs the paclet *)
packPaclet[] := Module[{built},
  Needs["PacletTools`"];
  built = Quiet[PacletTools`PacletBuild[$pacletRoot, FileNameJoin[{$repoRoot, "build", "paclet"}]], DocumentationBuild`DocumentationBuild::warning];
  If[! MatchQ[built, _Success], Print["Paclet not produced: ", built]; Return[$Failed]];
  Print[CopyFile[built["PacletArchive"], FileNameJoin[{$repoRoot, FileNameTake[built["PacletArchive"]]}], OverwriteTarget -> True], " ... OK"]
]
