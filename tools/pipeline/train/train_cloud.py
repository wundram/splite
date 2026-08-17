#!/usr/bin/env python3
"""Pack a cone-render capture into COLMAP text and optionally ns-train.

CUDA host only for the train step. Pack is host-agnostic.

    python tools/pipeline/train/train_cloud.py \
        --data assets/captures/tree_hero \
        --out assets/clouds/tree_hero.ply \
        --budget 600 --iters 7000

    python tools/pipeline/train/train_cloud.py --data … --pack-only
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path


def focal_px(width: int, camera_angle_x: float) -> float:
    return width / (2.0 * math.tan(camera_angle_x / 2.0))


def mat3_to_quat_wxyz(R):
    """Hamilton quaternion (w, x, y, z) from a 3×3 row-major rotation."""
    m00, m01, m02 = R[0]
    m10, m11, m12 = R[1]
    m20, m21, m22 = R[2]
    tr = m00 + m11 + m22
    if tr > 0.0:
        s = math.sqrt(tr + 1.0) * 2.0
        w = 0.25 * s
        x = (m21 - m12) / s
        y = (m02 - m20) / s
        z = (m10 - m01) / s
    elif m00 > m11 and m00 > m22:
        s = math.sqrt(1.0 + m00 - m11 - m22) * 2.0
        w = (m21 - m12) / s
        x = 0.25 * s
        y = (m01 + m10) / s
        z = (m02 + m20) / s
    elif m11 > m22:
        s = math.sqrt(1.0 + m11 - m00 - m22) * 2.0
        w = (m02 - m20) / s
        x = (m01 + m10) / s
        y = 0.25 * s
        z = (m12 + m21) / s
    else:
        s = math.sqrt(1.0 + m22 - m00 - m11) * 2.0
        w = (m10 - m01) / s
        x = (m02 + m20) / s
        y = (m12 + m21) / s
        z = 0.25 * s
    n = math.sqrt(w * w + x * x + y * y + z * z)
    return (w / n, x / n, y / n, z / n)


def opengl_c2w_to_colmap(c2w):
    """OpenGL cam2world → COLMAP world-to-camera (R', t')."""
    R = [[c2w[r][c] for c in range(3)] for r in range(3)]
    t = [c2w[0][3], c2w[1][3], c2w[2][3]]
    Rt = _transpose(R)
    tw = _mul_mat_vec(Rt, t)
    tw = (-tw[0], -tw[1], -tw[2])
    # R' = diag(1, -1, -1) @ R_w2c_gl
    Rp = [
        [Rt[0][0], Rt[0][1], Rt[0][2]],
        [-Rt[1][0], -Rt[1][1], -Rt[1][2]],
        [-Rt[2][0], -Rt[2][1], -Rt[2][2]],
    ]
    tp = (tw[0], -tw[1], -tw[2])
    return Rp, tp


def optical_axis_world(Rp):
    """COLMAP +Z_cam in world = row 2 of R' (R maps world → camera)."""
    # x_cam = R' * x_world, so camera +Z axis in world is the third row of R'.
    return (Rp[2][0], Rp[2][1], Rp[2][2])


def read_ply_xyz(path: Path):
    text = path.read_text().splitlines()
    n = 0
    i = 0
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


def png_size_and_mask(src: Path, dst_mask: Path) -> tuple[int, int]:
    data = src.read_bytes()
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
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    raw = zlib.decompress(idat)
    # Write L8 mask: 255 where source alpha > 8.
    mask_raw = bytearray()
    rowb = 1 + w * (4 if ctype == 6 else (3 if ctype == 2 else 1))
    for y in range(h):
        mask_raw.append(0)
        start = y * rowb + 1
        sl = raw[start : start + w * 4]
        for x in range(w):
            a = sl[x * 4 + 3] if ctype == 6 else 255
            mask_raw.append(255 if a > 8 else 0)
    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0)  # L8
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(mask_raw), 9)) + chunk(b"IEND", b"")
    dst_mask.parent.mkdir(parents=True, exist_ok=True)
    dst_mask.write_bytes(png)
    return w, h


def pack(data_dir: Path) -> Path:
    """Write ns/images, ns/masks, ns/colmap/sparse/0. Returns ns/."""
    tf = json.loads((data_dir / "transforms.json").read_text())
    angle = float(tf["camera_angle_x"])
    frames = tf["frames"]
    ns = data_dir / "ns"
    img_out = ns / "images"
    mask_out = ns / "masks"
    colmap = ns / "colmap" / "sparse" / "0"
    img_out.mkdir(parents=True, exist_ok=True)
    mask_out.mkdir(parents=True, exist_ok=True)
    colmap.mkdir(parents=True, exist_ok=True)

    width = height = None
    names = []
    for i, fr in enumerate(frames):
        rel = fr["file_path"]
        src = data_dir / (rel + ".png" if not rel.endswith(".png") else rel)
        if not src.exists():
            src = data_dir / "images" / f"{i:04d}.png"
        name = f"{i:04d}.png"
        shutil.copy2(src, img_out / name)
        w, h = png_size_and_mask(src, mask_out / name)
        width, height = w, h
        names.append((name, fr["transform_matrix"]))

    f = focal_px(width, angle)
    (colmap / "cameras.txt").write_text(
        "# CAMERA_ID, MODEL, WIDTH, HEIGHT, PARAMS[]\n"
        f"1 SIMPLE_PINHOLE {width} {height} {f:.6f} {width * 0.5:.4f} {height * 0.5:.4f}\n"
    )
    img_lines = ["# IMAGE_ID QW QX QY QZ TX TY TZ CAMERA_ID NAME"]
    for i, (name, c2w) in enumerate(names, start=1):
        Rp, tp = opengl_c2w_to_colmap(c2w)
        qw, qx, qy, qz = mat3_to_quat_wxyz(Rp)
        img_lines.append(
            f"{i} {qw:.8f} {qx:.8f} {qy:.8f} {qz:.8f} {tp[0]:.8f} {tp[1]:.8f} {tp[2]:.8f} 1 {name}"
        )
        img_lines.append("")  # empty POINTS2D
    (colmap / "images.txt").write_text("\n".join(img_lines) + "\n")

    pts = read_ply_xyz(data_dir / "points3D.ply")
    pt_lines = ["# POINT3D_ID X Y Z R G B ERROR"]
    for i, p in enumerate(pts, start=1):
        pt_lines.append(f"{i} {p[0]:.6f} {p[1]:.6f} {p[2]:.6f} 128 128 128 1")
    (colmap / "points3D.txt").write_text("\n".join(pt_lines) + "\n")
    return ns


def _which(name: str) -> str | None:
    return shutil.which(name)


def train(ns: Path, out_ply: Path, iters: int) -> int:
    if _which("ns-train") is None:
        print(
            "train_cloud: ns-train not found.\n"
            "This step is CUDA-only. See tools/pipeline/train/versions.lock\n"
            "and tools/pipeline/README.md (CUDA half). No Mac CPU fallback.",
            file=sys.stderr,
        )
        return 2
    out_ply.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        "ns-train", "splatfacto",
        "--max-num-iterations", str(iters),
        "--pipeline.model.cull_alpha_thresh", "0.05",
        "--pipeline.model.use_scale_regularization", "True",
        "--pipeline.model.max-gauss-ratio", "8.0",
        "--vis", "none",
        "--data", str(ns),
        "colmap", "--masks-path", "masks",
    ]
    print("train_cloud:", " ".join(cmd))
    r = subprocess.run(cmd)
    if r.returncode != 0:
        return r.returncode
    # Export is left to the operator when a config exists; record the dest.
    print(f"train_cloud: export with ns-export gaussian-splat --output-dir {out_ply.parent}")
    return 0


def parse_args(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--data", required=True, help="cone-render output directory")
    p.add_argument("--out", default="assets/clouds/tree_hero.ply")
    p.add_argument("--budget", type=int, default=600)
    p.add_argument("--iters", type=int, default=7000)
    p.add_argument("--pack-only", action="store_true")
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    ns = pack(Path(args.data))
    print(f"train_cloud: packed {ns}")
    if args.pack_only:
        return 0
    return train(ns, Path(args.out), args.iters)


def _transpose(R):
    return [[R[c][r] for c in range(3)] for r in range(3)]


def _mul_mat_vec(R, v):
    return (
        R[0][0] * v[0] + R[0][1] * v[1] + R[0][2] * v[2],
        R[1][0] * v[0] + R[1][1] * v[1] + R[1][2] * v[2],
        R[2][0] * v[0] + R[2][1] * v[1] + R[2][2] * v[2],
    )


if __name__ == "__main__":
    raise SystemExit(main())
