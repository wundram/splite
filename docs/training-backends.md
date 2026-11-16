# Training hosts

The user has an M4 Mac mini with 48 GB RAM. Native training is a credible
candidate, not forbidden as the original CUDA-only design assumed. The current
repo implements the CUDA/Colab handoff; native MLX training has not been added
or benchmarked. No connection to the mini has been established in this task.

## First reference backend: Colab / Nerfstudio

`tools/pipeline/train/colab.ipynb` packages the existing known-pose capture path
for a GPU runtime. Candidate versions are Nerfstudio 1.1.5 / gsplat 1.4.0,
matching [upstream dependencies](https://github.com/nerfstudio-project/nerfstudio/blob/v1.1.5/pyproject.toml).
Installation and `ns-train splatfacto --help` passed on the user's existing T4
runtime (2026.07, Python 3.12.13). The first CUDA renderer build stalled after starting ten compiler workers;
subsequent smoke checks use two workers. Memory pressure is suspected, not
confirmed. After recovery, the two-worker build completed and real CUDA forward/backward
passed. A real 1,000-step calibration fit, held-out evaluation, PLY export and
Godot import also passed. Its PSNR21.3/SSIM.887 establish pipeline function,
not production quality. The full exported cloud agrees with Godot at PSNR34.6
in the first matching camera. See `tools/pipeline/train/validation/calibration`.
Nerfstudio requires `--vis tensorboard`; evaluation/export of our newly generated
checkpoint needs a scoped PyTorch weights-only compatibility setting. Small
captures now train at full resolution rather than the default quarter resolution.
No additional runtime was provisioned by this task.

## Native candidates to benchmark on the mini

- [RobotFlow-Labs/gsplat-mlx](https://github.com/RobotFlow-Labs/gsplat-mlx): MLX
  rasterizer and training components. Its README describes a Python loop in
  the rasterization path and a planned faster Metal implementation. Good
  reference candidate; do not extrapolate its tiny-image benchmarks to final
  capture resolution.
- [ghif/splat-apple](https://github.com/ghif/splat-apple): MLX training CLI and a
  native Metal extension. Publisher reports M4 measurements. Verify gradient
  correctness, COLMAP text support, export/color conventions and licensing
  before adoption; its performance claims have not been reproduced here.

Use the identical asymmetric colored calibration object, then a tree and
player idle. Start at 256 pixels, 64 views and a small population. Measure
held-out RGB/silhouette error, wall time, peak memory, export parity and Godot
appearance. Pin the exact repository revision of whichever backend passes.
Do not build a new differentiable rasterizer until these options are tested.

Both backends must preserve the capture's meter scale/Y-up frame, support
geometry seeding and view-independent color, export log-scales/logit-opacity
plus wxyz quaternions, and keep held-out views out of optimization. Shared
capture/import code is the backend boundary.

## Remaining quality work

Splatfacto can densify well beyond the runtime budget. `refine_budget.py` now
ranks compositing contributions, refits a fixed population and evaluates held-out
RGB, foreground and alpha error. A matching normal-map capture supervises learned
surface direction for relighting. Tree and Ranger passed this sequence at 8,000
and 3,000 Gaussians; see their reports under `assets/clouds/garden`.
Remaining work includes broader relighting acceptance, sorting across multiple
assets, explicit refinement checkpoint resume, animated clouds with shared
normalization and cross-frame stability, and larger-scene performance.

## Colab CLI connection

The saved CLI authorization works. CLI 0.6.0 needs
`jupyter-kernel-client==0.15.0`: version 1.0.2 renamed `KernelClient` and
breaks CLI execution before it reaches Colab. Use:

```sh
uv tool run --python 3.13 --from google-colab-cli==0.6.0 --with jupyter-kernel-client==0.15.0 colab sessions
```

`colab sessions` lists backend runtimes, while `colab exec` uses locally named
sessions. The existing browser runtime was attached through the CLI's state
API in a private temporary configuration, without allocating another GPU.
Session proxy credentials expire; refresh attachment when necessary and never
commit the configuration or tokens. A new chat can verify saved login with
`colab sessions`; login need not be repeated while credentials remain valid.
