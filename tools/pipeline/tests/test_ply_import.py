#!/usr/bin/env python3
"""PR11c: PLY → tres drops SH rest, treats f_dc as albedo, respects budget."""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "pipeline" / "import"))

import ply_to_cloud  # noqa: E402


def _fail(msg: str) -> None:
    raise SystemExit(f"test_ply_import: FAIL {msg}")


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        ply = Path(td) / "cloud.ply"
        tres = Path(td) / "cloud.tres"
        rc = ply_to_cloud.main([
            "--write-fixture-ply", "--ply", str(ply), "--out", str(tres),
            "--budget", "40", "--kind", "volume", "--id", "tree_hero",
        ])
        if rc != 0:
            _fail(f"exit {rc}")
        text = tres.read_text()
        if "script_class=\"SplatCloud\"" not in text:
            _fail("not a SplatCloud tres")
        if "source_id = \"tree_hero\"" not in text:
            _fail("source_id")
        # radii line should have at most 40 numbers
        for line in text.splitlines():
            if line.startswith("radii"):
                n = line.count(",") + 1
                if n > 40:
                    _fail(f"budget {n} > 40")
        names, rows = ply_to_cloud.read_ply_vertices(ply)
        if "f_dc_0" not in names:
            _fail("fixture missing f_dc")
        gs = ply_to_cloud.convert(names, rows, 600, "volume")
        if not gs:
            _fail("no gaussians")
        if not all(0.0 <= g["c"][i] <= 1.0 for g in gs for i in range(3)):
            _fail("albedo out of range")
        if any(g["a"] < 0.04 for g in gs):
            _fail("kept low alpha")
    print("test_ply_import: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
