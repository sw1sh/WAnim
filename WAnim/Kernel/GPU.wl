(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{GPUGraphics}]


(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{gpuRasterize}]


(* ::Section:: *)
(*GPUGraphics*)

(* GPUGraphics[graphics] draws a Graphics on the GPU (Metal), without the front end, into an Image the
   size its ImageSize and AspectRatio say: tens of times faster than Rasterize.  GPUGraphics[primitives,
   opts] takes what Graphics takes.  It draws polygons (with VertexColors), lines, disks, circles,
   rectangles (rounded), points, text in any installed font (by CoreText, as the front end on macOS), and
   insets of images and of graphics, under colours, Opacity, FaceForm, EdgeForm, Thickness, CapForm,
   Rotate and Style; the plot range must be explicit.  Anything else (curves, arrows, dashing, typeset
   text, 3D) gives a Failure saying what, so a caller can rasterize that one with the front end instead.
   The native library (native/, built by make into LibraryResources) is for macOS on Apple silicon. *)
Options[GPUGraphics] = {ImageSize -> Automatic};
GPUGraphics[g_Graphics, opts : OptionsPattern[]] := gpuRasterize[Graphics[First[g], Sequence @@ FilterRules[{opts}, ImageSize], Sequence @@ Rest[List @@ g]]];
GPUGraphics[prims : Except[_Graphics], opts : OptionsPattern[Graphics]] := gpuRasterize[Graphics[prims, opts]];

(* the library, loaded once a kernel; $Failed where there is none *)
gpuFunctions[] := gpuFunctions[] = With[{lib = FindLibrary["libwanimgpu"]},
    If[! StringQ[lib], $Failed, Quiet @ Check[{
        LibraryFunctionLoad[lib, "wanimRender", {LibraryDataType[ByteArray], Integer, Integer}, LibraryDataType[NumericArray, "UnsignedInteger8"]],
        LibraryFunctionLoad[lib, "wanimError", {}, "UTF8String"]}, $Failed]]];

(* the pixel size: ImageSize's width (360 when Automatic), and its height or the AspectRatio's *)
gpuSize[g_Graphics] := Module[{is = Replace[OptionValue[Graphics, Options[g], ImageSize], Automatic | _Symbol -> 360],
        ar = OptionValue[Graphics, Options[g], AspectRatio], pr = OptionValue[Graphics, Options[g], PlotRange], w},
    w = Round[Replace[is, {x_, _} :> x]];
    {w, Round[Which[
        MatchQ[is, {_ ? NumericQ, _ ? NumericQ}], is[[2]],
        NumericQ[ar], w ar,
        MatchQ[pr, {{_ ? NumericQ, _ ? NumericQ}, {_ ? NumericQ, _ ? NumericQ}}], w (pr[[2, 2]] - pr[[2, 1]]) / (pr[[1, 2]] - pr[[1, 1]]),
        True, w 0.618]]}];

gpuRasterize[g_Graphics] := gpuRasterize[g, gpuSize[g]];
gpuRasterize[g_Graphics, {w_Integer, h_Integer}] := With[{fs = gpuFunctions[]},
    If[fs === $Failed, Failure["GPUGraphics", <|"MessageTemplate" -> "The GPU renderer is not available on this platform."|>],
        With[{r = fs[[1]][BinarySerialize[g], w, h]},
            If[NumericArrayQ[r], Image[r, "Byte", ColorSpace -> "RGB", Interleaving -> True],
                Failure["GPUGraphics", <|"MessageTemplate" -> fs[[2]][]|>]]]]];
