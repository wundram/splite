# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`; PR1–PR4 are uncommitted local work)  
**Next work:** **PR5** — player actor, stairs, presentation smoke.  
**Do not implement past PR5 unless the user asks.**

Open this folder as the workspace. Read `docs/design.md` before writing code. That document is the contract (reviewed, 4 rounds). This file is only the handoff.

## Where things are

| Path | Role |
|---|---|
| **This repo** | The engine. Host + resources + renderer + world/camera. No actor yet. |
| `~/dragon16` | Historical **prototype**. Read-only. Port *contracts*. |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_cloud.gd
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_world.gd
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite res://demos/_scratch/grid.tscn
```

Godot is `4.7.1` at `/Applications/Godot.app`.

## Product locks (do not reopen)

- Plugin **code name is Splite.** Types stay `SplatCloud` / `SplatWorld` / `Splite` / `SplatBatch`.
- Camera: near-top-down, **perspective**, ~10° **SW** tilt (height 6.6, west 0.82 on **−X**, south 0.82, FOV 60°). `look_at(focus, Vector3(0, 0, −1))`.
- Environment is a black void (K17). `WorldEnvironment` is **PR6**.
- Color is **albedo**. No player yet — that is this PR.

## PR1–PR3 — done

Godot 4.7 host. Resources. Hybrid renderer + `demos/_scratch/one_cloud.tscn`. `test_cloud.gd` PASS.

## PR4 — done (this working tree)

- `SplatWorld` — typed `Cell`s, `register_defs` / `set_cell` / `set_cell_state` / `set_active_rooms` / `is_walkable` / `floor_y` / `refresh(time, delta)`. Dirty flags `_needs_static` / `_needs_dyn` / `_needs_lights`.
- Hull meshes **only** when `TileSurface.visible`. No shadows-only hulls.
- Static drops from `cast_model`. `_receiver_y` starts at the **same** level (tiles are the ground).
- Frustum skip with a 2 m pad; static rebuilds when the camera’s rounded XZ cell changes.
- `SplatCameraRig` — defaults 6.6 / 0.82 / 0.82 / 60° / near 0.20 / far 40 / DOF 0.034.
- `plugin.gd` registers `SplatBatch`, `SplatWorld`, `SplatCameraRig`.
- `tests/test_world.gd` PASS (walk, rooms, SEQUENCE → `next_state`, ~10° SW tilt).
- Scratch `demos/_scratch/grid.tscn`: path ring + hybrid grass/bush + north HOUSE_IN alcove, bush drop visible. Verified in Godot.

## PR5 — do this

From `docs/design.md` §PR Plan and §5:

**Files**

- `addons/splite/core/splite_actor.gd`
- `addons/splite/dev/proc_catalog.gd` — player + a handful of one-state tiles
- `demos/shared/garden.gd` — minimal: grass rectangle + one stair run
- `demos/garden/garden_play.gd`
- `demos/garden/garden.tscn` as **main scene**

**Behavior**

- WASD, 10 fps walk clip, stair interpolation (`STAIRS`, N-exit, 2-tile span, `player_level` flips at 0.5).
- Footprint from `Splite.hitbox` (default ±0.18), not prototype magic ±0.16 / ±0.12.
- `--shot=` / `--frames=` / `--px=` headless path ports from `~/dragon16/demos/toybox/toybox.gd`.
- Register `SpliteActor` in `plugin.gd`.

**Done when:** you can walk a clover slab on a black void at the new camera scale. Last PR allowed to look like the prototype.

Port `splite_actor.gd` + `try_move` / `_update_stairs` from the prototype. Do **not** port the full garden MAPS (PR6), pale `_environment()`, or clover-as-style beyond the proc stand-in.

## After PR5 (do not start unless asked)

PR6 garden scaffold map → then PR7∥8∥9∥10.

## Suggested first commands for the new session

```sh
cd ~/dev/splite
git status
# then implement PR5 against docs/design.md §5
```
