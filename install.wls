#!/usr/bin/env wolframscript

$successQ = True;

pacletName = "WolframInstitute/WAnim"

(* If any messages are produced, fail with non-zero exit code. *)
Check[
  $repoRoot = DirectoryName[$InputFileName];
  $latestPacletFiles = MaximalBy[
    FileNames[FileNameJoin[{$repoRoot, "*.paclet"}]], FileInformation[#, "LastModificationDate"] &];

  If[Length[$latestPacletFiles] == 0,
    Print[
        "No paclet files *.paclet were found. ",
        "Run ./build.wls."];
    Exit[1];
  ];

  If[PacletFind[pacletName] =!= {}, PacletUninstall[pacletName]];

  If[PacletObjectQ[PacletInstall[First[$latestPacletFiles], "IgnoreVersion" -> True]],
    Print["Installed " <> First[$latestPacletFiles] <> ". Run Needs[\"WolframInstitute`WAnim`\"] to load the package."],
    Print["Install failed."];
    $successQ = False];,

  $successQ = False;
];

Exit[If[$successQ, 0, 1]]
