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
import os
import shutil
import subprocess
import sys
import tempfile
import importlib.metadata
import hashlib
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
    from PIL import Image
    with Image.open(src) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        dst_mask.parent.mkdir(parents=True, exist_ok=True)
        alpha.point(lambda a: 255 if a > 8 else 0).save(dst_mask)
        return rgba.size


def pack(data_dir: Path) -> Path:
    """Write ns/images, ns/masks, ns/colmap/sparse/0. Returns ns/."""
    tf = json.loads((data_dir / "transforms.json").read_text())
    angle = float(tf["camera_angle_x"])
    frames = tf["frames"]
    if not frames:
        raise ValueError("Capture has no frames")
    if not 0 < angle < math.pi:
        raise ValueError("Invalid camera angle")
    ns = data_dir / "ns"
    img_out = ns / "images"
    mask_out = ns / "masks"
    colmap = ns / "colmap" / "sparse" / "0"
    if ns.exists():
        raise ValueError(f"Pack destination already exists; use a fresh capture directory: {ns}")
    img_out.mkdir(parents=True, exist_ok=True)
    mask_out.mkdir(parents=True, exist_ok=True)
    colmap.mkdir(parents=True, exist_ok=True)

    width = height = None
    names = []
    for i, fr in enumerate(frames):
        rel = fr["file_path"]
        src = data_dir / (rel + ".png" if not rel.endswith(".png") else rel)
        name = f"{i:04d}.png"
        from PIL import Image
        with Image.open(src) as image:
            rgba = image.convert("RGBA")
            # Full-image loss against black supervises empty space too. A
            # foreground-only mask would leave floaters unconstrained.
            background = Image.new("RGBA", rgba.size, (0, 0, 0, 255))
            Image.alpha_composite(background, rgba).convert("RGB").save(img_out / name)
        w, h = png_size_and_mask(src, mask_out / name)
        if width is not None and (w, h) != (width, height):
            raise ValueError("Capture images must have identical dimensions")
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


def training_command(ns: Path, run_dir: Path, iters: int):
    return [
        "ns-train", "splatfacto", "--max-num-iterations", str(iters),
        "--output-dir", str(run_dir), "--experiment-name", "splite",
        "--timestamp", "fit", "--vis", "tensorboard", "--viewer.quit-on-train-completion", "True",
        "--steps-per-save", "500",
        "--pipeline.model.cull-alpha-thresh", "0.05",
        "--pipeline.model.use-scale-regularization", "True",
        "--pipeline.model.max-gauss-ratio", "8.0",
        "--pipeline.model.sh-degree", "0",
        "--pipeline.model.num-downscales", "0",
        "--pipeline.model.background-color", "black",
        "--pipeline.model.camera-optimizer.mode", "off",
        "--data", str(ns.resolve()), "colmap",
        "--orientation-method", "none", "--center-method", "none",
        "--auto-scale-poses", "False", "--assume-colmap-world-coordinate-convention", "False",
        "--downscale-factor", "1", "--eval-mode", "interval", "--eval-interval", "9",
    ]


def train(ns: Path, out_ply: Path, iters: int, budget: int = 600) -> int:
    if any(_which(tool) is None for tool in ("ns-train", "ns-export", "ns-eval")):
        print("train_cloud: install the CUDA environment in train/colab.ipynb; ns-train/ns-export/ns-eval required", file=sys.stderr)
        return 2
    if any(path.exists() for path in (out_ply, out_ply.with_suffix(".tres"), out_ply.with_suffix(".full.tres"))):
        raise ValueError("Output already exists; choose a new output name")
    out_ply = out_ply.resolve()
    out_ply.parent.mkdir(parents=True, exist_ok=True)
    run_dir = Path(tempfile.mkdtemp(prefix=out_ply.stem + "-", dir=out_ply.parent))
    manifest = {"status": "started", "iterations": iters, "import_budget": budget,
                "versions": {name: importlib.metadata.version(name) for name in ("nerfstudio", "torch", "gsplat")},
                "capture": json.loads((ns.parent / "recipe.json").read_text())}
    report = run_dir / "run.json"
    report.write_text(json.dumps(manifest, indent=2) + "\n")
    cmd = training_command(ns, run_dir, iters)
    manifest["train_command"] = cmd
    def run(command):
        print("train_cloud:", " ".join(command), flush=True)
        # Nerfstudio 1.1.5 checkpoints include NumPy optimizer scalars. PyTorch
        # 2.6+ weights-only defaults reject these. Only these child commands read
        # the checkpoint produced by this invocation; never set this globally.
        kwargs = {}
        if command[0] in ("ns-eval", "ns-export"):
            kwargs["env"] = {**os.environ, "TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD": "1"}
        result = subprocess.run(command, **kwargs)
        if result.returncode:
            manifest.update(status="failed", failed_command=command, returncode=result.returncode)
            report.write_text(json.dumps(manifest, indent=2) + "\n")
        return result.returncode
    rc = run(cmd)
    if rc:
        return rc
    config = run_dir / "splite" / "splatfacto" / "fit" / "config.yml"
    if not config.is_file():
        raise RuntimeError(f"Training returned success without expected config: {config}")
    rc = run(["ns-eval", "--load-config", str(config), "--output-path", str(run_dir / "eval.json")])
    if rc:
        return rc
    exported = run_dir / "export"
    rc = run(["ns-export", "gaussian-splat", "--load-config", str(config), "--output-dir", str(exported)])
    if rc:
        return rc
    ply = exported / "splat.ply"
    if not ply.is_file() or ply.stat().st_size == 0:
        raise RuntimeError("Exporter returned success without splat.ply")
    importer = Path(__file__).resolve().parents[1] / "import" / "ply_to_cloud.py"
    rc = run([sys.executable, str(importer), "--ply", str(ply),
              "--out", str(out_ply.with_suffix(".full.tres")), "--reference", "--id", out_ply.stem])
    if rc:
        return rc
    rc = run([sys.executable, str(importer), "--ply", str(ply), "--out", str(out_ply.with_suffix(".tres")),
              "--budget", str(budget), "--recipe", str(ns.parent / "recipe.json"), "--id", out_ply.stem])
    if rc:
        return rc
    shutil.copy2(ply, out_ply)
    manifest.update(status="complete", output=str(out_ply), full_cloud=str(out_ply.with_suffix(".full.tres")),
                    ply_sha256=hashlib.sha256(out_ply.read_bytes()).hexdigest())
    report.write_text(json.dumps(manifest, indent=2) + "\n")
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
    if args.iters < 1 or args.budget < 1:
        raise ValueError("iters and budget must be positive")
    data = Path(args.data).resolve()
    recipe = json.loads((data / "recipe.json").read_text())
    if recipe.get("color_mode") == "world-normal-encoded-raw":
        raise ValueError("Normal captures are auxiliary data; pass them to refine_budget.py --normals, not color training")
    if not args.pack_only and (recipe.get("source") == "builtin:cube" or recipe.get("blender_hash") == "fixture-cube"):
        raise ValueError("Synthetic fixture images are not a trainable multi-view capture")
    ns = pack(data)
    print(f"train_cloud: packed {ns}")
    if args.pack_only:
        return 0
    return train(ns, Path(args.out), args.iters, args.budget)


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
