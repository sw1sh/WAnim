---
Template: Symbol
Name: DictionaryCard
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/DictionaryCard
Keywords: [dictionary, entry, symbol, usage, WolframLanguageData, version introduced]
SeeAlso: [WolframLanguageData, CaptionText, TitleCard]
RelatedGuides: [WAnim]
---

## Usage

<code>[DictionaryCard]()["*symbol*", {$t_0$, $t_1$}]</code> presents a Wolfram Language symbol as a dictionary entry: its name, a line with the version and year that introduced it, and its usage.

## Details & Options

- The usage (first usage statement) and the version and date introduced are looked up with [WolframLanguageData](); "Usage" and "Note" override them, for example for a symbol too new to be in the data.
- The headword shrinks until it fits "Width"; at most "Lines" lines of usage are shown, revealed line by line.
- DictionaryCard takes the options common to all creation tools ([Backdrop]()) and these:

| Option | Default | Description |
| --- | --- | --- |
| "Usage" | Automatic | the usage text; `Automatic` looks it up |
| "Note" | Automatic | the part-of-speech line; `Automatic` gives the version and year introduced |
| "Width" | 590 | column width in pixels |
| "Lines" | 5 | most lines of usage to show |
| Position | {1250, 330} | baseline of the headword |

## Basic Examples

The entry for Names, looked up live:

```wl
DictionaryCard["Names", {0, 2}][1, ImageSize -> 480]
```

<!-- => "Names", "symbol · since 1.0, 1988" and its usage line -->

---

A newer symbol:

```wl
DictionaryCard["TuringMachine", {0, 2}][1, ImageSize -> 480]
```

<!-- => "TuringMachine", "symbol · since 6.0, 2007" and its usage -->

## Options

### Usage and Note

A symbol with its own usage and note:

```wl
DictionaryCard["MusicNote", {0, 2}, "Note" -> "symbol \[CenterDot] new in 15.0, 2026", "Usage" -> "MusicNote[p, d] returns a music note with the specified pitch p and duration d."][1, ImageSize -> 480]
```

<!-- => the MusicNote entry with the given note and usage -->
