# Device Profiles — mujoco-simulink-blockset

This folder contains reusable **device profiles** that bundle everything
needed to retarget a Simulink model from one hardware/ROS 2 target to
another with a single command:

1. A freestanding `Simulink.ConfigSet` (solver, hardware implementation,
   build toolchain, code-generation options, `CoderTargetData` including
   `BoardParameters.DeviceAddress/SSHPort/Username/Password` and
   `ROS2Install.Folder/Workspace`).
2. The full `ROS_Toolbox_ROS_Device` preference set that backs
   `ros2device` (hostname, username, SSH port, ROS 2 install folder,
   ROS 2 workspace, password if saved).
3. Optional per-block mask overrides (e.g. `MuJoCo Plant/renderingType`
   on headless targets).
4. Optional build requirements metadata for the ROS 2 target packages,
  including target apt/rosdep packages and MuJoCo shared-library artifacts.

## Switching targets (day-to-day)

```matlab
% Pi (aarch64, ROS 2 Jazzy, headless xvfb rendering)
mj_applyDeviceProfile("raspi-arm64-ros2jazzy");

% WSL (x86_64, ROS 2 Humble, local development)
mj_applyDeviceProfile("wsl-x64-ros2humble");
```

`mj_applyDeviceProfile`:
- Attaches the profile's ConfigSet to the open model and activates it
  (the previous active set is saved to `<modelDir>/<model>_preProfile.mat`).
- Writes the profile's `ROS2DevicePrefs` into
  `ROS_Toolbox_ROS_Device` prefs (so `ros2device()` now points at the
  new target). If a password is already saved for the same host/user/port,
  that saved password is preserved by default.
- Applies per-block mask overrides (e.g. MuJoCo renderingType).
- Seeds an empty `colcon build` on the remote workspace if
  `install/setup.bash` is missing, so Simulink's pre-deploy
  `DeviceDiagnostics` check doesn't pop the "Configure ROS device"
  dialog (see skill gotcha G11). Pass `SeedROS2Workspace=false` to
  disable.

## Operational gotchas (current)

- Keep build architecture and deployment architecture separate:
  `mujoco.ros2TargetArch` controls which MuJoCo target binaries are staged
  into generated code (`linux-x86_64` vs `linux-aarch64`), while
  `ROS2DevicePrefs`/`BoardParameters` control where deploy runs.
- Legacy profile compatibility is in place:
  if an older profile MAT has no `MuJoCoPrefs.ros2TargetArch`,
  `mj_applyDeviceProfile` infers it from profile metadata/name
  (for example `raspi` -> `linux-aarch64`).
- To reduce repeated SSH credential popups in regression automation:
  use `SeedROS2Workspace=false` in test paths that do not need first-time
  workspace seeding. Seeding performs an extra SSH probe by design.
- Raspberry Pi default profile behavior is intentionally headless-safe:
  template defaults disable MuJoCo image outputs (`renderingType=None`,
  RGB/depth/segmentation off). For camera-publication runs, explicitly
  set MuJoCo Plant to `renderingType=Local` and `rgbOutOption=on`, then
  launch under `xvfb-run`.
- MuJoCo runtime staging expectations:
  generated ROS package source should contain both a versioned
  `libmujoco.so.3.8.0` and soname/symlink-compatible `libmujoco.so` copy.
  Packaging helpers stage both so remote `colcon build` and runtime linking
  succeed.
- ROS ProjectTool package layout can produce nested `src/src` paths in some
  generated contexts; packaging/link normalization in post-codegen handles
  this, so avoid hardcoding single-level assumptions in helper scripts.

## Adding a new target

The preferred path is to start from a shipped sanitized template rather than
from a generic Simulink model. The templates configure the ROS 2 hardware
board, Colcon toolchain, runtime build action, `SupportNonInlinedSFcns=on`,
target hardware type, ROS device prefs, MuJoCo target architecture, model
overrides, and build requirements in one place. The profile's
`MuJoCoPrefs.ros2TargetArch` is consumed by `rtwmakecfg` so code generation
selects the correct MuJoCo target artifacts for `linux-x86_64` (WSL/native
Ubuntu) or `linux-aarch64` (Raspberry Pi/ARM).

```matlab
cfg = mj_ros2DeviceProfileTemplate("ubuntu-2204-x64-ros2humble");
cfg.ProfileName = "lab-ubuntu-x64-ros2humble";
cfg.ROS2DevicePrefs.Hostname = "lab-ubuntu";
cfg.ROS2DevicePrefs.Username = "robot";
cfg.ROS2DevicePrefs.Password = "";
cfg.ROS2DevicePrefs.ROS2Workspace = "/home/robot/ros2_ws/mj_monitorTune_ROS";
profilePath = mj_createDeviceProfileFromTemplate(cfg);
```

The generated private `*.mat` profile is ignored by git because it can contain
hostnames, usernames, and SSH passwords. Commit only `*.template.mat` files.

To refresh the shipped sanitized MAT templates after changing template fields:

```matlab
mj_exportDeviceProfileTemplates()
```

The exported templates are not directly applyable; `mj_applyDeviceProfile`
will reject them until placeholders such as `/home/<user>/ros2_ws/<node>` are
replaced and a private profile is created.

## Function-call cookbook (remote WSL, open model)

Use this when `ros2device` is already configured and you want a stable
profile for a fresh model that keeps ROS2/RTW/TLC settings intact.

```matlab
% 1) Build cfg from template + current MATLAB session
mdl = bdroot(gcs);  % e.g. "test_build"
cfg = mj_ros2DeviceProfileTemplate("wsl-x64-ros2humble");
cfg.ProfileName = "wsl-x64-ros2humble-remote";
cfg.Description = "Remote WSL Ubuntu 22.04 + ROS 2 Humble";
cfg.Model = string(mdl);
cfg.ROS2DevicePrefs = getpref('ROS_Toolbox_ROS_Device');

% 2) Force settings that commonly drift on fresh models
cfg.ModelConfig.RemoteBuild = true;
cfg.ModelConfig.RuntimeBuildAction = "Build and load";
cfg.ModelConfig.SupportNonInlinedSFcns = "on";
cfg.ModelConfig.ExtMode = "off";

% 3) Create profile MAT (private, ignored by git)
profilePath = mj_createDeviceProfileFromTemplate(cfg, ...
  SaveModel=false, VerifyConnection=false)
```

Apply + verify before building:

```matlab
info = mj_applyDeviceProfile("wsl-x64-ros2humble-remote", ...
  Model=string(mdl), Save=false, SeedROS2Workspace=false);
cs = getActiveConfigSet(mdl);

get_param(cs,'SystemTargetFile')
get_param(cs,'Toolchain')
get_param(cs,'SupportNonInlinedSFcns')
codertarget.data.getParameterValue(cs,'ROS.RemoteBuild')
codertarget.data.getParameterValue(cs,'Runtime.BuildAction')
```

For the `libmujoco.so.3.8.0` link issue during remote `colcon build`, verify
the generated package source contains both library names:

```bash
find src/<package>/src -maxdepth 1 -name 'libmujoco.so*' -print
```

Expected files:
- `libmujoco.so.3.8.0`
- `libmujoco.so`

Also verify target system deps are installed:

```bash
sudo apt-get install -y --no-install-recommends libglfw3-dev libgl-dev
```

## Adding a new target by snapshot

1. Configure `ros2device` from the Hardware menu **or** by
   `setpref('ROS_Toolbox_ROS_Device', …, …)` manually. Verify it
   connects.
2. Open your model, open Model Configuration Parameters → Hardware
   Implementation → select the board, pick toolchain, set build
   configuration, etc. Make sure the ROS pane matches `ros2device` (the
   save helper will sync on your behalf but it's good hygiene).
3. `mj_saveDeviceProfile("<new-target-name>", Description="…",
   ModelOverrides=struct('MuJoCo_Plant', struct('Path','MuJoCo Plant', …)))`.
   This snapshots the active ConfigSet + ROS2 prefs + overrides into
   `<new-target-name>.mat`.
4. Verify by switching to a different profile, then
   `mj_applyDeviceProfile("<new-target-name>")`, then `slbuild`.

## Related helpers

| Function                 | Purpose                                                         |
|--------------------------|-----------------------------------------------------------------|
| `mj_saveDeviceProfile`   | Snapshot current model + ROS2 prefs → profile `.mat`            |
| `mj_applyDeviceProfile`  | Apply profile to a model + prefs (+ optional ws seed)           |
| `mj_initROS2Workspace`   | Empty `colcon build` to seed `install/setup.bash` on remote     |
| `mj_ros2DeviceProfileTemplate` | Return fill-in config for a supported ROS 2 hardware shape |
| `mj_createDeviceProfileFromTemplate` | Build a private profile from a filled template       |
| `mj_exportDeviceProfileTemplates` | Regenerate commit-safe `*.template.mat` files        |

## Design

- Each profile is a single `*.mat` file containing one `profile` struct.
- Profiles are portable: copy the `.mat` file into another repo and
  apply it. No dependency on a Simulink Data Dictionary.
- Applying a profile **backs up** the model's previous active config to
  `<modelDir>/<model>_preProfile.mat` so you can roll back.

## Why not a Data Dictionary?

Data dictionaries are the "book of record" approach and are ideal when
multiple models in the same repository share a config. For the
mujoco-simulink-blockset our primary axis of variation is **target
hardware**, not model family, and the profiles double as serialized
`ros2device` snapshots — MAT files on disk travel better between
machines, devcontainers, and CI than a `.sldd`.

You can still load a profile's `ConfigSet` into a `.sldd` if you adopt
that workflow later; see `Simulink.data.dictionary.create`.

## Profile Struct Fields

| Field              | Type                 | Purpose                                   |
|--------------------|----------------------|-------------------------------------------|
| `Name`             | char                 | Profile identifier                        |
| `Description`      | char                 | Free-text label                           |
| `SavedAt`          | datetime             | Provenance                                |
| `SourceModel`      | char                 | Model that was snapshotted                |
| `ConfigSet`        | `Simulink.ConfigSet` | Freestanding (detached) copy              |
| `ConfigSummary`    | struct               | Human-readable highlights                 |
| `ROS2DevicePrefs`  | struct               | Verbatim `ROS_Toolbox_ROS_Device` prefs   |
| `MuJoCoPrefs`      | struct               | Hardware-specific MuJoCo prefs, e.g. `ros2TargetArch` |
| `ModelOverrides`   | struct               | Keyed by `matlab.lang.makeValidName` of block path, each entry has `.Path` (block path relative to model) and `.Values` (struct of MaskName→string) |
| `BuildRequirements`| struct               | Target setup packages and generated build artifacts |

Template profiles also set `IsTemplate=true` and are written as
`*.template.mat`. They contain placeholders and are safe to commit.

## ROS 2 target build requirements

Core MuJoCo/GLFW/OpenGL link declarations are emitted from
`blocks/rtwmakecfg.m` using `rtwmakecfg`-compatible fields. This keeps the
generated ROS CMake link rules in the supported makecfg flow.

`mj_postcodegen_grt` is packaging-only: it bundles
`libmujoco.so.<version>` plus the `libmujoco.so` soname copy, copies MJCF XML
assets, and stages those runtime files into the generated ROS package source.
`build_ros2_model.sh` then copies staged `libmujoco.so*` artifacts into the
package `install/<pkg>/lib` folder after `colcon build`, which is where the
runtime loader expects them on non-merge installs.

GLFW and OpenGL remain target system dependencies. Keep
`libglfw3-dev` and `libgl-dev` installed on target systems through
`tools/setup_ros2_target.sh` or equivalent provisioning.

Custom ROS2 message dependencies remain intact: this refactor leaves
Simulink/ROS Toolbox generated `ament_target_dependencies(...)` content as-is.

On the target, `tools/setup_ros2_target.sh` installs the expected apt packages:

```bash
sudo apt-get install -y --no-install-recommends libglfw3-dev libgl-dev build-essential cmake
```

## Safety

- Passwords inside `ROS2DevicePrefs` **and** inside the captured
  `ConfigSet.CoderTargetData.BoardParameters.Password` are stored
  verbatim in the MAT. Treat profiles as secrets or blank both fields
  before committing. The save helper doesn't auto-redact because then
  the profile couldn't be applied without prompting.
- `mj_applyDeviceProfile` always writes a rollback MAT next to the
  model before attaching the new config set.

## Included Profiles

Private device profiles embed SSH credentials (see Safety above) and are
excluded by `tools/deviceProfiles/.gitignore`. The repository ships sanitized
`*.template.mat` files for these supported shapes:

- `raspi-arm64-ros2jazzy.template.mat` — Raspberry Pi 4 on your LAN, Ubuntu
  24.04 aarch64, ROS 2 Jazzy (`/opt/ros/jazzy`), workspace
  `/home/<user>/ros2_ws/<pkg>`. ARM Cortex-A 64-bit,
  BuildConfiguration=`Faster Runs`, MuJoCo defaults to headless-safe
  `renderingType = None` with image outputs disabled.
- `wsl-x64-ros2humble.template.mat` — WSL2 Ubuntu 22.04 x86_64, ROS 2 Humble
  (`/opt/ros/humble`), workspace `/home/<user>/ros2_ws/<pkg>`.
  x86_64 build-for-host/local development target.
- `ubuntu-2204-x64-ros2humble.template.mat` — Native Ubuntu 22.04 x86_64,
  ROS 2 Humble (`/opt/ros/humble`), workspace `/home/<user>/ros2_ws/<pkg>`.

