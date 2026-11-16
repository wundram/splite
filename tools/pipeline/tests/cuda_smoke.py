"""Check the real gsplat CUDA forward/backward path without a source dataset."""
import os

# Limit first-build RAM use on small Colab hosts.
os.environ.setdefault('MAX_JOBS', '2')

import torch
from gsplat import rasterization


def main():
    assert torch.cuda.is_available(), 'CUDA unavailable'
    device = 'cuda'
    means = torch.tensor([[0.0, 0.0, 3.0], [0.2, 0.1, 3.2]], device=device, requires_grad=True)
    quats = torch.tensor([[1., 0., 0., 0.]] * 2, device=device, requires_grad=True)
    scales = torch.full((2, 3), 0.15, device=device, requires_grad=True)
    opacity = torch.full((2,), 0.8, device=device, requires_grad=True)
    colors = torch.tensor([[0.8, 0.2, 0.1], [0.1, 0.7, 0.3]], device=device, requires_grad=True)
    view = torch.eye(4, device=device)[None]
    intrinsics = torch.tensor([[[40., 0., 16.], [0., 40., 16.], [0., 0., 1.]]], device=device)
    rgb, alpha, _ = rasterization(means, quats, scales, opacity, colors, view, intrinsics,
                                  width=32, height=32, packed=False, sh_degree=None)
    loss = rgb.square().mean() + alpha.mean()
    loss.backward()
    torch.cuda.synchronize()
    assert torch.isfinite(rgb).all() and alpha.max() > 0
    for name, parameter in [('means', means), ('quats', quats), ('scales', scales), ('opacity', opacity), ('colors', colors)]:
        assert parameter.grad is not None and torch.isfinite(parameter.grad).all(), name
    assert colors.grad.abs().sum() > 0 and scales.grad.abs().sum() > 0
    print('PASS: gsplat CUDA forward/backward on', torch.cuda.get_device_name(0))


if __name__ == '__main__':
    main()
