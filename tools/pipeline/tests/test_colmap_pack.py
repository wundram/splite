#!/usr/bin/env python3
"""PR11b: 4-view COLMAP pack matches the §7.2 contract."""

from __future__ import annotations

import math
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "pipeline" / "blender"))
sys.path.insert(0, str(ROOT / "tools" / "pipeline" / "train"))

import cone_render  # noqa: E402
import train_cloud  # noqa: E402


def _fail(msg: str) -> None:
    raise SystemExit(f"test_colmap_pack: FAIL {msg}")


def _image_rows(path: Path):
    rows = []
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line and not line.startswith("#"):
            rows.append(line.split())
            i += 1
            if i < len(lines) and (lines[i].strip() == "" or lines[i][0].isdigit() is False):
                i += 1
            continue
        i += 1
    return rows


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        cap = Path(td) / "cap"
        rc = cone_render.main([
            "--fixture", "--out", str(cap), "--views", "4",
            "--tile-meters", "1.0", "--resolution", "64",
        ])
        if rc != 0:
            _fail(f"fixture {rc}")
        ns = train_cloud.pack(cap)
        images = sorted((ns / "images").glob("*.png"))
        masks = sorted((ns / "masks").glob("*.png"))
        img_rows = _image_rows(ns / "colmap" / "sparse" / "0" / "images.txt")
        if not (len(images) == len(masks) == len(img_rows) == 4):
            _fail(f"counts images={len(images)} masks={len(masks)} rows={len(img_rows)}")

        cam = (ns / "colmap" / "sparse" / "0" / "cameras.txt").read_text().strip().splitlines()[-1].split()
        if cam[1] != "SIMPLE_PINHOLE":
            _fail(f"camera model {cam[1]}")
        w = int(cam[2])
        f = float(cam[4])
        want = train_cloud.focal_px(w, cone_render.CAMERA_ANGLE_X)
        if abs(f - want) > 0.01:
            _fail(f"f {f} != {want}")

        pts = []
        for line in (ns / "colmap" / "sparse" / "0" / "points3D.txt").read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            bits = line.split()
            pts.append((float(bits[1]), float(bits[2]), float(bits[3])))
        ys = [p[1] for p in pts]
        if min(ys) < -1e-4:
            _fail(f"min Y {min(ys)}")
        if sum(ys) / len(ys) < 0.0:
            _fail("mean Y < 0")
        max_xz = max(max(abs(p[0]) for p in pts), max(abs(p[2]) for p in pts))
        if max(ys) <= max_xz * 0.2:
            _fail("longest axis is not +Y (not sitting on the ground)")

        tf_frames = __import__("json").loads((cap / "transforms.json").read_text())["frames"]
        for fr in tf_frames:
            Rp, _tp = train_cloud.opengl_c2w_to_colmap(fr["transform_matrix"])
            axis = train_cloud.optical_axis_world(Rp)
            if axis[1] >= 0.0:
                _fail(f"camera looks +Y (axis={axis})")

    print("test_colmap_pack: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
