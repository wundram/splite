# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`)  
**Next work:** none in the v1 PR plan. Optional: pick a Poly Haven SKU and re-run PR11 on a real tree / player. Forest is still forbidden.

Open this folder as the workspace. Read `docs/design.md` before writing code.

## Where things are

| Path | Role |
|---|---|
| **This repo** | The engine. Showable garden + tour through PR12. |
| `~/dragon16` | Historical **prototype**. Read-only. |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite res://demos/tour/tour.tscn -- --hold-scale=0.25
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_tour.gd
```

Godot is `4.7.1` at `/Applications/Godot.app`.

## Product locks (do not reopen)

- Name is **Splite**. Camera: height 6.6, SW 0.82 / 0.82, FOV 60°.
- K17 black void. DayClock never writes `background_color`.
- 16:00 is `AFTERNOON_SUN`. No SKY volume. No second biome.

## PR1–PR12 — done

| PR | SHA | What |
|---|---|---|
| 1–4 | `c6bef98` | host, resources, renderer, world/camera |
| 5–7 | `7b35d8c` | actor, §8 garden, cut-away |
| 8 | `e1ee378` | interactables, door SEQUENCE, WorldHint |
| 9 | `5bf6922` | DayClock, lantern, `[` `]` |
| 10 | `c321226` | DistortionField + SplatVolume |
| 11a | `c72814b` | cone-render + coord test |
| 11b | `b42b868` | COLMAP pack + train wrapper |
| 11c | `e5922ea` | PLY import + `tree_hero.tres` |
| 12 | (this commit) | garden polish + feature tour |

Fitted `tree_hero.tres` is a hand-exported canopy stand-in (cube-trained path not run). Swap the real fit onto the canopy volume when CUDA has produced one. `player_walk` is still the proc chibi.

MAPS: **§8**. Tour beats: **§8 reel**. Pipeline: **§7**.
