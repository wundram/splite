# Expanded garden validation — 2026-09-08

The playable default now spans 16×14 ground cells and three raised levels
(292 cells total). The connected route climbs north at (10,8), turns east on
the landing, climbs north at (12,5), then reaches the west lookout via (2,4).
The original garden and tour remain available at their existing scene paths.

`tests/test_expanded_garden.gd` walks all three flights up and down without
teleporting; opens the door through its sequence, checks the visible hinge angle
and walkability timing, enters/exits the cellar, takes the ember, checks night
lantern activation, idle reset and camera orientation. All pass. Checkpoint
images are numbered in traversal order. Original actor/world/tour tests pass,
and the actual GPU anisotropic renderer smoke passes.

`tests/benchmark_expanded_garden.gd` measures 360 real rendered frames with an
animated moving Ranger, a following camera and two stair ascents. M1 Pro,
Godot4.7.1/Metal, vsync disabled:

| Resolution | Mean FPS | Mean frame | p95 frame |
| --- | ---: | ---: | ---: |
| 1280×800 | 143.40 | 6.97 ms | 17.18 ms |
| 1920×1200 | 123.62 | 8.09 ms | 17.43 ms |

This is a bounded route benchmark, not a sustained minimum-FPS guarantee.
Initial rebuilding on every camera translation measured15FPS. Camera follow now
preserves orientation, and fitted batches rebuild for basis/pose changes rather
than translations, which leave within-batch depth ordering unchanged.

Ranger and two trees are fitted Gaussian clouds. Shrubs, grass, flowers and rocks
are CC0 source meshes; architecture/furniture are procedural meshes. The water
foam retains the earlier distortion animation. Door uses the existing tile-state
sequence with a mesh hinge; ember bobs/rotates. Source proxies cast tree/character
shadows. Cross-batch Gaussian ordering, richer architectural assets, and exact
colliders for decorative furniture remain future work.
