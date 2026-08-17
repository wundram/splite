# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`)  
**Next work:** **PR8** — interactables, tile states, world-space hints.

Open this folder as the workspace. Read `docs/design.md` before writing code.

## Where things are

| Path | Role |
|---|---|
| **This repo** | The engine. Walkable §8 garden + temporally stable cut-away. |
| `~/dragon16` | Historical **prototype**. Read-only. |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_actor.gd
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_world.gd
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite -- --shot=/tmp/garden.png --frames=20
```

Godot is `4.7.1` at `/Applications/Godot.app`. `--shot` needs a real window (not `--headless`).

## Product locks (do not reopen)

- Name is **Splite**. Camera: height 6.6, SW 0.82 / 0.82, FOV 60°.
- K17 black void. No fill light, no ground plane, fog off.
- Color is albedo.

## PR1–PR7 — done

PR1–PR4: `c6bef98`. PR5–PR7: actor, §8 garden, temporally stable cut-away.

- Cut XZ follows at ~14 Hz; Y tracks the head. `delta <= 0` snaps.
- IF_ABOVE compares hull floor to **feet** so a 1.25 m landing stays open while you stand under it.
- Walkway `P`/`L` is `IF_ABOVE`. Proc large-kernel canopy on `TrunkMarker` (`IF_OCCLUDES`). Not a `SplatVolume` until PR10.
- F3 debug cylinder. Static/hulls do not rebuild when the camera moves.

## After PR7

PR8 interactables / tile states / WorldHint. PR9 DayClock + lantern. PR10 distortion + volumes.

MAPS: **§8**. Cut-away: **§3.3**. Environment: **K17**.
