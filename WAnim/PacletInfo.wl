(* ::Package:: *)

PacletObject[<|
  "Name" -> "WolframInstitute/WAnim",
  "PublisherID" -> "WolframInstitute",
  "Version" -> "0.5.0",
  "WolframVersion" -> "15.0+",
  "Description" -> "Live audiovisual coding: graphics with a time axis for Manim-style scenes and whole films, drawn with a canvas kit and scored with Strudel/Tidal-style cyclic-time music patterns",
  "Creator" -> "Nikolay Murzin",
  "License" -> "MIT",
  "Keywords" -> {"animation", "live coding", "music", "Strudel", "TidalCycles", "patterns", "audio", "video", "timeline", "motion graphics"},
  "Categories" -> {"Graphics & Visualization", "Music"},
  "PrimaryContext" -> "WolframInstitute`WAnim`",
  "Dependencies" -> {"Wolfram/Parser" -> ">=1.1"},
  "Extensions" -> {
    {
      "Kernel",
      "Root" -> "Kernel",
      "Context" -> {"WolframInstitute`WAnim`"}
    },
    {
      "Kernel",
      "Root" -> "Strudel",
      "Context" -> {"WolframInstitute`WAnim`Strudel`"}
    },
    {
      "Documentation",
      "Root" -> "Documentation",
      "Language" -> "English"
    },
    {
      "Test",
      "Root" -> "Tests",
      "Method" -> "Experimental-v1"
    },
    {
      "Asset",
      "Root" -> "Assets",
      "Assets" -> {
        {"Drums", "Drums"}
      }
    }
  }
|>]
