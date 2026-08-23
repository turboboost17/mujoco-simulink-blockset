# End-to-end xacro -> MuJoCo example & regression artifact

This folder holds the end-to-end (E2E) example and regression artifact that
exercises the full pipeline:

```
ROS xacro (with args)  ->  importrobot_xacro_workspace  ->  resolved URDF
                       ->  generate_mujoco_from_xacro_workspace
                       ->  MuJoCo compile.exe (x2)        ->  portable MJCF + URDF + manifest
```

The robot under test is the Kinova **gen3** 7-DOF arm with a **Robotiq 2F-85**
gripper, plus a sensor package (wrist force/torque frame, wrist IMU frame, a
wrist-mounted RealSense D405 camera and a base-mounted RealSense D435i imager).

## Source model

| Item | Path |
| --- | --- |
| Top-level xacro | `tests/fixtures/gen3_robotiq_ros2/kortex_description/robots/gen3_robotiq_2f_85.xacro` |
| Sensor macro | `tests/fixtures/gen3_robotiq_ros2/kortex_description/robots/kinova_sensors.xacro` |
| Gripper (MuJoCo) | `tests/fixtures/gen3_robotiq_ros2/kortex_description/grippers/robotiq_2f_85/mujoco/` |
| Gripper descriptor | `.../mujoco/robotiq_2f_85.gripper.json` |

The xacro is invoked with `sensors:=true` (default), which inserts the
`force_torque_frame` between the arm flange and the gripper mount so the gripper
wrench is registered through the force/torque sensor.

## What the converter produces

The ROS Robotiq subtree (kinematic-only) is **stripped** from the imported URDF
and replaced with the self-contained MuJoCo gripper via a MuJoCo `<attach>` using
the `rq_` prefix. The converter also inserts:

- `<camera>` entries from the MJCF-format comments preceding each
  `*_camera_link` / `*_image_link` frame (`realsense_d405`, `realsense_d435i`).
- `force_torque_site` (in `force_torque_frame`) and `imu_site` (in `imu_frame`).
- Sensors: `jointpos`/`jointvel` per arm joint, `force`/`torque` on the FT site,
  and `framequat`/`gyro`/`accelerometer` on the IMU site.
- Position actuators for each detected arm joint.

## Folder layout

| Path | Purpose |
| --- | --- |
| `expected/gen3_robotiq_2f_85.expected.json` | Regression spec: entities the generated MJCF must contain. |
| `generated/` | Output location for a manual run (git-ignored). |

## Regenerate the artifacts manually

```matlab
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath')))); % blockset root
fixtureRoot = fullfile(repoRoot, 'tests', 'fixtures', 'gen3_robotiq_ros2');
xacro = fullfile(fixtureRoot, 'kortex_description', ...
    'robots', 'gen3_robotiq_2f_85.xacro');
generate_mujoco_from_xacro_workspace(xacro, ...
  'WorkspaceRoot', fixtureRoot, ...
    'OutputDir', fullfile(repoRoot, 'tests', 'e2e_xacro_ros2', 'generated'), ...
    'Gripper', 'robotiq_2f_85', ...
    'ForceRebuild', true);
```

## Regression test

`tests/t_XacroGen3GripperE2E.m` runs the converter into a temporary directory and
asserts the generated MJCF matches `expected/gen3_robotiq_2f_85.expected.json`.
The test is Windows-only because it invokes the bundled `compile.exe`
(`lib/win64/mujoco/bin/compile.exe`).

> Note: this artifact stops at the portable MJCF/URDF stage. The downstream
> `colcon`/ROS 2 build is intentionally **not** run here.
