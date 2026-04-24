# Regression test harness

Entry point:

    cd(<repoRoot>)
    addpath('tests'); addpath('tests/utils'); addpath('tests/fixtures');
    results = runAllTests();

## Tag-based filtering

    runAllTests('Tags', {'Core'})              % fast smoke tests only
    runAllTests('Skip', {'ROS2Pi','ROS2WSL'})  % dev iteration
    runAllTests('Tags', {'NewFeature'})        % just the seg-repo additions

## Tags

- `Core`, `CommandInputs`, `SensorOutputs`
- `Rendering`, `RenderOff`, `RGB`, `Depth`, `Seg`, `Combo`
- `ROS2WSL`, `ROS2Pi`
- `NewFeature`, `PerCameraResolution`, `SegmentationIDs`, `SegmentationVideo`, `Xacro`

New-feature tests are expected to fail / be skipped before their
corresponding integration phase lands.
