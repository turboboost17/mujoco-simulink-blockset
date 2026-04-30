# Lego SDF Plugin

This MuJoCo engine plugin registers one SDF shape:

```text
mujoco.sdf.lego_brick
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
artifact = build_lego_sdf_plugin;
```

The helper builds the shared library with CMake and installs it into the active MuJoCo runtime's `bin/mujoco_plugin` directory.

Run the full local smoke path with:

```matlab
result = smoke_lego_sdf_plugin;
```

The smoke helper rebuilds the plugin, runs the native MuJoCo loader executable, checks `mj_sampletime` and `mj_labelmap_mex`, then runs a temporary no-render Simulink model around `mj_sfun`.

Keep smoke and demo MJCFs conservative with `sdf_initpoints` and `sdf_iterations`. MuJoCo can become unstable or crash if SDF visualization asks it to generate or show too many tetrahedra; `smoke_lego_sdf_plugin` fails fast above its default budget of `8` init points and `8` iterations unless you explicitly override the limits.
