# Custom SDF Brick Handoff

This file restores the useful parts of the prior Copilot chat about adding a parametric brick-like SDF plugin to this MuJoCo Simulink blockset. The old `mujoco-simulink-blockset-sdf-fork` clone can be abandoned; this branch starts fresh from latest `main`.

Recovered source transcript:

```text
C:\Users\turbo\AppData\Roaming\Code\User\workspaceStorage\611fe7ae45cd7b81b86ef6b812f46812\GitHub.copilot-chat\transcripts\b47c5917-ac87-429a-bdbf-84c7e756607c.jsonl
```

Original chat title: `Adding SDF Definitions to Mujoco Installation`.

## Main Findings

- You do not need to rebuild MuJoCo itself to add this SDF. Build a MuJoCo engine plugin shared library: one Windows DLL, one Linux x86_64 SO, and one Linux aarch64 SO if all blockset platforms should support it.
- Use the deployable MuJoCo 3.7.0 runtime under `lib/{win64,linux-x86_64,linux-aarch64}/mujoco`, not the older `tools/lib/win64/mujoco` copy. The old tools copy reported MuJoCo 3.3.4.
- The plugin must be loaded before `mj_loadXML`. The blockset paths that parse XML currently call `mj_loadXML` directly, so SDF plugin support needs a one-time `mj_loadAllPluginLibraries(...)` or `mj_loadPluginLibrary(...)` before XML loading.
- A quick test with the bundled `compile.exe` and stock `nutbolt.xml` failed with `plugin mujoco.sdf.nut not found`, confirming that plugin loading is the practical trap to fix.

## Target Plugin

Public plugin name:

```text
mujoco.sdf.brick
```

Attributes:

```cpp
struct LegoBrickAttribute {
  static constexpr int nattribute = 3;
  static constexpr char const* names[nattribute] = {
      "stud_x", "stud_y", "height"
  };
  static constexpr mjtNum defaults[nattribute] = {
      4, 2, 3
  };
};
```

Height mapping:

```text
height = 1 -> plate        -> 3.2 mm
height = 2 -> double plate -> 6.4 mm
height = 3 -> brick        -> 9.6 mm
```

## Geometry Notes

- MuJoCo SDF callbacks receive query points in meters. Convert to millimeters internally and return meters.
- Stud pitch: `8.0 mm`.
- Body size: `x = 8*stud_x - 0.2`, `z = 8*stud_y - 0.2`, `y = 3.2*height` mm.
- Top studs: cylinders, radius `2.4 mm`, height `1.8 mm`, centered on the stud grid.
- Body: rounded outer box with a small `0.1 mm` radius.
- Hollow underside: subtract an inner box with about `1.2 mm` wall thickness and `1.2 mm` top thickness.
- Bottom tubes: if `stud_x > 1 && stud_y > 1`, add hollow vertical tubes centered between adjacent studs; outer radius `6.51/2 mm`, inner radius `4.8/2 mm`.
- The Shadertoy render-only parts should be omitted: lettering, textures, ray marching, motion/time, tiled scene bounds, camera math, materials, lighting, and ambient visibility.

## Core SDF Helpers

Use conventional signed-distance primitives:

```text
sdBox(point, half) = length(max(abs(point)-half,0)) + min(maxComponent(abs(point)-half),0)
sdRoundBox(point, half, radius) = sdBox(point, half-radius) - radius
sdCylinderY(point, radius, halfHeight) = max(length(point.xz)-radius, abs(point.y)-halfHeight)
sdTubeY(point, outerRadius, innerRadius, halfHeight) = max(max(length(point.xz)-outerRadius, innerRadius-length(point.xz)), abs(point.y)-halfHeight)
```

Nearest grid coordinate:

```text
first = -0.5 * (count - 1) * pitch
index = clamp(round((value - first) / pitch), 0, count - 1)
coord = first + index * pitch
```

## Distance Algorithm

1. Convert the MuJoCo point from meters to millimeters.
2. Sanitize attributes: `stud_x >= 1`, `stud_y >= 1`, and `height` clamped to `[1, 3]`.
3. Compute `body = max(outerRoundedBox, -innerCavityBox)`.
4. Compute top stud distance using the nearest clamped stud center.
5. Set `shape = min(body, topStudCylinder)`.
6. If the tube grid exists, compute nearest bottom tube ring and union it with `shape`.
7. Return `shape * 0.001`.

Finite-difference gradients are acceptable for the first implementation:

```cpp
void LegoBrick::Gradient(mjtNum gradient[3], const mjtNum point[3]) const {
  constexpr mjtNum eps = 1e-6;

  for (int axis = 0; axis < 3; ++axis) {
    mjtNum plus[3] = {point[0], point[1], point[2]};
    mjtNum minus[3] = {point[0], point[1], point[2]};
    plus[axis] += eps;
    minus[axis] -= eps;
    gradient[axis] = (Distance(plus) - Distance(minus)) / (2 * eps);
  }
}
```

## AABB Callback

MuJoCo expects `[center_x, center_y, center_z, half_x, half_y, half_z]` in local coordinates. The brick body is centered around local `y = 0` and the studs extend upward, so:

- `center_y = studHeight / 2` in meters.
- `half_y = (bodyHeight + studHeight) / 2` in meters.
- `half_x` and `half_z` are body half extents plus a small margin.

## MJCF Usage Draft

```xml
<extension>
  <plugin plugin="mujoco.sdf.brick">
    <instance name="brick_2x4">
      <config key="stud_x" value="4"/>
      <config key="stud_y" value="2"/>
      <config key="height" value="3"/>
    </instance>
  </plugin>
</extension>

<asset>
  <mesh name="brick_2x4">
    <plugin instance="brick_2x4"/>
  </mesh>
</asset>

<worldbody>
  <body>
    <geom type="sdf" mesh="brick_2x4" rgba="0.8 0.05 0.03 1">
      <plugin instance="brick_2x4"/>
    </geom>
  </body>
</worldbody>
```

## Implementation Plan

1. Create a separate out-of-tree plugin folder for `brick_sdf` rather than replacing DeepMind's stock `sdf_plugin`.
2. Add `brick_shape.h`, `brick_shape.cc`, `register.cc`, and `CMakeLists.txt`.
3. Register with `mjPLUGIN_LIB_INIT(brick_sdf) { BrickShape::RegisterPlugin(); }` for the MuJoCo 3.7/3.8 plugin ABI.
4. Build against `lib/win64/mujoco`, `lib/linux-x86_64/mujoco`, and `lib/linux-aarch64/mujoco`.
5. Copy artifacts to:

```text
lib/win64/mujoco/bin/mujoco_plugin/brick_sdf.dll
lib/linux-x86_64/mujoco/bin/mujoco_plugin/libbrick_sdf.so
lib/linux-aarch64/mujoco/bin/mujoco_plugin/libbrick_sdf.so
```

6. Add plugin loading before every XML parse path that should support SDF XMLs, especially the main MuJoCo wrapper before `mj_loadXML`.
7. Validate plugin loading with the stock `nutbolt.xml`, then validate `mujoco.sdf.brick` with a simple 2x4 brick MJCF.
