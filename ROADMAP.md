# ROADMAP

Tracking current release status, remaining gaps, and upcoming work for
render-heavy domain randomization and batch GPU rendering.

## Release Versioning

Git release tags use `M.m.p.r`: `M.m.p` is the bundled MuJoCo version and
`r` is the blockset subrelease. The initial MuJoCo 3.12.0 blockset release is
`3.12.0.0`. Runtime download selection remains controlled by `MJ_VER` in
`install.m`, not by Git tag parsing.

## Current baseline

- **MuJoCo 3.12.0 -> 3.17.0 upgrade (2026-10-30)**: Windows, Linux x86_64,
  and Linux aarch64 SDKs are pinned to 3.17.0. All six MEX targets and the
  brick SDF plugin rebuilt without C API source changes. The release helper
  reports blockset 3.17.0.0. See the upgrade notes below for validation status
  and model-dependent behavior watchpoints.
- **Per-camera render sizing**: `MujocoGUI::initInThread` resolves effective
  offscreen W/H from `desiredWidth/Height`, MJCF camera `resolution`, global
  offscreen size, then `640x480`, and calls `mjr_resizeOffscreen` before
  `mjr_maxViewport`.
- **Parser auto-refresh**: RGB / Depth parser mask initialization rebinds bus
  names, dropdowns, and port widths after resolution changes.
- **YOLO export smoke**: `tests/t_YoloExport.m` covers synthetic segmentation
  video to YOLO label export and normalized bounds.
- **ROS 2 Pi runtime validation (2026-10-30)**: build/deploy, node discovery,
  both publishers, three changing finite IMU samples, and three nonconstant
  320x240 `rgb8` camera images pass on 3.17.0 under `xvfb-run`. Keep the
  camera assertion enabled rather than accepting publisher presence as proof
  of valid rendered images.

## Verified (green)

| Area                     | Status | Notes |
|--------------------------|--------|-------|
| Core (command/sensor/version/plugin) | 8/8 | `tests/runAllTests Tags='Core'` |
| Rendering combos (8)     | 8/8    | Off / RGB / Depth / Seg / RGB+Depth / Depth+Seg / Seg+RGB / AllThree |
| Segmentation IDs         | PASS   | `t_SegmentationIDs` |
| Segmentation video write | PASS   | `t_SegmentationVideo` (needs ≥64×64 frames for MPEG-4) |
| Xacro import helpers     | PASS   | `t_XacroImport` |
| ROS2 WSL codegen + build | PASS   | `rtwbuild` → `.tgz` → colcon build on WSL Ubuntu + ROS 2 Humble |
| ROS2 Pi runtime deploy   | PASS*  | Build/deploy/discovery/IMU and strict nonconstant camera frames |
| Per-camera resolution (mex) | PASS | `mj_initbus(xml, widths, heights)` with scalar or vector args |

`PASS*` rows require external hardware or ROS 2 host setup. They skip with
`assumeFail`/assumptions when the target, ROS 2 prefs, or required device
profiles are unavailable, but they are verified end-to-end when the lab Pi/WSL
environment is present.

## Open work

### Unverified

- **YOLO dataset export from real simulations**: `t_YoloExport` covers a
  synthetic 2-frame segmentation video through YOLO labels. A longer
  end-to-end smoke using a real model/rendered dataset is still useful.

### Known limitations

- **`set_param` is a no-op for mask init when the new value matches the
  saved value**: documented in tests; force re-init via `bdclose all` in
  `TestMethodSetup` or by touching `xmlFile` (which always triggers init).

1. **MuJoCo 3.12 comparison harness**: add quantitative A/B baselines for
  contact-sensitive brick stacks, `implicitfast` free-body motion, and finite
  textured primitives. The existing smoke tests prove functionality but do not
  freeze exact trajectory or pixel baselines.
2. **Device profile packaging**: keep generated `*.mat` device profiles out
  of git because they can contain lab host/user settings. If public examples
  are needed, add sanitized templates or an export script rather than tracking
  local profile snapshots.
3. **ROS 2 Pi host CI hook**: document how to point tests at a lab host via
   `setenv('MJ_ROS2_PI_HOST', '...')` in a preflight script.
4. **ROS 2 Linux host CI hook**: document how to point tests at a native Linux
  ROS 2 host via `setenv('MJ_ROS2_LINUX_HOST', '...')` in a preflight script.
5. **`.gitignore` audit**: verify all generated artifacts (`slprj/`,
   `*_ert_rtw/`, `*_grt_rtw/`, `*.slxc`) are properly scoped per-folder.

### Environment / supply chain

- **MuJoCo 3.17.0**: current target. Keep `multiccd` A/B checks from 3.8;
  additionally review nonzero `gap`, free-body `implicitfast`, DC motors,
  custom texture assets, finite textured primitives, and mocap contact/raycast
  behavior when those features appear in user models. Since 3.12.0.1 the
  control bus has one element per control (`nu`), so multi-input actuators
  such as `<orientation input="quat">` get `<actuator>_<input>` elements.
- **MuJoCo 3.17**: reviewed 2026-10-24 as a low-impact fast forward. Its
  breaking changes (`mjs_*` spec API, resource provider and decoder renames,
  `mjNEQDATA`, flex implicit integration, `dampratio` with reflected inertia,
  solver termination scaling) touch no API the blockset calls. The upgrade is
  an `MJ_VER` bump in `install.m`, a MEX and plugin rebuild, a ROS 2 target
  SDK refresh, and new numeric baselines where models use `dampratio` or rely
  on solver iteration counts.
- **GLFW 3.4**: optional bump from 3.3.7 (minor API additions, non-breaking).

### Build artifact policy

- **`tools/win64.mk` stays untracked**: it is generated by `tools/setupBuild.m`
  and contains machine-local MATLAB, MuJoCo, and GLFW paths. Keep the current
  `tools/.gitignore` rule. If onboarding needs a checked-in artifact later,
  add a sanitized `win64.mk.example` or improve `setupBuild` prompts instead of
  committing a real local `win64.mk`.

### Future: MJX / Warp batch rendering

- **MJX-Warp batch renderer prototype**: evaluate `mujoco-mjx[warp]` for
  high-throughput RGB/depth camera observations across many parallel worlds.
  The likely first prototype is a Python sidecar or dataset-generation tool that
  loads exported MJCF, creates a fixed-size `create_render_context`, calls
  `mjx.refit_bvh` + `mjx.render`, and returns batched frames to MATLAB or files.
- **Scope constraints to verify**: MJX-Warp is NVIDIA-GPU oriented, its render
  context fixes `nworld` at creation time, and public docs focus on RGB/depth.
  Segmentation/ID output support needs a proof of concept before promising full
  parity with the current C/OpenGL segmentation pipeline.
- **JAX backend role**: MJX-JAX remains interesting for differentiable or
  accelerator-batched physics workflows, while MJX-Warp looks more attractive
  for high-throughput rendering/contact-heavy simulation. Treat them as
  complementary backends, not a replacement for the Simulink S-function path.

### Future: domain randomization

- **MATLAB/Simulink front end**: add a randomization config layer for model
  parameters, camera intrinsics/extrinsics, lighting/materials, sensor noise,
  initial conditions, and controller inputs. Include deterministic seeds and a
  manifest so exported datasets can be reproduced.
- **Runtime vs structural changes**: numeric `mjModel`/`mjData` perturbations
  can be applied at runtime for the C/MEX path; structural changes such as body
  topology, mesh assets, camera counts, or MJCF include graph should remain
  compile/export-time changes.
- **MJX batching path**: represent per-world randomized numeric fields as
  batched `mjx.Model`/`mjx.Data` arrays where possible. Avoid randomizing MJX
  structural numpy fields inside a tight loop because those force recompilation.
  This fits naturally with the future batch-rendering sidecar above.

## MuJoCo 3.17 Upgrade Notes

Target: MuJoCo 3.17.0, released 2026-10-22; planned blockset version 3.17.0.0.
Baseline: public `main` at `3f8db89` (blockset 3.12.0.1).

Public history had been rewritten. The old local `main` at `f781b7f` had the
same tree as rewritten public commit `66ed4c8`, but was not its ancestor.
It is preserved as `archive/2026-10-30-main-before-public-sync`; `main` now
tracks `public/main` and `git pull --ff-only` succeeds. No remote history or
release tag was rewritten.

Review of the [3.13](https://github.com/google-deepmind/mujoco/releases/tag/3.13.0),
[3.14](https://github.com/google-deepmind/mujoco/releases/tag/3.14.0),
[3.15](https://github.com/google-deepmind/mujoco/releases/tag/3.15.0),
[3.16](https://github.com/google-deepmind/mujoco/releases/tag/3.16.0), and
[3.17](https://github.com/google-deepmind/mujoco/releases/tag/3.17.0) releases
found no required migration of the C APIs used by this wrapper. All MEX files,
plugins, and generated target executables must nevertheless be rebuilt against
matching headers and libraries because public struct layouts changed.

Model-dependent watchpoints remain: elastic flexes under implicit integrators
must migrate to `discrete`; actuator `dampratio` and shortcut-default inheritance
changed; weld/tendon force sensors and collision handling were corrected; solver
termination scaling changed. Existing exact dynamics baselines may need review.
The current classic OpenGL path does not use the renamed Filament APIs.

Execution gates (2026-10-30):

1. Rebuild public main with 3.12.0 in desktop MATLAB via `setupBuild; build`.
2. Record baseline local, WSL archive, and Pi runtime test results.
3. Update the installer, release helper, and all three platform SDK assets.
4. Use a fresh MATLAB session for the runtime swap; never replace a loaded
  brick SDF plugin and reuse it in the same process.
5. Rebuild and repeat the same regressions with
  `setenv('MJ_STRICT_PI_CAMERA','1')` so three nonconstant images are required.

Validation status: all three 3.17.0 SDK archives verified against published
SHA-256 digests; installation, six-target MEX rebuild, plugin rebuild, and
both release-version tests passed. The full regression recorded 38 passes,
one failure, and zero incomplete tests. Local rendering, camera sizing,
multi-input controls, Xacro conversion, and WSL archive generation passed.
The strict Pi test initially failed only on nonconstant camera content.

Root cause (2026-10-30): the Pi device profile disabled RGB output, which
removed the plant's RGB port; re-enabling RGB recreated the port without
reconnecting the downstream parser, so generated code published a
zero-filled image. Standalone MuJoCo 3.17 rendering on the Pi
(`tools/pi_render_probe.py` under `xvfb-run`, Mesa llvmpipe) produced valid
frames, isolating the fault to the Simulink port wiring. The runtime test now
applies RGB settings without the off/on transition and asserts the parser is
connected before building; the strict run then received three nonconstant
320x240 images. The underlying mask `replacer()` connection loss is tracked
for a fix with the plant state/control ports work.

Generated reports (ignored test artifacts):
- `tests/results/baseline-3.12-public-main.json`
- `tests/results/baseline-3.12-pi-discovery-before-stream.json`
- `tests/results/upgrade-3.17.0.json`
- `tests/results/upgrade-3.17.0-pi-headless.json`

Baseline observations: public main passed 38 tests, with the Pi graph check
failing despite message receipt. Discovering the graph before creating reliable
image subscribers resolved that failure. Strict testing then exposed constant
camera frames on 3.12.0; the test now requires three changing IMU samples and
three nonconstant images without weakening graph assertions. The 3.12 brick
stack had zero warnings but exceeded its existing RMS angular-speed threshold
(0.322 rad/s versus 0.25 rad/s); keep this as a numerical comparison point.
With 3.17.0, the same native stack checker passed without model changes:
RMS angular speed 0.228 rad/s, peak penetration 0.141 mm, and zero warnings.

## MuJoCo 3.12 Upgrade Notes

Upgrade review covered 3.9.0 through 3.12.0 against this repository's C API and
MJCF usage:

| Release | Relevant change | Blockset disposition |
| --- | --- | --- |
| 3.9 | `mjtnum.h` renamed to `mjtype.h` | Brick SDF include migrated. |
| 3.9 | `margin`/`gap` semantics changed | Shipped models use default `gap=0`; no migration required. |
| 3.10 | Threading API removed; `mj_fullM` changed | APIs are not used by the wrapper. |
| 3.11 | `mjv_moveCamera` dropped `mjvScene` | Both GUI call sites migrated. |
| 3.11 | `implicitfast` free-body integration changed | Brick SDF smoke covers finite contact behavior; add quantitative baseline later. |
| 3.12 | Custom binary textures removed; primitive UVs changed | No custom binary textures; shipped textured plane is infinite and retains origin anchoring. |
| 3.12 | DC motor semantics, flex contacts, mocap weld groups changed | Features are absent from shipped models; keep as user-model migration checks. |
| 3.12 | Box-box collision fixes | Rendering/core and brick contact smokes pass; add stack trajectory baseline later. |

Validation completed on 2026-08-23:

1. `install('ros2')` installed 3.12.0 headers and libraries for win64,
  linux-x86_64, and linux-aarch64.
2. MATLAB R2025a `setupBuild; build` rebuilt all six MEX targets with MSVC 2022.
3. `smoke_brick_sdf_plugin` passed native registration, label-map/sample-time,
  and Simulink `mj_sfun` execution.
4. `Core`, `Rendering`, and `NewFeature` tags passed 32/32 with no incomplete tests.
5. Remote WSL/Humble `rtwbuild` passed; the deployed executable resolves
  `libmujoco.so.3.12.0` and system GLFW after standard runtime staging.
6. The aarch64 Python target passed MuJoCo 3.12.0 falling-box/contact physics
  and a nonconstant 64x64 EGL render in an isolated Python 3.12 environment.
7. The Raspberry Pi/Jazzy `t_ROS2_PiRuntime` regression passed build, deploy,
  graph discovery, publisher, IMU, and camera checks against the 3.12 runtime.
