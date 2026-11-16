# Splite asset pipeline

The first working route is **Blender on Mac → Colab/CUDA Splatfacto → Godot**.
The M4 Mac mini (48 GB) is the intended native-training evaluation host. MLX is
an alternative backend to benchmark, not an implemented trainer in this repo.

## What is verified

Real Blender 4.1.1 CPU renders: evaluated geometry, material colors, distinct
view silhouettes, transparent background and camera framing. Host-side tests
cover filtered PNG decoding, world-coordinate flags, PLY import and mocked
train/evaluate/export failure propagation. Colab installation, T4 detection,
CUDA compiler availability, real gsplat forward/backward, and trainer CLI
startup passed on runtime
2026.07 (Python 3.12). **No real GPU fit has been completed yet.**
`train/versions.lock` remains a candidate baseline.

## 1. Prepare one static source

Use a `.glb`, `.gltf` (with its dependent textures) or `.blend`. Keep only the
asset being captured visible for rendering. A collection containing a whole
asset pack is not one tile. Record its actual source URL and license in
`assets/ATTRIBUTION.md`; suggested packs live in `docs/art-direction.md`.

Supported materials: a Principled BSDF connected directly to Material Output,
with texture/vertex-color networks feeding Base Color and Alpha. Capture
replaces shading with emission while retaining those networks. Other shader
layouts fail explicitly and need material preparation. Normal maps, gloss and
lighting are intentionally not baked into albedo. Save source files before
capture so their checksum can be recorded.

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python tools/pipeline/blender/cone_render.py -- \
  --source assets/sources/tree.blend --out assets/captures/tree_hero \
  --id tree_hero --tile-meters 2.5 --views 64 --resolution 512 \
  --license CC0 --url https://quaternius.com/packs/ultimatestylizednature.html
```

The destination must be empty. Capture evaluates modifiers/rig pose at
`--frame` (default 1), bakes world transforms, grounds and centers the whole
asset, and scales its **maximum X/Y footprint** to `--tile-meters`. Cameras
fit the complete bounds with a margin and span elevations 62–85°. Surface-area
sampling supplies 4096 geometry seeds (`--seed-points`). No SfM is required.

Coordinate contract: Blender Z-up `(x,y,z)` → Godot Y-up `(x,z,-y)`.
Both camera poses and seeds use that same frame. Training disables automatic
centering, orientation, scaling, COLMAP's extra world rotation and camera
optimization. Import does not remap positions again. PLY quaternions are wxyz;
Godot resource quaternions are normalized xyzw.

Output: RGBA images, `transforms.json`, `points3D.ply`, and `recipe.json` with
source checksum, Blender build, normalization transform, bounds and settings.
Colors use Standard/sRGB unlit base color; runtime color-space and relighting
parity still need a source-versus-Godot comparison.

## 2. Bundle and train in Colab

```sh
python3 -m pip install -r tools/pipeline/requirements.txt
python3 tools/pipeline/bundle_capture.py \
  --data assets/captures/tree_hero --out /tmp/tree_hero.zip
```

Open `train/colab.ipynb` in Google Colab, select a GPU runtime, and run its cells.
Upload the ZIP when prompted. The bundle includes the current pipeline code,
so a pushed repository is not required. The notebook installs the candidate
Nerfstudio 1.1.5 / gsplat 1.4.0 environment, checks CUDA/compiler availability,
tests real CUDA rasterization/backpropagation, trains, evaluates, exports and
downloads results. The smoke check limits CUDA compilation to two workers to
reduce host RAM pressure. Full-fit compatibility remains unverified.

Equivalent on an already configured CUDA host:

```sh
python tools/pipeline/train/train_cloud.py \
  --data assets/captures/tree_hero --out assets/training/tree_hero.ply \
  --budget 600 --iters 7000
```

Packing uses Pillow to decode real PNG filters and alpha-composites against
black. Masks are retained for inspection, but training uses full-image loss
so empty background constrains floaters. SH degree 0 keeps color independent
of view. Every ninth view is held out, spanning all four elevation rings.

Each fit gets its own output directory and exact config path. It runs
`ns-eval`, then `ns-export`, then the importer; subprocess failures propagate.
Outputs include full PLY, reduced `.tres`, checkpoint/config, evaluation and
run manifest. Existing outputs/pack directories are rejected to prevent stale
results from silently passing. Retry using a fresh capture copy and output
name; automatic checkpoint resume is not implemented. The notebook also saves
`pip freeze` and GPU/CUDA details. Download before disconnecting Colab.

**`--budget` limits the imported cloud, not the training population.** Current
farthest-point reduction can remove important splats; it is not a quality-aware
compression algorithm. Preserve the full fit. Evaluate full-fit, reduced-fit
and runtime images separately before accepting a budget.

## 3. Inspect before integrating

Copy an approved `.tres` into `assets/clouds/`. The game runs without training
dependencies. No new production fit has replaced the procedural garden yet.

```sh
python3 tools/pipeline/import/ply_to_cloud.py \
  --ply assets/training/tree_hero.ply --out assets/clouds/tree_hero.tres \
  --recipe assets/captures/tree_hero/recipe.json --budget 600
```

Importer handles scalar binary/ASCII PLY fields, rejects missing Gaussian
properties and empty clouds, filters nonfinite/out-of-bounds splats and stores
anisotropic scales/rotations. The runtime still draws isotropic billboards;
training metrics alone cannot validate the final game image.

The Ranger now has a coherent ten-frame walk. `blender/bake_skinned_clip.py`
transfers barycentric source skin weights to the normal-supervised idle fit,
then deforms Gaussian centers, full covariances and normals with the source rig.
It keeps Gaussian identity, colors, opacity and capture normalization fixed.
This is skeletal animation of a trained cloud, not ten independently trained poses.

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python tools/pipeline/blender/bake_skinned_clip.py -- \
  --out assets/clouds/garden/ranger_walk
```

The output directory must be new. Required local inputs are the captured Ranger
source, its capture recipe, the downloaded normal-refined PLY/normals and KayKit's
MovementBasic GLB. The bake writes frames, weights, source hashes, `actor.tres`,
and matching shadow GLBs under `assets/models/garden/ranger_walk`. Both garden
studies play it on WASD and return to idle on release. Run
`Godot --path . --script tools/pipeline/tests/validate_ranger_walk.gd` for real GPU
frame captures, correspondence/loop checks and synthetic keyboard control checks.
Pass `-- --source` for matching source-model reference frames. This deformation
can stretch Gaussians around joints and cannot recover surfaces absent from the
idle fit; held-out animated-pose quality metrics remain a separate next gate.

## Tests

```sh
python3 tools/pipeline/tests/test_cone_coords.py
python3 tools/pipeline/tests/test_colmap_pack.py
python3 tools/pipeline/tests/test_ply_import.py
python3 tools/pipeline/tests/test_pipeline_regressions.py
/Applications/Blender.app/Contents/MacOS/Blender -b \
  --python-exit-code 1 --python tools/pipeline/tests/blender_capture_smoke.py
```

`--fixture` emits intentionally fake identical images for format tests and is
rejected for training. Running capture in ordinary Python without `--fixture`
fails instead of silently emitting those images.

### Source study and renderer comparison

The acquired CC0 sources and preparation scripts are listed in
`assets/ATTRIBUTION.md`. Launch the separate source scene with:

```sh
Godot --path . res://demos/garden_study/garden_study.tscn
```

Use an unpruned import first when checking trainer/runtime parity:

```sh
python3 tools/pipeline/import/ply_to_cloud.py --ply <fit.ply> --out <full.tres> --reference
Godot --path . --script res://tools/pipeline/tests/render_fitted_capture.gd -- \
  --cloud=<absolute-full.tres> --transforms=<absolute-capture/transforms.json> \
  --frame=0 --size=256 --capture=<absolute-output.png>
```

`FittedSplatBatch` projects full ellipsoid covariance; the existing procedural
batch remains separate. Reference mode bypasses size/opacity/AABB pruning and
budget reduction. Compare source, trainer and runtime images before reducing.
Current caveats: Godot linear alpha blending differs from training in encoded RGB;
static and dynamic batches sort internally but not across each other.

The first T4 build can take over 30 minutes. A successful Python 3.12 / Torch
2.11.0+cu128 / gsplat 1.4.0 / T4 extension archive is saved locally under
`assets/training/cache/`, with its checksum/environment manifest. Restore only
into a matching environment's `/root/.cache/torch_extensions`, and rerun
`tests/cuda_smoke.py`; a cache is not a replacement for GPU validation. The
Nerfstudio 1.1.5 CLI accepts `--vis tensorboard`, not `none`. Small captures now
train at full resolution from the start and save checkpoints every 500 steps.

### Validated garden fitting sequence

The September T4 runs now include full source fits, budget refinement and learned
normal supervision. Runnable result:

```sh
Godot --path . res://demos/garden_study/fitted_garden.tscn
```

The tree uses 8,000 Gaussians and Ranger 3,000. Final held-out color PSNR is 30.83
and 38.48 dB respectively. Reports and resource hashes are under
`assets/clouds/garden/`; the original PLYs/checkpoints and all intermediate stages
are locally saved under ignored `assets/training/`.

1. Capture albedo from the normalized source at 32 views / 384 px. Also capture
   `--material-pass normals` with the same source, frame, footprint, views and
   resolution into another directory. Normal captures encode Godot world-space
   direction in RGB with Raw color management. Keep alpha and exact camera poses.
2. Run `train_cloud.py` at 4,000 steps. The wrapper preserves the full PLY and a
   `.full.tres` reference before its legacy budgeted import. The legacy geometric
   pruning is not the final production asset: it visibly damages leaf coverage.
3. Run `refine_budget.py` on the full PLY with `--budget 8000 --steps 1500`
   (tree) or 3,000 (Ranger). It ranks integrated compositing contributions across
   training cameras, then refits a fixed population against RGB/SSIM/alpha.
4. Run it again on that `refined.ply`, using the same budget, `--steps 2500`
   and `--normals <normal-capture>`. This optimizes normal features as well as
   geometry/color/opacity. Exact camera matching is enforced. Every ninth view
   is held out throughout both stages.
5. Import with `--reference --normals <output/normals.json>`. The explicit
   reference flag preserves ordering and avoids discarding valid fitted points.
   `FittedSplatBatch.scene_lighting=true` uses these learned normals with Godot's
   lights and shadows. Source meshes currently provide shadow proxies.

Example refinement on an existing Colab workspace:

```sh
python tools/pipeline/train/refine_budget.py --ply <full.ply> --data <capture> \
  --out <new-budget-directory> --budget 8000 --steps 1500
python tools/pipeline/train/refine_budget.py --ply <new-budget-directory/refined.ply> \
  --data <capture> --normals <normal-capture> --out <new-normal-directory> \
  --budget 8000 --steps 2500
python tools/pipeline/import/ply_to_cloud.py --ply <new-normal-directory/refined.ply> \
  --normals <new-normal-directory/normals.json> --out <asset.tres> --reference
```

Refinement writes fixed-population checkpoints every 500 steps and before/after
held-out RGB, foreground, alpha and normal errors. The current script saves
checkpoints but does not yet expose a resume CLI. Albedo-image fit is not a
relighting acceptance test: nearest-surface normals alone produced visible patches;
normal supervision reduced those patches without increasing the population.

`bake_surface_normals.py` is a source-normal transfer baseline, useful for
comparison. It verifies the capture's source hash and evaluates the original
pose/modifiers; it is not a replacement for the learned-normal stage.

The fitted study measured 66 FPS average / 15.9 ms p95 at 1280×800 on an M1 Pro while
moving/turning the Ranger (240 frames, uncapped). This is not an M4 benchmark.
The test script is `tests/benchmark_fitted_garden.gd`. Remaining work includes
multi-asset sorting, animated capture with shared normalization, performance at
larger scene scale, and visual approval of the asset family.
