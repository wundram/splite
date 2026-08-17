# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`)  
**Next work:** **PR9** — DayClock, high-latitude sun, lantern.

Open this folder as the workspace. Read `docs/design.md` before writing code.

## Where things are

| Path | Role |
|---|---|
| **This repo** | The engine. Walkable §8 garden + cut-away + interactables. |
| `~/dragon16` | Historical **prototype**. Read-only. |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_actor.gd
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite -- --shot=/tmp/garden.png --frames=20
```

Godot is `4.7.1` at `/Applications/Godot.app`. `--shot` needs a real window (not `--headless`).

## Product locks (do not reopen)

- Name is **Splite**. Camera: height 6.6, SW 0.82 / 0.82, FOV 60°.
- K17 black void. No fill light, no ground plane, fog off.
- Color is albedo. DayClock must never write `background_color`.

## PR1–PR8 — done

PR5–PR7: `7b35d8c`. PR8: `Interactable` / `TileInteractable` / `WorldHint`. Cellar door is `closed → opening (4 frames @ 10 fps) → open`. Ember is an `Interactable`. Corner prompt is gone; one `WorldHint` retargets. Upstairs door stays a wall.

## After PR8

PR9 DayClock + lantern (`[` `]` scrub). PR10 distortion + volumes.

MAPS: **§8**. Cut-away: **§3.3**. Environment: **K17**. Clock: **§2.5**.
