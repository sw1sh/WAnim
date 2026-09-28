Needs["PacletManager`"];

$repoRoot = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], ".."}]];
pacletName = "WAnim";   (* the paclet directory; its full name is WolframInstitute/WAnim *)
$pacletRoot = FileNameJoin[{$repoRoot, pacletName}];

packPaclet[] := Module[{pacletFileName},
  pacletFileName = CreatePacletArchive[$pacletRoot, $repoRoot];
  If[TrueQ[FileExistsQ[FileNames["WolframInstitute__" <> pacletName <> "*.paclet"][[1]]]],
      Print[FileNames["WolframInstitute__" <> pacletName <> "*.paclet"][[-1]] <> " ... OK"],
      Print["Paclet not produced"]
    ]
]
