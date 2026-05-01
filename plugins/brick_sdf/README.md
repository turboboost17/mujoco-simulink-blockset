# Brick SDF Plugin

This MuJoCo engine plugin registers one parametric brick SDF shape:

```text
mujoco.sdf.brick
```

Config attributes:

| Attribute | Default | Meaning |
| --- | ---: | --- |
| `stud_x` | `4` | Number of studs along local `x` |
| `stud_y` | `2` | Number of studs along local `z` |
| `height` | `3` | Brick height in plates, clamped to `1..3` |

The local SDF uses `y` as the vertical axis. The example MJCF rotates the geom so the brick stands upright in MuJoCo's usual world `z` axis.

Build from MATLAB with:

```matlab
artifact = build_brick_sdf_plugin;
```

The helper builds the shared library with CMake and installs it into the active MuJoCo runtime's `bin/mujoco_plugin` directory.

Run the full local smoke path with:

```matlab
result = smoke_brick_sdf_plugin;
```

The smoke helper rebuilds the plugin, runs the native MuJoCo loader executable, checks `mj_sampletime` and `mj_labelmap_mex`, then runs a temporary no-render Simulink model around `mj_sfun`.

Public examples:

- `examples/brick_sdf_2x4.xml` keeps the release smoke case small and reproducible.
- `examples/brick_sdf_stack.xml` keeps the larger interlock/tuning scenario used during contact-stability work.

For contact-settling work, the build also creates a native metric executable:

```text
brick_sdf_stability <plugin_dir> <model.xml> [body_name=brick_2] [duration=3] [settle_start=1]
```

It steps the model headlessly and reports a scalar `score` plus final/RMS body speeds, pose drift, contact penetration, contact count, solver iterations, warnings, and real-time factor. Lower score is better; `stability_pass=1` means the named body settled below the current conservative thresholds.

Keep smoke and demo MJCFs conservative with `sdf_initpoints` and `sdf_iterations`. MuJoCo can become unstable or crash if SDF visualization asks it to generate or show too many tetrahedra; `smoke_brick_sdf_plugin` fails fast above its default budget of `10` init points and `8` iterations unless you explicitly override the limits.
