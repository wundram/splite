# Splite

A Godot 4 plugin: **tile-based top-down worlds rendered as volumetric
Gaussian splats**, with mesh surfaces, “splites” (splat-sprites), and
a locked near-top-down camera.

This repository is the engine. The first showable thing is a **single
garden scene** (interactive style demo). More scenes come after that
scene is something you would actually show someone.

Prototype work that led here lives in `~/dragon16` and is historical.

Design (reviewed): [`docs/design.md`](docs/design.md).

## Revival status

The default playable scene is [The Sleeping Garden](demos/living_garden/garden.tscn):
a 36×30 garden with woodland slopes, raised terraces, a seeded rose hedge maze,
climbing-rose wall tiles, two eldritch statues, reflective animated ponds and
peaceful rabbits, birds and koi. Thirty-four trees span five forms, including a
10.4-metre landmark pine. Five tree placements and the animated Ranger use
trained Gaussian clouds; other new assets are meshes.

The styled HUD includes a compass, live 3D character view, map and help notes.
WASD/arrows move; E interacts; Space/Q cast verdant/moonlight spells; I toggles
the portrait; M opens the map; H/F1 opens help; [ / ] changes time.
[Validation and previews](demos/living_garden/validation/README.md).
Previous demos remain at `demos/garden_expanded/garden.tscn` and
`demos/garden/garden.tscn`.
Start with [art direction](docs/art-direction.md), [training hosts](docs/training-backends.md)
and the [pipeline guide](tools/pipeline/README.md). Feature completion is not
visual acceptance.

The new [fitted garden study](demos/garden_study/fitted_garden.tscn) uses an
8,000-Gaussian tree and 3,000-Gaussian Ranger with learned normals. Run it with
`Godot --path . res://demos/garden_study/fitted_garden.tscn` and move with WASD.
[Validation and screenshot](tools/pipeline/train/validation/garden/README.md).

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

Feature tour (no input, quits 0):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://demos/tour/tour.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . res://demos/tour/tour.tscn -- --hold-scale=0.25
```

## Layout

| Path | What |
|---|---|
| `addons/splite/` | The plugin. This is the engine. |
| `addons/splite/editor/` | Empty until a tile painter. |
| `demos/garden/` | Walkable garden style demo (main scene). |
| `demos/tour/` | Captioned feature tour; `--hold-scale=0.25` for CI. |
| `tools/pipeline/` | Cone-render → COLMAP pack → PLY import. |
| `assets/` | Checked-in clouds (`tree_hero.tres`) and attributions. |
| `docs/design.md` | Architecture (start here). |
