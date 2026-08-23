# Gen3 + Robotiq Xacro Regression Fixture

This is a minimal vendored fixture for the end-to-end xacro -> URDF -> MJCF regression.
It contains only the Kinova Gen3 7-DOF and Robotiq 2F-85 files referenced by the test.

## Provenance

- Kinova Kortex ROS source: `Kinovarobotics/ros_kortex`, `noetic-devel` lineage.
- Robotiq source provenance: see `kortex_description/grippers/robotiq_2f_85/README.md`.
- Local additions for this regression: sensor xacro, MuJoCo gripper descriptor, and self-contained gripper MJCF/assets.

The Kinova license is preserved in `LICENSE`. The Robotiq license is preserved in
`kortex_description/grippers/robotiq_2f_85/LICENSE`.

## Scope

This fixture is intentionally not a full ROS workspace. `kortex_description/package.xml`
is retained so `importrobot_xacro_workspace` can resolve the package map. Meshes are
retained because both URDF and MuJoCo compilation validate the referenced assets.

Do not replace this fixture with a machine-local `ros_kortex-noetic-devel` checkout.
Update it only with matching provenance, licenses, and a passing
`t_XacroGen3GripperE2E` regression.
