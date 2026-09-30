(* ::Package:: *)

PacletObject[<|
  "Name" -> "WolframInstitute/WAnim",
  "PublisherID" -> "WolframInstitute",
  "Version" -> "0.5.0",
  "WolframVersion" -> "15.0+",
  "Description" -> "Live audiovisual coding: Manim-style scenes, films and Strudel-style music as graphics and patterns in time",
  "Creator" -> "Nikolay Murzin, Claude (Anthropic)",
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
