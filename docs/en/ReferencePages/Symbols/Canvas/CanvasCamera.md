---
Template: Symbol
Name: CanvasCamera
Context: WolframInstitute`WAnim`
Paclet: WolframInstitute/WAnim
URI: WolframInstitute/WAnim/ref/CanvasCamera
Keywords: [3D, camera, perspective, projection, point cloud, surface, sphere, Bloch sphere, canvas]
SeeAlso: [CanvasCloud, CanvasCurve3D, CanvasSurface3D, CanvasSphere3D, CanvasLine]
RelatedGuides: [WAnim]
---

## Usage

<code>[CanvasCamera]()[*opts*]</code> is a perspective camera for the 3D canvas tools.

<code>[CanvasCloud]()[*camera*, *points*, *colour*, *r*]</code> draws glowing dots at 3D points; <code>[CanvasCurve3D]()[*camera*, *points*, *colour*, *thickness*]</code> a path through space; <code>[CanvasSurface3D]()[*camera*, *grid*, *colours*]</code> a lit surface from a grid of points; <code>[CanvasSphere3D]()[*camera*, *centre*, *r*, *colour*]</code> a sphere with its meridians and parallels.

## Details & Options

- The 3D tools project a scene through the camera and draw it as ordinary canvas primitives -- disks, lines, polygons -- far to near. Nothing is rasterized, so the camera can move every frame and a scene draws on the GPU.
- The camera looks at "Target" from "Azimuth" (about the vertical z axis) and "Elevation", "Distance" away (smaller is more perspective), and puts the target at canvas point "Center", "Scale" pixels to the unit.
- Colours may be one colour or one per point; a surface's may also be a grid of colours or a function of the point. A surface is shaded smoothly per vertex by its "Light", without seams; "Mesh" -> *colour* draws its grid lines instead.
- [CanvasLine]() and [CanvasDisk]() take "Glow" -> *r*, a halo *r* pixels wide; the cloud and curve pass it on.

| Option | Default | Description |
| --- | --- | --- |
| "Azimuth" | 0.6 | the camera's angle about the z axis, in radians |
| "Elevation" | 0.35 | its angle above the horizon |
| "Distance" | 8 | its distance from the target |
| "Target" | {0, 0, 0} | the point it looks at |
| "Center" | {960, 540} | where the target appears on the canvas |
| "Scale" | 200 | canvas pixels to the unit at the target |

## Basic Examples

A turning Bloch sphere with its state:

```wl
With[{v = Normalize[{0.6, 0.4, 0.7}]}, AnimatedGraphics[Function[t, With[{cam = CanvasCamera["Center" -> {300, 200}, "Scale" -> 140, "Azimuth" -> 0.6 + t]}, {CanvasRectangle[{0, 0, 600, 400}, Black], CanvasSphere3D[cam, {0, 0, 0}, 1, RGBColor["#58C4DD"]], CanvasCurve3D[cam, {{0, 0, 0}, v}, Orange, 5, "Glow" -> 8]}]], "CanvasSize" -> {600, 400}, "Duration" -> 2][0.5, ImageSize -> 360]]
```

<!-- => a wireframe sphere with an orange glowing vector -->

---

A lit surface:

```wl
AnimatedGraphics[{CanvasRectangle[{0, 0, 600, 400}, Black], CanvasSurface3D[CanvasCamera["Center" -> {300, 230}, "Scale" -> 70], Table[{x, y, Exp[-x^2 - y^2] Cos[3 x]}, {x, -2, 2, 0.1}, {y, -2, 2, 0.1}], RGBColor["#58C4DD"]]}, "CanvasSize" -> {600, 400}][0, ImageSize -> 360]
```

<!-- => a smooth blue rippled surface -->
