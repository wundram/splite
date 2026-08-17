# Splite

A Godot 4 plugin: **tile-based top-down worlds rendered as volumetric
Gaussian splats**, with mesh surfaces, “splites” (splat-sprites), and
a locked near-top-down camera.

This repository is the engine. The first showable thing is a **single
garden scene** (interactive style demo). More scenes come after that
scene is something you would actually show someone.

Prototype work that led here lives in `~/dragon16` and is historical.

Design (reviewed): [`docs/design.md`](docs/design.md).

## Run

Godot **4.7** is at `/Applications/Godot.app`. From the repo root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

That opens a black 1920×1200 window titled **Splite**. WASD to walk
the garden; stairs climb when you walk along them. E opens the cellar
door / takes the ember. `[` `]` scrub the clock. Walk under the
stone walkway (or the trunk canopy) to see the cut-away. F3 draws
the hole cylinder.

Headless shot:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --shot=/tmp/garden.png --frames=20
```

## Layout

| Path | What |
|---|---|
| `addons/splite/` | The plugin. This is the engine. |
| `addons/splite/editor/` | Empty until a tile painter. |
| `demos/garden/` | Walkable clover slab + stair (main scene). |
| `tools/pipeline/` | Asset pipeline CLI (later PRs). |
| `assets/` | Source models, clouds, tiles (later PRs). |
| `docs/design.md` | Architecture (start here). |
