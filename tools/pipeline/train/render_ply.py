#!/usr/bin/env python3
"""Render an exported Gaussian PLY through capture cameras using gsplat/CUDA.

This isolates exporter/importer/runtime differences from fitting quality.
"""
import argparse
import json
import math
import os
from pathlib import Path

os.environ.setdefault('MAX_JOBS', '2')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ply', required=True)
    parser.add_argument('--transforms', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--size', type=int, default=256)
    parser.add_argument('--frames', default='0,9,18,27')
    args = parser.parse_args()
    import numpy as np
    import torch
    from PIL import Image
    from plyfile import PlyData
    from gsplat import rasterization

    vertices = PlyData.read(args.ply)['vertex'].data
    def tensor(names):
        return torch.as_tensor(np.stack([vertices[n] for n in names], -1),
                               dtype=torch.float32, device='cuda').contiguous()
    means = tensor(['x', 'y', 'z'])
    quats = torch.nn.functional.normalize(tensor([f'rot_{i}' for i in range(4)]), dim=-1)
    scales = tensor([f'scale_{i}' for i in range(3)]).exp()
    colors = (tensor([f'f_dc_{i}' for i in range(3)]) * 0.28209479177387814 + .5).clamp(0, 1)
    opacities = tensor(['opacity']).squeeze(-1).sigmoid()
    transforms = json.loads(Path(args.transforms).read_text())
    size = args.size
    focal = size / (2 * math.tan(transforms['camera_angle_x'] / 2))
    K = torch.tensor([[focal, 0, size/2], [0, focal, size/2], [0, 0, 1]], device='cuda')[None]
    output = Path(args.out)
    output.mkdir(parents=True, exist_ok=True)
    with torch.no_grad():
        for index in map(int, args.frames.split(',')):
            c2w = torch.tensor(transforms['frames'][index]['transform_matrix'], device='cuda')
            # Capture/Godot uses camera -Z forward, +Y up; gsplat uses +Z, -Y.
            c2w[:, 1:3] *= -1
            rgb, alpha, _ = rasterization(means, quats, scales, opacities, colors,
                torch.linalg.inv(c2w)[None], K, size, size,
                backgrounds=torch.zeros((1, 3), device='cuda'), packed=False)
            pixels = (rgb[0].clamp(0, 1).cpu().numpy() * 255).round().astype(np.uint8)
            Image.fromarray(pixels).save(output / f'{index:04d}.png')
    print(f'render_ply: {len(vertices)} Gaussians, frames {args.frames} -> {output}')


if __name__ == '__main__':
    main()
