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

That opens a black 1920×1200 window titled **Splite**. There is no
garden yet — the host project and an empty `addons/splite` plugin
are the first slice.

## Layout

| Path | What |
|---|---|
| `addons/splite/` | The plugin. This is the engine. |
| `addons/splite/editor/` | Empty until a tile painter. |
| `demos/` | Garden + tour (later PRs). |
| `tools/pipeline/` | Asset pipeline CLI (later PRs). |
| `assets/` | Source models, clouds, tiles (later PRs). |
| `docs/design.md` | Architecture (start here). |
