# ROADMAP

Tracking integration status, known gaps, and upcoming work on the
`feature/segmentation` branch after the seg-baseline merge.

## Recently landed

- **Known-issue cleanup pass (2026-04-25)**:
  - `mj_parser_maskinit.m` + `tools/patch_parsers.m` rebuilt the RGB / Depth
    Parser MaskInitialization callbacks so dropdowns + port widths
    auto-rebind to the current `mj_bus_<kind>_<hash>` after a resolution
    change — no more manual open-and-refresh of each parser.
  - `MujocoGUI::initInThread` (in `src/mj.cpp`) now resolves effective
    offscreen W/H from the priority chain `desiredWidth/Height →
    m->cam_resolution[2*i] → m->vis.global.offwidth/offheight → 640×480`
    and always calls `mjr_resizeOffscreen` before `mjr_maxViewport`. This
    closes the MJCF per-camera `<camera resolution="W H">` gap.
  - `install.m` now writes `libmujoco.so → libmujoco.so.<ver>` symlinks
    natively on Linux/macOS, and on Windows drops a
    `create_libmujoco_symlink.sh` next to each Linux lib + a best-effort
    `wsl -e sh -c` passthrough so the symlink is created automatically
    when WSL is available.
  - `blocks/mjLib.slx` re-saved as native R2025a in both repos —
    forward-compat "saved in 24.2 R2024b" warning is gone.
  - `t_PerCameraResolution/customResolutionRuns` no longer wraps the
    custom-res sim in `try/catch + assumeFail`; any port-widths error
    is now a real regression.
  - `tests/t_YoloExport.m` added: 2-frame synthetic seg video → exporter
    → assert YOLO directory layout + normalized label coords ∈ [0,1].
  - Removed `assignin('base', 'znear'/'zfar'/'sampleTime', ...)` from
    `blocks/mj_maskinit.m` — values were already pushed via `set_param`
    onto the mask, so the base-workspace writes were dead pollution.
- **MuJoCo 3.4.0 → 3.7.0 upgrade (2026-04-24)**: swapped
  `lib/{win64,linux-x86_64,linux-aarch64}/mujoco/` to 3.7.0,
  refreshed `blocks/mujoco.dll`, bumped `MJ_VER` in both install.m,
  added 3.7.0 entries to `tools/links.json`. Rebuilt all 6 MEX clean
  against new headers — no source edits required (our API surface
  is stable across 3.5/3.6/3.7). Smoke tests green: Core 4/4,
  Rendering+NewFeature 16 pass / 1 known-limit (same pre-existing
  per-camera parser gap, unchanged from 3.4.0).
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
  With the 2026-04-25 parser auto-refresh patch, mask-init now rebinds
  bus + dropdown automatically when the resolution changes. Previously
  a hard known-limit; now expected to pass — if `t_PerCameraResolution/
  customResolutionRuns` fails, treat it as a regression of the parser
  fix rather than an inherent limitation.
- **`set_param` is a no-op for mask init when the new value matches the
  saved value**: documented in tests; force re-init via `bdclose all` in
  `TestMethodSetup` or by touching `xmlFile` (which always triggers init).

### Open TODOs

1. ~~MuJoCo 3.7 upgrade~~ — done 2026-04-24 (lib swap only, zero source
   changes; see "Recently landed" above).
2. ~~Dynamic parser in `mj_gettingStarted.slx`~~ — addressed 2026-04-25
   via `mj_parser_maskinit.m`; mask-init rebinds bus + port widths on
   resolution change.
3. ~~Honor MJCF per-camera `resolution=` attribute~~ — addressed
   2026-04-25 in `MujocoGUI::initInThread` priority chain
   (`m->cam_resolution[2*i]` is consulted before `vis.global.off*`).
4. ~~YOLO export regression test~~ — added 2026-04-25 as
   `tests/t_YoloExport.m` (NewFeature tag).
5. **Commit the `wsl-x64-ros2humble.mat` / `raspi-arm64-ros2jazzy.mat` device
   profiles under `tools/deviceProfiles/`** (currently in place but not
   tracked in git on this branch — verify).
6. **ROS 2 Pi host CI hook**: document how to point tests at a lab host via
   `setenv('MJ_ROS2_PI_HOST', '...')` in a preflight script.
7. **`.gitignore` audit**: verify all generated artifacts (`slprj/`,
   `*_ert_rtw/`, `*_grt_rtw/`, `*.slxc`) are properly scoped per-folder.

### Environment / supply-chain TODOs

- ~~MuJoCo 3.7.0 upgrade~~ — landed 2026-04-24 (was 3.4.0 → now 3.7.0).
- **GLFW 3.4**: optional bump from 3.3.7 (minor API additions, non-breaking).
- ~~Linux tarball symlink automation~~ — addressed 2026-04-25 in
  `install.m` (`ensureLinuxLibmujocoSymlink` + `winPathToWsl`).

## MuJoCo 3.7 upgrade plan (historical — completed 2026-04-24)

Previous: MuJoCo 3.4.0. Target (shipped): 3.7.0. **Breaking changes audited
during the upgrade — none of them affected this codebase:**

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
