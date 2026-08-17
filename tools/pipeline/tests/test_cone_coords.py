#!/usr/bin/env python3
"""PR11a: fixture capture is Y-up, grounded, no camera below 55°, useful alpha."""

from __future__ import annotations

import json
import math
import struct
import sys
import tempfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "pipeline" / "blender"))

import cone_render  # noqa: E402


def _fail(msg: str) -> None:
    raise SystemExit(f"test_cone_coords: FAIL {msg}")


def _read_ply_xyz(path: Path):
    text = path.read_text().splitlines()
    i = 0
    n = 0
    while i < len(text):
        line = text[i].strip()
        if line.startswith("element vertex"):
            n = int(line.split()[-1])
        if line == "end_header":
            i += 1
            break
        i += 1
    pts = []
    for line in text[i : i + n]:
        x, y, z = line.split()[:3]
        pts.append((float(x), float(y), float(z)))
    return pts


def _png_mean_alpha(path: Path) -> float:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    w = h = None
    idat = b""
    while pos < len(data):
        ln = struct.unpack(">I", data[pos : pos + 4])[0]
        tag = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + ln]
        pos += 12 + ln
        if tag == b"IHDR":
            w, h, bit, ctype = struct.unpack(">IIBB", chunk[:10])
            if bit != 8 or ctype != 6:
                _fail(f"{path.name} is not 8-bit RGBA")
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    raw = zlib.decompress(idat)
    alphas = []
    row = 1 + w * 4
    for y in range(h):
        start = y * row + 1
        sl = raw[start : start + w * 4]
        for x in range(w):
            alphas.append(sl[x * 4 + 3] / 255.0)
    return sum(alphas) / max(len(alphas), 1)


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "cube"
        rc = cone_render.main([
            "--fixture", "--out", str(out), "--views", "8",
            "--tile-meters", "1.0", "--resolution", "64",
        ])
        if rc != 0:
            _fail(f"cone_render exited {rc}")
        tf = json.loads((out / "transforms.json").read_text())
        if abs(tf["camera_angle_x"] - cone_render.CAMERA_ANGLE_X) > 1e-9:
            _fail("camera_angle_x")
        frames = tf["frames"]
        if len(frames) != 8:
            _fail(f"expected 8 frames, got {len(frames)}")
        for fr in frames:
            c2w = fr["transform_matrix"]
            el = cone_render.camera_elevation_deg(c2w)
            if el < cone_render.MIN_ELEVATION_DEG:
                _fail(f"camera elevation {el:.1f} < 55")
        pts = _read_ply_xyz(out / "points3D.ply")
        ys = [p[1] for p in pts]
        if min(ys) < -1e-4:
            _fail(f"AABB not on Y=0 (min Y={min(ys)})")
        if max(ys) <= max(abs(p[0]) for p in pts) * 0.05:
            _fail("+Y is not up (flat in Y)")
        pngs = sorted((out / "images").glob("*.png"))
        if len(pngs) != 8:
            _fail(f"png count {len(pngs)}")
        for p in pngs:
            a = _png_mean_alpha(p)
            if not (0.02 < a < 0.98):
                _fail(f"{p.name} mean alpha {a:.3f} not in (0.02, 0.98)")
    print("test_cone_coords: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
