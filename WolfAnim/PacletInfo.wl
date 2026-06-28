(* ::Package:: *)

PacletObject[<|
  "Name" -> "WolfAnim",
  "Version" -> "0.2.0",
  "WolframVersion" -> "14.0+",
  "Description" -> "Live audiovisual coding: Manim-style animation and Strudel/Tidal-style cyclic-time music patterns -- one structure, two renderers.",
  "Creator" -> "Nikolay Murzin",
  "License" -> "MIT",
  "Keywords" -> {"animation", "live coding", "music", "Strudel", "TidalCycles", "patterns", "audio", "video"},
  "Categories" -> {"Graphics & Visualization", "Music"},
  "PrimaryContext" -> "WolfAnim`",
  "Dependencies" -> {"Wolfram/Parser", "MaTeX"},
  "Extensions" -> {
    {
      "Kernel",
      "Root" -> "Kernel",
      "Context" -> {"WolfAnim`"}
    },
    {
      "Kernel",
      "Root" -> "Strudel",
      "Context" -> {"WolfAnim`Strudel`"}
    }
  }
|>]
