#!/usr/bin/env python3
"""Visibility-ranked reduction followed by fixed-population CUDA refinement.

Uses training views only for ranking/optimization. Reports held-out quality
before/after, including alpha error, and retains the source PLY unchanged.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import time

os.environ.setdefault('MAX_JOBS', '2')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ply', required=True)
    parser.add_argument('--data', required=True)
    parser.add_argument('--out', required=True)
    parser.add_argument('--budget', required=True, type=int)
    parser.add_argument('--steps', default=1500, type=int)
    parser.add_argument('--normals', help='Optional matching world-normal capture directory')
    args = parser.parse_args()
    if args.budget < 1 or args.steps < 1:
        parser.error('budget and steps must be positive')
    output = Path(args.out)
    output.mkdir(parents=True, exist_ok=False)
    import numpy as np
    import torch
    from PIL import Image
    from plyfile import PlyData, PlyElement
    from gsplat import rasterization
    from torchmetrics.functional.image import structural_similarity_index_measure as ssim

    torch.manual_seed(42)
    started = time.monotonic()
    data = Path(args.data)
    tf = json.loads((data / 'transforms.json').read_text())
    vertices = PlyData.read(args.ply)['vertex'].data
    def tensor(names):
        return torch.as_tensor(np.stack([vertices[n] for n in names], -1),
                               dtype=torch.float32, device='cuda').contiguous()
    values = {
        'means': tensor(['x', 'y', 'z']),
        'quats': tensor([f'rot_{i}' for i in range(4)]),
        'scales': tensor([f'scale_{i}' for i in range(3)]),
        'opacity': tensor(['opacity']).squeeze(-1),
        'color': torch.logit((tensor([f'f_dc_{i}' for i in range(3)]) * .28209479177387814 + .5).clamp(.0001, .9999)),
    }
    normal_targets = []
    if args.normals:
        normal_data = Path(args.normals)
        assert json.loads((normal_data/'transforms.json').read_text()) == tf, 'Normal cameras must match color capture'
        quats = torch.nn.functional.normalize(values['quats'], dim=-1)
        axis = torch.nn.functional.one_hot(values['scales'].argmin(-1), 3).float()
        cross = torch.linalg.cross(quats[:, 1:], axis)
        values['normal'] = axis + 2*(quats[:, :1]*cross + torch.linalg.cross(quats[:, 1:], cross))
    images, masks, views = [], [], []
    for frame in tf['frames']:
        path = (data / frame['file_path']).with_suffix('.png')
        rgba = np.asarray(Image.open(path).convert('RGBA'), dtype=np.float32) / 255
        images.append(torch.from_numpy(rgba[:, :, :3] * rgba[:, :, 3:4]).cuda())
        masks.append(torch.from_numpy(rgba[:, :, 3:4]).cuda())
        if args.normals:
            normal_rgba = np.asarray(Image.open((normal_data/frame['file_path']).with_suffix('.png')).convert('RGBA'), dtype=np.float32)/255
            normal_targets.append(torch.from_numpy(normal_rgba[:, :, :3]*normal_rgba[:, :, 3:4]).cuda())
        c2w = torch.tensor(frame['transform_matrix'], device='cuda')
        c2w[:, 1:3] *= -1
        views.append(torch.linalg.inv(c2w)[None])
    height, width = images[0].shape[:2]
    assert all(im.shape == images[0].shape for im in images)
    focal = width / (2 * math.tan(tf['camera_angle_x'] / 2))
    K = torch.tensor([[focal, 0, width/2], [0, focal, height/2], [0, 0, 1]], device='cuda')[None]
    training = [i for i in range(len(images)) if i % 9 != 0]
    held_out = [i for i in range(len(images)) if i % 9 == 0]
    assert training and held_out

    def render(params, index, colors=None):
        if colors is None:
            colors = params['color'].sigmoid()
            if args.normals:
                normal = torch.nn.functional.normalize(params['normal'], dim=-1)
                camera_pos = torch.linalg.inv(views[index])[0, :3, 3]
                facing = ((normal*(camera_pos-params['means'])).sum(-1, keepdim=True)>=0).float()*2-1
                colors = torch.cat([colors, (normal*facing+1)*.5], dim=-1)
        rgb, alpha, _ = rasterization(params['means'],
            torch.nn.functional.normalize(params['quats'], dim=-1), params['scales'].exp(),
            params['opacity'].sigmoid(), colors,
            views[index], K, width, height, backgrounds=torch.zeros((1, colors.shape[-1]), device='cuda'), packed=False)
        return rgb[0, :, :, :3], alpha[0], rgb[0, :, :, 3:]

    def evaluate(params, name):
        scores = []
        directory = output / name
        directory.mkdir()
        with torch.no_grad():
            for index in held_out:
                rgb, alpha, normal_rgb = render(params, index)
                mse = (rgb - images[index]).square().mean()
                foreground = masks[index].expand_as(rgb) > .05
                scores.append({'frame': index, 'psnr': float(-10 * torch.log10(mse.clamp_min(1e-12))),
                    'foreground_mae': float((rgb-images[index]).abs()[foreground].mean()),
                    'alpha_mae': float((alpha-masks[index]).abs().mean()),
                    'ssim': float(ssim(rgb.permute(2, 0, 1)[None], images[index].permute(2, 0, 1)[None], data_range=1.0))})
                if args.normals:
                    scores[-1]['normal_mae'] = float((normal_rgb-normal_targets[index]).abs().mean())
                Image.fromarray((rgb.clamp(0, 1).cpu().numpy()*255).round().astype(np.uint8)).save(directory/f'{index:04d}.png')
        return {'frames': scores, 'mean': {key: sum(s[key] for s in scores)/len(scores)
                for key in scores[0] if key != 'frame'}}

    report = {'source_sha256': hashlib.sha256(Path(args.ply).read_bytes()).hexdigest(),
              'input_count': len(vertices), 'budget': min(args.budget, len(vertices)),
              'steps': args.steps, 'training_frames': training, 'held_out_frames': held_out,
              'selection': 'summed alpha/transmittance contribution over training views',
              'versions': {'torch': str(torch.__version__)},
              'capture_recipe': json.loads((data/'recipe.json').read_text()),
              'normal_supervision': bool(args.normals), 'random_seed': 42}
    report['full'] = evaluate(values, 'full')
    # d(sum RGB)/d(color_i) integrates the actual composited contribution of
    # Gaussian i, including occlusion. Geometry and opacity remain detached.
    scores = torch.zeros(len(vertices), device='cuda')
    for index in training:
        probe = torch.ones((len(vertices), 3), device='cuda', requires_grad=True)
        rgb, _, _ = render(values, index, probe)
        rgb.sum().backward()
        scores += probe.grad.sum(-1).detach()
    keep = torch.topk(scores, report['budget'], sorted=False).indices
    params = {name: torch.nn.Parameter(value[keep].clone()) for name, value in values.items()}
    report['selected'] = evaluate(params, 'selected')
    rates = {'means': .00008, 'quats': .001, 'scales': .003, 'opacity': .02, 'color': .0025, 'normal': .005}
    optimizer = torch.optim.Adam([{'params': [p], 'lr': rates[name]} for name, p in params.items()], eps=1e-15)
    for step in range(args.steps):
        index = training[int(torch.randint(len(training), ()).item())]
        rgb, alpha, normal_rgb = render(params, index)
        target = images[index]
        structural = ssim(rgb.permute(2, 0, 1)[None], target.permute(2, 0, 1)[None], data_range=1.0)
        loss = .8*(rgb-target).abs().mean() + .2*(1-structural) + .05*(alpha-masks[index]).abs().mean()
        if args.normals:
            loss = loss + .3*(normal_rgb-normal_targets[index]).abs().mean()
        if not torch.isfinite(loss):
            raise RuntimeError(f'Non-finite loss at step {step}')
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        optimizer.step()
        if (step+1) % 100 == 0:
            print(f'refine_budget: {step+1}/{args.steps} loss={float(loss.detach()):.6f}', flush=True)
        if (step+1) % 500 == 0 or step+1 == args.steps:
            torch.save({'step': step+1, 'parameters': {k: v.detach() for k, v in params.items()},
                        'optimizer': optimizer.state_dict(), 'report': report}, output/'checkpoint.pt')
    report['refined'] = evaluate(params, 'refined')
    if not all(torch.isfinite(value).all() for value in params.values()):
        raise RuntimeError('Non-finite refined parameters')
    if args.normals:
        (output/'normals.json').write_text(json.dumps(torch.nn.functional.normalize(params['normal'], dim=-1).detach().cpu().tolist()))
    fields = ['x', 'y', 'z'] + [f'f_dc_{i}' for i in range(3)] + ['opacity'] + [f'scale_{i}' for i in range(3)] + [f'rot_{i}' for i in range(4)]
    arrays = [params['means'], (params['color'].sigmoid()-.5)/.28209479177387814,
              params['opacity'][:, None], params['scales'], torch.nn.functional.normalize(params['quats'], dim=-1)]
    matrix = torch.cat(arrays, dim=-1).detach().cpu().numpy()
    records = np.empty(len(matrix), dtype=[(name, '<f4') for name in fields])
    for index, name in enumerate(fields):
        records[name] = matrix[:, index]
    PlyData([PlyElement.describe(records, 'vertex')], text=False).write(str(output/'refined.ply'))
    report['elapsed_seconds'] = time.monotonic()-started
    (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({name: report[name]['mean'] for name in ('full', 'selected', 'refined')}, indent=2))


if __name__ == '__main__':
    main()
