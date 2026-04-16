# 3D Mannequin Try-On Pipeline

This document defines the path from the current 2D studio preview to a real 3D mannequin try-on system.

## Product Goal

Users upload clothing photos, organize their wardrobe, and preview items on a standard mannequin. The short-term product uses a stable shared mannequin. The long-term product should render garments on a real 3D mannequin and later support subtle edge motion such as wind on hems, sleeves, and outerwear edges.

## Current State

- The app has a working 2D `Try On Studio`.
- The app has an AI Try-On path backed by a standard mannequin image.
- The app now includes a 3D mannequin manifest at `assets/mannequin/standard_mannequin.v1.json`.
- The current `3D Build` screen is still a foundation view, not a real GLB renderer yet.

## Asset Standard

The first real mannequin asset should be a licensed `.glb` file with:

- Humanoid skeleton.
- Neutral A-pose or relaxed A-pose.
- Clean front-facing default camera.
- Stable bone names listed in the manifest.
- Plain material without distracting branding.
- Reasonable polygon count for mobile rendering.

Recommended search terms for finding candidates:

- `humanoid mannequin glb a-pose rigged`
- `fashion mannequin rigged glb`
- `male female mannequin glb rigged`
- `game ready mannequin glb humanoid`

Good sources to check:

- Sketchfab, filtering for downloadable and commercial-use licenses.
- CGTrader, with `GLB`, `FBX`, or `Blender` models that can be exported to GLB.
- TurboSquid, checking mobile/game-ready topology.
- BlenderKit, if the license is compatible.

## Folder Layout

```text
assets/
  mannequin/
    standard_mannequin.v1.json
    standard_mannequin.v1.glb      # future real asset
    textures/                     # future optional textures
```

## Manifest Contract

The manifest is the stable contract between UI, 3D rendering, AI rendering, and future cloth motion.

Important fields:

- `model.path`: null today, should become `assets/mannequin/standard_mannequin.v1.glb`.
- `rig.requiredBones`: bones the selected GLB must expose.
- `garmentSlots`: maps wardrobe categories to mannequin regions.
- `motion.windAffectedZones`: future cloth-motion zones.

## Implementation Phases

1. Manifest foundation
Status: done.

2. Real GLB mannequin asset
Add a licensed GLB model and update `model.path`.

3. Flutter 3D renderer
Add a viewer package or native renderer that can load GLB. Candidate packages must be tested on iOS, Android, and macOS.

4. Garment anchoring
Map processed PNGs to 3D billboard planes first. This is cheaper and safer than true cloth simulation.

5. AI realistic try-on
Use the standard mannequin render plus product photo as the AI input. This is the fastest path to realistic visuals.

6. True 3D cloth
Only after product-market validation, explore mesh fitting, UV projection, and cloth simulation. This is the expensive path.

## Recommended Near-Term Decision

Use the hybrid approach:

- Keep `Try On Studio` as free and instant.
- Use AI Try-On as premium/high-value generation.
- Use 3D mannequin first for camera consistency and presentation.
- Defer true cloth simulation until the app has enough usage to justify the cost.

