# Regression test harness

Entry point:

    cd(<repoRoot>)
    addpath('tests'); addpath('tests/utils'); addpath('tests/fixtures');
    results = runAllTests();

## Tag-based filtering

    runAllTests('Tags', {'Core'})              % fast smoke tests only
    runAllTests('Skip', {'ROS2Pi','ROS2WSL'})  % dev iteration
    runAllTests('Tags', {'NewFeature'})        % just the seg-repo additions
    runAllTests('Tags', {'BrickSdf'})          % brick SDF build/load smoke only

## Tags

- `Core`, `CommandInputs`, `SensorOutputs`
- `BrickSdf`
- `Rendering`, `RenderOff`, `RGB`, `Depth`, `Seg`, `Combo`
- `ROS2WSL`, `ROS2Pi`, `ROS2Runtime`, `ROS2PiRuntime`
- `NewFeature`, `PerCameraResolution`, `SegmentationIDs`, `SegmentationVideo`, `Xacro`

`ROS2Pi` and `ROS2PiRuntime` are hardware-gated. They skip when ROS 2 prefs,
device profiles, or the Raspberry Pi target are unavailable, but they are
expected to pass end-to-end on the lab Pi target. The runtime test launches the
deployed node in normal simulation mode with external mode off and validates
changing `/block_camera` and `/arm_imu` messages.

New-feature tests are expected to fail / be skipped before their
corresponding integration phase lands.
