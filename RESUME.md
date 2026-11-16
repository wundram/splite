# Resume here

**Repo:** `/Users/wundram/dev/splite` (`main`)  
**Current playable scene:** `demos/living_garden/garden.tscn` (project default).
Captured a [28-second video tour](demos/living_garden/validation/living-garden-tour.mp4);
see [capture notes](WORKLOG.md#2026-09-08--living-garden-video-capture).
The Sleeping Garden expands to36×30 ground cells/1148 total cells. Woodland ramps,
34trees including a10.4m pine, five fitted tree instances, rose-wall TileDef,
solvable hedge maze, eldritch statues, wildlife, probe-reflective water and two
particle/refraction spells. Styled compass/3D portrait/map/help HUD. Earlier
terraced/procedural demos remain available.
**Next work:** review the dense scene, profile woodland GPU cost/LOD, train more
of the source-mesh scenery, and improve water reflection updates and art detail.
Final living-scene checks pass. [Evidence/previews](demos/living_garden/validation/README.md).
Full-resolution sampled means:48FPS woodland,62pond/spell,76maze on M1 Pro.
Five fitted trees plus Ranger total43k fitted Gaussians; new species/mobs are meshes.
Water uses captured probe reflections. Godot's7Texture-RID shutdown warning remains
unresolved. No new remote jobs; monitor stays paused.
See `docs/art-direction.md`, `docs/training-backends.md`, and `tools/pipeline/README.md`.

September revival: real Blender capture replaces fixture pixels; packing,
coordinate preservation, automatic evaluation/export/import and a Colab notebook
are implemented. Blender + host regression tests pass. Colab auth, package
installation and real gsplat CUDA forward/backward now pass on T4 after
recovery and a two-worker extension build. Calibration, tree and Ranger full fits,
budget refinement, normal supervision and Godot import have all completed.
See [WORKLOG.md](WORKLOG.md) for evidence and the next recovery experiment. User has an M4 mini with 48 GB RAM; evaluate native MLX candidates
alongside Colab. Painted miniature fantasy garden direction is confirmed.

All remote jobs are complete. Latest root `/content/splite-garden-v1`, final
`job-normals/status.json`, `phase-normals.json`, `job-normals/output.log`.
Every result archive, checkpoint and CUDA extension cache is saved locally under
`assets/training/`. Final clouds: tree8k PSNR30.83, Ranger3k PSNR38.48;
normal supervision reduced direction error and improved relighting. Five-minute
heartbeat `check-splite-colab-training` is paused with no active jobs; reactivate
when launching another remote job.
Use `/tmp/splite-colab-pipeline-status.py` via the pinned CLI described in WORKLOG.
User asked to close Colab browser tabs; all3 service tabs closed. Use CLI-first.
September 8 CLI check: no active Colab assignments. No remote jobs were launched
for the locally baked walk. Preserve credentials
in the private session config; never print its contents.

Source study: `demos/garden_study/garden_study.tscn`; fitted version:
`demos/garden_study/fitted_garden.tscn`. WASD movement with a ten-frame rig-deformed fitted walk and idle reset. CC0
Quaternius foliage and KayKit Ranger GLBs are ready, with reproducible Blender
preparation scripts and attribution. `FittedSplatBatch` preserves anisotropy and
passes a real GPU smoke test. `render_fitted_capture.gd` compares exact capture
cameras; importer `--reference` preserves full valid clouds for that check.
Optional scene lighting uses learned normals and source-mesh shadow proxies.
Animated moving-character benchmark on this M1 Pro:65.68FPS average,16.0ms p95
at1280x800. See `tools/pipeline/train/validation/garden/walk/`. The walk is a
source-rig deformation of the trained idle cloud, not independently fitted poses.
No native MLX backend or M4 connection has been established.

Open this folder as the workspace. Read `docs/design.md` before writing code.

Expanded-scene evidence: [validation](demos/garden_expanded/validation/README.md)
and September8 worklog entry. Traversal/door/rooms/night/camera tests pass; old
actor/world/tour checks and GPU anisotropy smoke pass. Default-resolution moving
route benchmark:123.62FPS average,17.43ms p95 at1920×1200 on M1 Pro. Camera follow
keeps its locked orientation; fitted batches skip translation-only rebuilds.
No new Colab runtime or training was used.

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

Separate discussion: AI engineering team operating-model research is recorded in
[the work log](WORKLOG.md#2026-09-06--ai-engineering-team-operating-model-research).
It introduces no change to Splite's implementation plan.
