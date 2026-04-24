# MATLAB Xacro Import Helpers

This folder adds a workspace-aware alternative to MATLAB `importrobot` for xacro files that use ROS substitution args like `$(find pkg)`.

## Functions

- `initialize_xacro_import_environment`
- `importrobot_xacro_workspace`

## Quick Start

```matlab
cfg = initialize_xacro_import_environment(...
    'WorkspaceRoot', 'C:\path\to\xacro_workspace');

xacroFile = fullfile(cfg.WorkspaceRoot, 'src', 'example_robot_description', 'urdf', 'robot_workspace.urdf.xacro');

[robot, info] = importrobot_xacro_workspace(xacroFile, ...
    'WorkspaceRoot', cfg.WorkspaceRoot, ...
    'DataFormat', 'row', ...
    'MaxNumBodies', 128);
```

## Simulink Model Initialization Example

Use this in model callbacks such as **Model Properties > Callbacks > InitFcn**:

```matlab
cfg = initialize_xacro_import_environment(...
    'WorkspaceRoot', 'C:\path\to\xacro_workspace');

xacroFile = fullfile(cfg.WorkspaceRoot, 'src', 'example_robot_description', 'urdf', 'robot_workspace.urdf.xacro');

robot_test = importrobot_xacro_workspace(xacroFile, ...
    'WorkspaceRoot', cfg.WorkspaceRoot, ...
    'DataFormat', 'row', ...
    'MaxNumBodies', 128);
```

## Robotiq / Launch-Arg Compatibility

Some Robotiq xacro files mix launch-style `$(arg ...)` patterns into robot-description includes.
The importer supports this with global defaults.

```matlab
argDefaults = struct('use_fake_hardware','true','com_port','/dev/ttyUSB0');

robot_test = importrobot_xacro_workspace(xacroFile, ...
    'WorkspaceRoot', cfg.WorkspaceRoot, ...
    'ArgDefaults', argDefaults, ...
    'RobotiqCompat', true, ...
    'UnresolvedArgPolicy', 'warn', ...
    'DataFormat', 'row', ...
    'MaxNumBodies', 128);
```

Policies:
- `'error'`: stop on unresolved `$(arg ...)`
- `'warn'` (default): warn and replace unresolved args with empty string
- `'empty'`: silently replace unresolved args with empty string

## Notes

- The importer recursively preprocesses xacro includes and resolves:
  - `$(find <package>)`
  - `package://<package>/...`
- It preserves support for `DataFormat`, `MaxNumBodies`, and `CollisionDecomposition` through to `importrobot`.
- Additional launch-style xacro arg support is available through `ArgDefaults`, `RobotiqCompat`, and `UnresolvedArgPolicy`.
- For codegen pipelines, use this during initialization to generate/resolve URDF, then import URDF in generated workflows.
