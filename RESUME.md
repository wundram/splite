# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`, clean)  
**Next work:** **PR1** — Godot 4.7 project + empty Splite plugin skeleton.  
**Do not implement past PR1 unless the user asks.**

Open this folder as the workspace. Read `docs/design.md` before writing code. That document is the contract (reviewed, 4 rounds). This file is only the handoff.

## Where things are

| Path | Role |
|---|---|
| **This repo** | The engine. Almost empty on purpose: README + `docs/design.md` only. |
| `~/dragon16` | Historical **prototype**. Runnable garden + tour. **Read-only.** Do not add features there. Port *contracts*, do not copy the clover data model. |

Run the prototype if you need to see the old demo:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dragon16
```

Tour: `Godot --path ~/dragon16 res://demos/tour/tour.tscn`  
Godot is `4.7.1` at `/Applications/Godot.app`.

## Product locks (do not reopen)

- Plugin **code name is Splite.** Addon path `addons/splite`. Types stay `SplatCloud` / `SplatWorld` / `Splite` / `SplatBatch`.
- **One garden scene first.** No forest / temple / cathedral / neon.
- Look: tactile / representational (Link’s Awakening plastic + E33 paint), not photoreal.
- Camera: near-top-down, **perspective**, ~10° SW tilt (height 6.6, SW 0.82, FOV 60°). Not ortho.
- Color is **albedo**; day/night + lantern later (PR9).
- Fitted assets: shop **Poly Haven CC0 first**. Fitted **player walk cycle** is the showable *intent*; proc chibi is the late-fit fallback. Training is **remote CUDA**; M1 Pro does not run splatfacto. Showable garden is **not** gated on the tree or fitted player.
- Dragon Rescue is a future consumer, not this repo’s name.

## PR1 — do this

From `docs/design.md` §PR Plan:

**Files**

- `project.godot`
- `icon.svg` (minimal is fine)
- `addons/splite/plugin.cfg`
- `addons/splite/plugin.gd`
- `addons/splite/editor/.gitkeep`
- README: run instructions + layout table

**Behavior**

- `EditorPlugin` with **empty** `_enter_tree` / `_exit_tree` — **register zero types**. Preloading a missing script will fail to enable the addon.
- Features string **`4.7`** (not the prototype’s `4.4`).
- Window **1920×1200**, **black** clear `Color(0.015, 0.016, 0.020)`, Forward+, MSAA 2×, **stretch off**.
- Main scene: a blank `Node3D`.
- Plugin listed under `editor_plugins` and enabled.

**Done when:** `/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite` opens a black window titled **Splite**.

`WorldEnvironment` is **PR6**, not PR1. Clear color only.

## After PR1 (do not start unless asked)

PR2 resources → PR3 renderer → PR4 world/camera → PR5 actor → PR6 garden map → then PR7∥8∥9∥10. Pipeline PR11a/b/c is off the garden critical path. PR12 is the showable demo + tour.

Full sequence and file lists: `docs/design.md` → **PR Plan**. Key decisions: **K1–K18**.

## Prototype vs this repo

Port from `~/dragon16` only what the design says to port (camera contract, room set, 4pm drop *math*, hybrid mesh-writes / splat-tests, distortion idea, `--shot=` harness later).

Do **not** port: `SplatTile` as a single-state Resource, untyped `cells` dict, clover catalog as production, hardcoded `try_interact`, pale `_environment()` / green ground plane, `cast_shadow` hulls on every grass tile.

## Suggested first commands for the new session

```sh
cd ~/dev/splite
git status
# then implement PR1 against docs/design.md
```
