# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`)  
**Next work:** **PR10** — distortion fields + environmental volumes.

Open this folder as the workspace. Read `docs/design.md` before writing code.

## Where things are

| Path | Role |
|---|---|
| **This repo** | The engine. Garden + cut-away + interact + DayClock. |
| `~/dragon16` | Historical **prototype**. Read-only. |

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite --headless --script res://tests/test_clock.gd
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dev/splite -- --shot=/tmp/garden.png --frames=20
```

Godot is `4.7.1` at `/Applications/Godot.app`. `--shot` needs a real window (not `--headless`).

## Product locks (do not reopen)

- Name is **Splite**. Camera: height 6.6, SW 0.82 / 0.82, FOV 60°.
- K17 black void. DayClock writes `ambient_light_*` only, never `background_color`.
- 16:00 is `AFTERNOON_SUN` exactly. Sun elevation never above 55°.

## PR1–PR9 — done

PR8: `e1ee378`. PR9: `DayClock` keyframed path, `[` `]` scrub ±0.5 h, lantern sway + ≤12 radial drops. Default `paused = true`. Lantern on at night or in the cellar. Cellar torch is still mesh-only.

## After PR9

PR10 distortion + volumes. Pond marker gets HEAT + ATMOS foam. Trunk marker gets a proc `SplatVolume` (CANOPY). No SKY volume.

MAPS: **§8**. Cut-away: **§3.3**. Environment: **K17**. Clock: **§2.5**. Volumes: **§2.4**.
