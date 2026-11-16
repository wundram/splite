# Work log

## 2026-09-06 — Colab connection and GPU validation

Harness: Codex desktop; model: GPT-6 (developer session metadata), exact
variant unknown. No earlier harness baseline exists. Starting revision
`5685f5b`; substantial uncommitted revival changes already present and preserved.

Saved Colab CLI authentication and remote Python execution succeeded on the
user's existing T4. Python 3.12.13, torch 2.11.0+cu128, Nerfstudio 1.1.5,
gsplat 1.4.0, numpy 1.26.4. Installation, GPU detection, `nvcc --version`
and `ns-train splatfacto --help` passed. CLI 0.6.0 requires the older
jupyter-kernel-client 0.15.0 API; 1.0.2 fails before remote execution.

The real CUDA forward/backward smoke test started compiling with the upstream
default of ten workers, then stopped producing output. Colab displayed
10.91/12.67 GB host RAM use. Kernel status requests with fresh proxy credentials
and an interrupt request timed out. The CLI test ultimately hit its
600-second timeout; remote compiler termination was not confirmed. Memory pressure is a hypothesis; no
compiler failure or OOM report was recovered. GPU gradients and full fitting
remain unverified. No new VM was allocated.

Added the smoke test to the repo notebook and limited subsequent compilation
to two workers. All notebook code cells parse; embedded test matches its source;
Python syntax check passed. Updated backend/CLI setup notes.

Next experiment: recover the existing runtime, verify no old compiler is still
running, then rerun the two-worker GPU smoke test and a short real capture fit.
The browser notebook has the successful setup cells; the new smoke-test cell
is in the local notebook. Saved CLI auth does not need repeating.

## 2026-09-06 — AI engineering team operating-model research

Researched shared agent services versus engineer-owned persistent agent profiles.
Revision remains `5685f5b`; pre-existing application changes preserved. No known
harness/model change from the recorded baseline. No application code changed.

Verified current Claude Code memory and Kiro custom-agent documentation; reviewed
Anthropic's managed-agent architecture, DORA platform research, context-file
study abstracts, and METR's February 2026 productivity update. Sources support
layered configuration and replaceable execution environments; they do not
establish that personal agents outperform shared services. Context-file results
are mixed; accumulated memory is not demonstrated monotonic improvement.

Recommendation for discussion, not an accepted implementation decision: shared
infrastructure and enforcement, engineer-owned profiles, portable specialist
packages, and measured promotion of successful experiments. Next experiment:
compare common and personalized profiles on representative work, accounting for
review/rework and maintenance, then test transfer to another engineer.

Key sources: [Claude memory](https://code.claude.com/docs/en/memory),
[managed agents](https://www.anthropic.com/engineering/managed-agents),
[context evaluation](https://arxiv.org/abs/2602.11988),
[METR update](https://metr.org/blog/2026-02-24-uplift-update/).

Follow-up research on craftsmanship: the IUI 2026
[ownership experiment](https://doi.org/10.1145/3742413.3789121) reports declining
felt ownership with greater AI contribution while production accountability
remained stable. A [developer field study](https://arxiv.org/abs/2512.14012)
describes active expert control of agents. Neither directly tests personal
versus shared agent hosting. Extend the proposed pilot to measure perceived
agency, system understanding, and ownership alongside delivery outcomes;
separate attachment to a customized agent from verified quality improvements.

### Recovery follow-up

User reconnected/restarted and confirmed notebook execution. Colab assigned a
fresh T4 with Python 3.12.13; Nerfstudio was absent. Reattached the CLI and
reinstalled the candidate stack successfully. Retried the GPU smoke test in
a separate process with a saved log and MAX_JOBS=2. Two CUDA compiler workers
were observed using about 3 GB each; kernel checks stayed responsive. Build
targets only compute_75/sm_75 (T4), with 24 CUDA files and one C++ file.
The build completed all 25 objects and the real CUDA forward/backward test
passed (exit 0). A fresh-process cached rerun passed in 4.2 seconds. Trainer
CLI startup also passed; nvcc reports 12.8.93. Exact environment and passing
log are saved under `tools/pipeline/train/validation/t4/`. The first build
exceeded 30 minutes; do not mistake quiet compilation for a failed kernel.
Updated notebook and status docs to distinguish GPU smoke validation from a
full fit. Next: short fit on the real asymmetric Blender calibration capture,
then validate export/import and held-out views before fitting garden assets.

### Subsequent disconnect check

After the user saw a browser disconnect and clicked Reconnect, the CLI listed
a different T4 endpoint. Remote execution works, but the previous validation
files and gsplat installation are absent: the runtime was replaced, not merely
a browser connection loss. Cause of replacement is unknown. Prior GPU tests
completed successfully and their reports remain saved locally. No asset fit
was running. Reinstallation and extension rebuilding will be needed on this
fresh runtime; neither was launched during this read-only status check.

### Autonomous continuation and monitoring

Enabled five-minute thread heartbeat `check-splite-colab-training` as requested.
Current CLI configuration: `/tmp/splite-colab-session/sessions.json` (private,
never print credentials). Use uv Python 3.13, google-colab-cli==0.6.0,
jupyter-kernel-client==0.15.0; UV_CACHE_DIR=/tmp/splite-uv-cache.

Fresh runtime packages installed successfully. A 32-view/256px real calibration
capture and saved source model were created with `make_calibration.py` and
uploaded. Remote work root `/content/splite-calibration-v1`, job status
`job/status.json`, `phase.json`, log `job/output.log`. Launcher runs CUDA smoke,
archives its extension cache to `/content/splite-t4-torch211-cu128-cache.tar.gz`,
then runs a 1,000-step fit/eval/export/import. Success archive:
`/content/splite-calibration-results.zip`. Download both promptly when present.
Status script `/tmp/splite-colab-pipeline-status.py`; it uses files, not kernel
variables. `run_job.py` durably records exit status; local success/failure checks
passed. Remote job is currently building, not yet a validated asset fit.

### Source garden and fitted renderer groundwork

Acquired CC0 Quaternius Ultimate Stylized Nature and KayKit Adventurers Free 2.0;
exact download hashes and licenses are under assets/sources and linked from
assets/ATTRIBUTION.md. Universal Base Characters Standard was auditioned but
not selected. Source scripts select nature meshes, repair missing texture paths,
recolor foliage, pose KayKit characters, and export portable normalized GLBs.
Caught and fixed glTF's unsupported Hue/Saturation material export by baking
edited base colors; explicitly export the current character pose rather than
armature rest position. Large raw downloads/captures are ignored, with licenses
and manifests retained. Portable selected models total about 23 MB.

Added a separate playable source reference at demos/garden_study/garden_study.tscn:
locked camera/black void, sage tree and shrubs, flowers, stone path, pond/bridge,
Ranger, WASD movement. Native Metal screenshot captured and inspected. Character
pose now survives export. This remains a mesh source study, with overly dense
foliage and limited face visibility at the locked camera; not visual acceptance.

Added FittedSplatBatch + fitted_gaussian.gdshader as a separate reference path:
trained covariance projected into screen space, ellipsoid rotations/scales,
three-sigma footprint, per-Gaussian depth sort. Real Metal renderer smoke passed
with measured anisotropy ratio 98.98. Exact capture-camera screenshot script also
ran successfully against an existing fixture. Linear blending versus training's
encoded RGB blending and static/dynamic batch interleaving remain parity risks.
Importer --reference bypasses heuristic pruning/budget while retaining validity
checks. Seven host regression tests pass. Main game scene is unchanged.

Current Colab rebuild has reached 24/25 objects, remains responsive, ~7 GB memory
available. Calibration job still owns the GPU. Tree (32x384) and Ranger (32x384)
captures are ready; /tmp/splite-tree-v1.zip and /tmp/splite-ranger-v1.zip. Do not
launch competing trainers before calibration validation completes.

### First real fit completed; garden training launched

CUDA smoke completed after 25 objects. Cache (8,326,105 bytes) downloaded to
assets/training/cache with environment and SHA256 manifest. Calibration's first
trainer attempt rejected --vis none; changed to tensorboard. 1,000 steps then
finished, but ns-eval hit PyTorch 2.6+ weights-only loading of NumPy checkpoint
scalars. Scoped TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 only to child evaluation/export
of the checkpoint just created by our trainer. Recovered the existing checkpoint
without retraining. Evaluation/export/import completed successfully. Full archive
assets/training/calibration-results.zip is downloaded and extracted locally.

Held-out calibration: PSNR 21.3343, SSIM .88734, LPIPS .10208; 3,574 exported
Gaussians, 1,200 in reduced import. The first fit used Nerfstudio's default quarter
training resolution, explaining some visible silhouette error; future small-asset
runs explicitly use num_downscales=0. Exact camera0 gsplat→Godot full-reference
PSNR 34.594 dB; source→gsplat 21.157 dB. Visual alignment/colors agree; quality is
still inadequate in the short fit. Added render_ply.py for direct CUDA render of
exported PLY. Local seven regression tests pass, including scoped load setting.

ACTIVE JOB has moved to /content/splite-garden-v1 (launcher PID14407), status
job/status.json, phase.json, job/output.log. Sequential 4,000-step full-resolution
384px/32-view tree and Ranger fits, budgets2400/1600, saveevery500. Each asset is
evaluated/exported/imported/rendered before next, then archived to
/content/splite-tree-results.zip or /content/splite-ranger-results.zip.
Download each as soon as available. Existing /tmp/splite-colab-pipeline-status.py
now points to this garden job. Calibration root remains for evidence/recovery.

### Budget refinement active

Both 4,000-step fits completed. Tree full cloud26,957, held-out PSNR31.425,
SSIM.96345; direct gsplat/Godot comparison visually preserves leaf silhouette.
Naive farthest-point 2400 reduction destroys coverage, so it is rejected for scene
use. Ranger full export12,945; its result archive is being downloaded.

ACTIVE GPU JOB: same /content/splite-garden-v1 root, now job-refine/status.json,
phase-refine.json, job-refine/output.log (launcher16859). New refine_budget.py
ranks actual integrated alpha/transmittance contributions across training views
using color gradients, selects8k tree/3k Ranger, and optimizes fixed populations
for1500steps against RGB/SSIM/alpha. Holds out every9th view for before/after
metrics. Experimental; not yet validated. Expected archives
/content/splite-tree-refined.zip and /content/splite-ranger-refined.zip.
Status script now follows this job. Full source clouds/checkpoints are preserved.

### Refinement passed; relighting experiment

Visibility-based fixed-budget refinement completed in ~50s for both assets.
Tree8k: PSNR30.323 vs31.425 full; Ranger3k: PSNR36.794 vs42.953 full.
Both archives downloaded and extracted; resources plus reports are under
assets/clouds/garden. Added fitted_garden.tscn using these genuine clouds.
Source-reference GLB textures capped1K, reducing selected-model footprint23MB→7.7MB.

Scene lighting exposed poor relighting despite good albedo scores. Added optional
Godot physical scene lighting to fitted shader (reference mode uses emission),
source mesh shadow proxies, evaluated-source nearest-surface normal transfer,
and conditional ellipsoid depth for shadow lookup. Reference anisotropy GPU test
still passes. Source-normal transfer alone yields visible lighting patches;
normal supervision is being tested rather than declaring visual acceptance.

ACTIVE GPU JOB: /content/splite-garden-v1/job-normals/status.json,
phase-normals.json, job-normals/output.log, launcher21331. Matching32x384 normal
captures created by cone_render --material-pass normals (raw Godot world-normal
encoding), exact camera matrices verified against color captures. Updated
refine_budget.py jointly refines color/alpha/normal features for2500steps at8k/3k.
Expected archives /content/splite-{tree,ranger}-normals-refined.zip. Monitor script
now follows this job. Prior accepted color fits remain saved unchanged in
assets/training/{tree,ranger}-refined.

User saw another disconnect: same T4 endpoint remained assigned. CLI proxy session
expired (401/404); reattached using fresh proxy info and verified all files and
completed jobs intact. This was connection loss, not VM replacement. User asked
to close disruptive Colab tabs; all3 Colab service tabs closed via CUA. Continue
CLI-first; notebook auth/runtime UI only when needed. No GPU work lost.

### Milestone result and handoff

Normal-supervised refinement completed successfully for both assets. Final tree
8,000: held-out PSNR30.829, SSIM.96095, normal MAE.02327 (from.05141).
Final Ranger3,000: PSNR38.475, SSIM.99001, normal MAE.00411 (from.01389).
Both archives/checkpoints/normal arrays downloaded under assets/training;
assets/clouds/garden contains final resources and updated provenance/report hashes.
The fitted scene now uses learned normals and Godot scene lighting; native image
inspection shows the worst prior lighting patches reduced. Still an art study:
soft/dense foliage, limited face visibility at the locked camera, static idle
pose rather than a walk clip, and source-mesh shadow proxies remain limitations.

Benchmark with moving/turning character:240frames at1280x800, M1 Pro/Metal,
Godot4.7.1:66.05FPS mean,15.14ms mean frame,15.927ms p95. Not an M4 measurement.
Nine host regression tests pass; final real GPU anisotropy/rotation smoke passes
(ratio98.98,7978pixels). git diff --check passes. Updated pipeline/backend guides,
README, attribution, validation screenshots/reports and RESUME. Training wrapper
now preserves an unpruned .full.tres before legacy budget reduction; normal-capture
misuse as albedo and invalid normal arrays are rejected.

All remote jobs completed and all results saved locally. Five-minute monitor
check-splite-colab-training is PAUSED until the next remote job. CLI configuration
remains private; browser service tabs are closed per user request. Native MLX and
an M4 connection remain unimplemented. Original main scene and pre-existing
uncommitted work are preserved; no commit or publication was requested.

Requested user feedback on developing this Ranger/sage-foliage family versus
an alternative family before expanding the trained catalog. Next concrete work:
resolve visual family choice, then shared-pose normalization and a short trained
walk cycle, broader foliage/ground assets, multi-asset sorting and larger-scene
performance. Do not mistake successful image metrics for final art acceptance.

## 2026-09-08 — Accepted family, coherent Ranger walk

User approved continuing Ranger/sage garden assets, noting washed-out colors.
No known model/harness change from prior baseline. Existing uncommitted work
preserved; no commit requested. Colab CLI reports no active assignments today;
all prior training results are local, so no runtime was allocated and the monitor
remains paused.

Added `bake_skinned_clip.py`: barycentric source mesh skin-weight transfer to the
normal-supervised 3,000-Gaussian idle fit; Walking_A bone deltas deform positions,
full covariance and learned normals with one shared capture normalization.
Ten frames retain color/opacity/index correspondence. Bake produced source hashes,
weights, frame bounds and exact posed source GLBs; assembler writes a Splite actor
resource. This is skeletal deformation of a trained cloud, not ten trained poses.
Nearest source transfer distance averages 6.9mm (maximum61.1mm).

Both garden studies now switch walk frames and matching source/shadow proxies on
WASD, returning to idle on release. Removed synthetic bob and a duplicate upload.
Small lawn/pond palette changes and saturation1.13/contrast1.04 affect the study
only; raw trained resources and training metrics are preserved.

Actual Blender bake succeeded. Godot4.7.1 Metal validation passes finite geometry,
positive scales, unit normals, persistent colors/opacity, loop continuity,
keyboard movement and idle reset. Source/fitted frame comparison visually agrees.
Loop point displacement6.1mm versus ordinary steps10.0–21.1mm. Final animated
240-frame benchmark at1280x800 on M1 Pro:65.68FPS,15.225ms mean,16.001ms p95.
Python compile and git diff --check pass. Artifacts, GIF and machine-readable
checks are in `tools/pipeline/train/validation/garden/walk/`.

Limitations: source-mesh shadows remain; joint deformation can stretch splats;
unseen idle surfaces cannot be recovered through skinning. Animated-pose held-out
render metrics are not yet measured. Next experiment: shared-camera source walk
captures for deformation quality, followed by fitted shrub/flower/rock tiles and
multi-asset sorting/performance. Main garden remains unchanged.

## 2026-09-08 — Larger terraced garden and scrolling performance

User requested the previous demo's scrolling, verticality, levels, indoor/outdoor
multi-state tiles and basic animations with the accepted assets. No known harness
or model change. Preserved pre-existing uncommitted work; no commit requested.

Added `demos/garden_expanded` and made it the default scene. Reuses original
SplatWorld, TileState/TileInteractable, room visibility, clock/lantern, hints and
navigation. Shared garden exposes stair_runs(), play host exposes create_garden();
original scenes and tour remain intact. New connected flights at x10 L0, x12 L1,
x2 L2 avoid the prior overlapping-flight layout. 292 cells across four elevations.
Fitted Ranger frame/shadow playback is separate from legacy procedural batch;
two real fitted trees plus CC0 mesh foliage/rocks dress the larger space.
Added paved terraces, planters, benches, rails, stairs, bridge boards and cellar
furniture. Door's existing sequence drives a visible hinged wood mesh while
walkability remains blocked until completion. Foam distortion, ember bob/rotation,
walking, night lantern and room-scoped visibility remain active. World hints use
full camera billboarding in this scene for near-top-down readability.

Initial moving-camera benchmark15.07FPS exposed unnecessary static cloud rebuilds.
SplatCameraRig now follows a smoothed focus with constant locked orientation;
FittedSplatBatch invalidates sorting/normals on basis changes, not translation,
and skips processing while hidden. Translation shifts all depths equally within
a batch. Final360-frame movement/two-flight benchmark:1280×800143.40FPS mean,
6.97ms mean/17.18ms p95;1920×1200123.62FPS mean,8.09ms mean/17.43ms p95.
Actual M1 Pro/Godot4.7.1 Metal measurements, not M4 or worst-case guarantees.

`test_expanded_garden.gd` passes full ascent/descent without teleportation, door
blocking/sequence/hinge angle, room entry/exit, ember pickup, lantern/night, idle
and camera-angle checks. Original actor/world/tour tests pass. Sandboxed initial
Godot tests crashed opening user logs before running; authorized reruns succeeded.
Real GPU anisotropy smoke and git diff --check pass. Six rendered checkpoints and
benchmark JSONs saved in `demos/garden_expanded/validation`.

No new training/runtime needed. Remaining limits: source meshes for scenery beyond
the fitted trees/player, separate batch sorting, decorative furniture lacks exact
colliders, and architecture needs a stronger art pass. Next: user play-through
of larger route, then expand the trained tile catalog/architectural assets.

## 2026-09-08 — Living garden, wildlife, magic and styled UI

User authorized a denser/larger garden, slopes, varied/tall trees, climbing roses,
maze, Lovecraftian statues, UI/compass/paper doll/help, reflective animated water,
particle/spatial-distortion spells and peaceful mobs. No known harness/model
change. Existing working-tree changes preserved; no commit requested.

Added default `demos/living_garden/garden.tscn`, preserving prior demos via
inheritance. Ground grows36×30;1148cells total. Added continuous grassy ramps,
34trees/five forms including10.38m pine, rose-wall TileDef with instanced vines
and blossoms, deterministic solvable maze, two authored tentacled statues and
an awakening shrine. Exported four extra CC0 Quaternius trees from local source
with source-object/hash manifests. Five broadleaf placements reuse trained8k
clouds; Ranger3k gives43k fitted Gaussians. Other new forms remain source or
procedural meshes, not new fits.

Added6rabbits/4birds/6koi with bounded ambient motion, reflection-probe water with
animated normals and lilies, and verdant/moonlight spells with GPU particles,
refraction, light/rings and distinct DistortionField modes. New SystemFont-based
HUD has compass, live3D Ranger view, discovery labels, map and key help. Space
no longer also triggers ui_accept. Help/map block movement. Ground is batched;
foliage materials are shared; tree bodies block occupied grid cells.

Integration test passes0failures: slope ascent/descent,40-step maze route through
real walkability, shrine/cooldowns/warp modes, tree count/height, wildlife, UI keys,
help movement suppression and indoor/outdoor visibility. Real renders inspected;
fixed missing ground under cut hedges, excessive highlights/tree saturation,
probe ambient lighting and first-frame portrait rendering. GIF/8checkpoints,
test log and benchmark JSON saved in `demos/living_garden/validation`.

Final1920×1200 M1 Pro/Godot4.7.1 Metal measured means:woodland47.95FPS,
pond/spell61.86FPS,maze76.22FPS (120frames/view; p95s22.52/21.43/20.88ms).
Earlier benchmarks had the older demo still running; closed our prior launch
before final measurements. git diff --check passes. Godot still reports7Texture
RIDs on shutdown despite explicit scene/cache cleanup; unresolved, not a failing
functional assertion. Water uses captured-probe reflections, not live planar
mirroring. Next: user play-through/art refinement, woodland GPU/LOD work, broader
trained assets, reflection-update behavior and shutdown-resource investigation.
No new Colab runtime/training was used; remote monitor remains paused.

## 2026-09-08 — Living Garden video capture

Added `tests/capture_living_tour.gd` and a 28-second, 1280×800, 24fps H.264
MP4 at `demos/living_garden/validation/living-garden-tour.mp4`. Six cuts cover
rabbits, a continuous woodland slope walk, maze, shrine pulse, rose walls and
pond/moonlight magic. Captured 672 PNG frames with Godot `--fixed-fps 24`, then
encoded with ffmpeg (CRF19, yuv420p, faststart); no audio track. Representative
frames visually inspected. Capture exits successfully with the previously known
7Texture-RID shutdown warning. This is fixed-step presentation footage, not a
real-time performance measurement. No gameplay changes or remote jobs. Next:
review the tour for scene composition and art improvements.

## 2026-11-16 — GitHub upload

Codex desktop / GPT-6 (developer-provided session identity; exact version unknown).
Starting revision: `5685f5b`, with pre-existing modified and untracked project files.
Preserved the current project state in a snapshot commit for the user-requested
private `wundram/splite` GitHub repository. Existing ignore rules exclude local
caches, training outputs, captures, and source archives. Checked upload file sizes
and common credential patterns; no oversized GitHub blobs or matches found.
No implementation changes or runtime tests; this is a repository upload.
Next step: verify the pushed branch and tags against local refs.
