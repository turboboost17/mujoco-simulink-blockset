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
  new target).
- Applies per-block mask overrides (e.g. MuJoCo renderingType).
- Seeds an empty `colcon build` on the remote workspace if
  `install/setup.bash` is missing, so Simulink's pre-deploy
  `DeviceDiagnostics` check doesn't pop the "Configure ROS device"
  dialog (see skill gotcha G11). Pass `SeedROS2Workspace=false` to
  disable.

## Adding a new target

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
| `ModelOverrides`   | struct               | Keyed by `matlab.lang.makeValidName` of block path, each entry has `.Path` (block path relative to model) and `.Values` (struct of MaskName→string) |

## Safety

- Passwords inside `ROS2DevicePrefs` **and** inside the captured
  `ConfigSet.CoderTargetData.BoardParameters.Password` are stored
  verbatim in the MAT. Treat profiles as secrets or blank both fields
  before committing. The save helper doesn't auto-redact because then
  the profile couldn't be applied without prompting.
- `mj_applyDeviceProfile` always writes a rollback MAT next to the
  model before attaching the new config set.

## Included Profiles

> **Not shipped with the repository.** Device profiles embed SSH
> credentials (see Safety above) and are excluded by
> `tools/deviceProfiles/.gitignore`. Create your own with
> `mj_saveDeviceProfile`; the templates below describe the shapes the
> maintainer uses locally.

- `raspi-arm64-ros2jazzy.mat` — Raspberry Pi 4 on your LAN, Ubuntu
  24.04 aarch64, ROS 2 Jazzy (`/opt/ros/jazzy`), workspace
  `/home/<user>/ros2_ws/<pkg>`. ARM Cortex-A 64-bit,
  BuildConfiguration=`Faster Runs`, MuJoCo `renderingType = Local` for
  headless `xvfb-run` / `DISPLAY=:99`.
- `wsl-x64-ros2humble.mat` — WSL2 Ubuntu 22.04 x86_64, ROS 2 Humble
  (`/opt/ros/humble`), workspace `/home/<user>/ros2_ws/<pkg>`.
  x86_64 build-for-host/local development target.

