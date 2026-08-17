# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`)  
**Next work:** **PR11a** — cone-render + coordinate test. Or **PR12** (garden polish + feature tour). Do not start unless asked.

Open this folder as the workspace. Read `docs/design.md` before writing code.

## Where things are

| Path | Role |
|---|---|
| **This repo** | The engine. Walkable garden through PR10. |
| `~/dragon16` | Historical **prototype**. Read-only. |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_actor.gd
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite -- --shot=/tmp/garden.png --frames=20
```

Godot is `4.7.1` at `/Applications/Godot.app`. `--shot` needs a real window (not `--headless`).

## Product locks (do not reopen)

- Name is **Splite**. Camera: height 6.6, SW 0.82 / 0.82, FOV 60°.
- K17 black void. DayClock never writes `background_color`.
- 16:00 is `AFTERNOON_SUN`. No SKY volume yet.

## PR1–PR10 — done

| PR | SHA | What |
|---|---|---|
| 1–4 | `c6bef98` | host, resources, renderer, world/camera |
| 5–7 | `7b35d8c` | actor, §8 garden, cut-away |
| 8 | `e1ee378` | interactables, door SEQUENCE, WorldHint |
| 9 | `5bf6922` | DayClock, lantern, `[` `]` |
| 10 | (this commit) | DistortionField + SplatVolume. Pond HEAT + ATMOS foam. Trunk CANOPY. No SKY. |

## After PR10

PR11a cone-render. PR12 garden style + tour. Fitted `tree_hero` is a drop-in on the canopy volume.

MAPS: **§8**. Cut-away: **§3.3**. Environment: **K17**. Clock: **§2.5**. Volumes: **§2.4**.
