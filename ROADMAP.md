# ROADMAP

Tracking integration status, known gaps, and upcoming work on the
`feature/segmentation` branch after the seg-baseline merge.

## Recently landed

- `d759257` `blocks/` rebased on seg baseline (segmentation IDs, per-camera
  resolution mask params, YOLO export, xacro import helpers).
- `3dd1492` `src/` C++ rebased on seg baseline (buffer safety, conditional
  RGB/Depth/Seg rendering, per-camera resolution plumbing).
- `3bb9778` `tools/` rebased: space-tolerant build scaffolding, labelmap mex
  build target.
- `e99e322` examples synced to new mjLib, YOLO + video-write demos.
- `790f1ba` / `75bdd40` / `3ea62b6` test harness hardened (library-state
  isolation, per-camera mask assertions, parser-width known-limit).
- `9c2d9be` retired `mjLib_old.slx`; ignore generated `+bus_conv_fcns/`,
  `ros_kortex-noetic-devel/`, and transient test artifacts.

## Verified (green)

| Area                     | Status | Notes |
|--------------------------|--------|-------|
| Core (command/sensor)    | 4/4    | `tests/runAllTests Tags='Core'` |
| Rendering combos (8)     | 8/8    | Off / RGB / Depth / Seg / RGB+Depth / Depth+Seg / Seg+RGB / AllThree |
| Segmentation IDs         | PASS   | `t_SegmentationIDs` |
| Segmentation video write | PASS   | `t_SegmentationVideo` (needs ≥64×64 frames for MPEG-4) |
| Xacro import helpers     | PASS   | `t_XacroImport` |
| ROS2 WSL codegen + build | PASS   | `rtwbuild` → `.tgz` → colcon build on WSL Ubuntu + ROS 2 Humble |
| Per-camera resolution (mex) | PASS | `mj_initbus(xml, widths, heights)` with scalar or vector args |

## Known gaps / broken / unverified

### Unverified

- **ROS 2 Pi deploy (`t_ROS2_Pi`)**: currently `assumeFail` (no host reachable
  in lab). Needs a target matching `MJ_ROS2_PI_HOST` env var (or
  `raspberrypi.local`) running ROS 2 Jazzy on arm64 before it can be
  validated end-to-end.
- **YOLO dataset export end-to-end**: `t_SegmentationVideo` / seg decoder
  covered, but `mj_export_yolo_dataset` / `export_yolo_data` have no
  regression coverage yet. TODO: add a golden-image smoke test.

### Known limitations

- **Per-camera resolution downstream parser**: `mj_gettingStarted.slx` wires
  `MuJoCo Depth Parser` selector indices against the native MJCF resolution.
  Driving `camWidth` / `camHeight` to a different size triggers
  "Invalid dimensions" / "port widths" errors. `t_PerCameraResolution/customResolutionRuns`
  marks this as `assumeFail` with the known-limit note. Fix requires
  rewiring the parser to dynamic selector indices (or regenerating the
  example model after mask init).
- **MJCF `<camera resolution="W H">` attribute not honored**: MEX-level
  per-camera resolution args work, but the per-camera resolution attribute
  inside MJCF falls back to the global `<global offwidth/offheight>` size.
  This is a C++ plumbing gap in `initCameras()` / offscreen buffer sizing.
- **`set_param` is a no-op for mask init when the new value matches the
  saved value**: documented in tests; force re-init via `bdclose all` in
  `TestMethodSetup` or by touching `xmlFile` (which always triggers init).
- **`mjLib` saved in R2024b**: loads with forward-compat warnings under
  R2025a. No functional impact but noisy in logs.

### Open TODOs

1. **MuJoCo 3.7 upgrade (scheduled next, see section below).**
2. **Dynamic parser in `mj_gettingStarted.slx`**: rewire Depth / RGB parsers
   so changing per-camera resolution mask values doesn't break parent
   port-width checks. Likely requires variant subsystems or mask-init
   driven selector-index vectors.
3. **Honor MJCF per-camera `resolution=` attribute** in
   `MujocoModelInstance::initCameras()` / `MujocoGUI::setCustomResolution`
   so users can set camera sizes from XML instead of the mask.
4. **YOLO export regression test**: add a short-sim + export smoke to the
   `NewFeature` suite with a fixed seed.
5. **Commit the `wsl-x64-ros2humble.mat` / `raspi-arm64-ros2jazzy.mat` device
   profiles under `tools/deviceProfiles/`** (currently in place but not
   tracked in git on this branch — verify).
6. **ROS 2 Pi host CI hook**: document how to point tests at a lab host via
   `setenv('MJ_ROS2_PI_HOST', '...')` in a preflight script.
7. **`.gitignore` audit**: verify all generated artifacts (`slprj/`,
   `*_ert_rtw/`, `*_grt_rtw/`, `*.slxc`) are properly scoped per-folder.

### Environment / supply-chain TODOs

- **MuJoCo 3.7.0 (latest)**: upgrade from current 3.4.0. Breaking changes
  expected (see upgrade notes below).
- **GLFW 3.4**: optional bump from 3.3.7 (minor API additions, non-breaking).
- **Renumber `install.m` to handle new mujoco dll name / pdb layout**.

## MuJoCo 3.7 upgrade plan

Current: MuJoCo 3.4.0. Target: latest 3.7.x. **Breaking changes that affect
this codebase:**

- `mjr_readPixels` / `mjr_drawPixels` signature and behavior stability —
  verify segmentation readback still returns packed RGB IDs as uint8 via
  `mjRND_SEGMENT + mjRND_IDCOLOR`.
- `mjModel` name-address tables: our code reads `m->name_camadr`,
  `m->names`, `m->ncam`. These remain stable through 3.7 but have been
  re-audited in release notes — confirm during upgrade.
- `mjv_defaultFreeCamera` and `mjvScene` visual defaults have shifted
  between 3.4 and 3.7. Re-check zoom/viewpoint defaults in `MujocoGUI`.
- `mjr_resizeOffscreen` is still available; verify linkage.
- New 3.7 features we may opt into later (not part of initial upgrade):
  - Native per-camera offscreen size (pending MuJoCo commit, may close
    our MJCF-resolution gap above).
  - Extended sensor types (touch grid, etc.).

Upgrade steps (tracked as separate commits):

1. Drop new `mujoco-3.7.0-*` libs into `lib/win64/`, `lib/linux-x86_64/`,
   `lib/linux-aarch64/`.
2. Update `tools/win64.mk` / `tools/Makefile` to reference the new DLL /
   .so names.
3. Rebuild all 6 MEX (`mj_sfun`, `mj_initbus_mex`, `mj_labelmap_mex`,
   `mj_depth_near_far`, `mj_id2name_mex`, `mj_sampletime`).
4. Re-run full test matrix: Core + Rendering + NewFeature + ROS2WSL.
5. Update `install.m` if DLL filename changed.
6. Bump `README.md` / this file with "Tested against MuJoCo 3.7.x".
