# Splite asset pipeline

Mac half (this machine) + CUDA half (remote NVIDIA box). The game host is Apple Silicon; `ns-train splatfacto` will not run here.

```
CC0 model
  → cone_render.py          # Mac, Blender 4.x  (or --fixture cube)
  → train_cloud.py          # CUDA host
  → ply_to_cloud.py         # Mac
  → assets/clouds/<id>.tres # committed; clone-without-CUDA still walks
```

## Mac — cone-render (PR11a)

```
/Applications/Blender.app/Contents/MacOS/Blender -b assets/sources/tree.blend \
  --python tools/pipeline/blender/cone_render.py -- \
  --out assets/captures/tree_hero --tile-meters 1.0 --views 64
```

Until a Poly Haven SKU is picked, write a built-in cube capture:

```
python3 tools/pipeline/blender/cone_render.py --fixture \
  --out assets/captures/tree_hero --tile-meters 1.0 --views 64
```

Coordinate contract: Blender Z-up `(x, y, z)` → OpenGL / Godot Y-up `(x, z, −y)`. `transforms.json` and `points3D.ply` are already in that frame. The importer does not remap again.

Lighting: no scene lights, black transparent film, Standard view transform. RGBA PNG. Never below 55° elevation.

Test:

```
python3 tools/pipeline/tests/test_cone_coords.py
```

## CUDA — train (PR11b)

Pinned triple lives in `train/versions.lock`. Wrapper exits **2** if `ns-train` is missing. It does not fall back to a Mac CPU train.

```
python tools/pipeline/train/train_cloud.py \
  --data assets/captures/tree_hero \
  --out assets/clouds/tree_hero.ply \
  --budget 600 --iters 7000
```

Packs `ns/images/`, `ns/masks/`, `ns/colmap/sparse/0/` (SIMPLE_PINHOLE, OpenGL→COLMAP `R'`/`t'`), then:

```
ns-train splatfacto [method flags] --vis none --data …/ns colmap --masks-path masks
ns-export gaussian-splat --load-config <latest> --output-dir …
```

Test (no CUDA required):

```
python3 tools/pipeline/tests/test_colmap_pack.py
```

## Mac — import (PR11c)

```
python3 tools/pipeline/import/ply_to_cloud.py \
  --ply assets/clouds/tree_hero.ply \
  --out assets/clouds/tree_hero.tres \
  --budget 600
```

`f_dc` is treated as albedo. Higher SH is dropped.
