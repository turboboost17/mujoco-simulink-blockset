import argparse
import json
import os
from pathlib import Path

import mujoco
import numpy as np
from OpenGL import GL
from PIL import Image


KNOWN_GOOD_XML = """
<mujoco>
  <visual><global offwidth="320" offheight="240"/></visual>
  <worldbody>
    <light pos="0 0 3"/>
    <geom type="plane" size="3 3 .1" rgba=".2 .3 .4 1"/>
    <body pos="0 0 .4">
      <freejoint/>
      <geom type="box" size=".2 .2 .2" rgba="1 .1 .1 1"/>
    </body>
  </worldbody>
</mujoco>
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path)
    parser.add_argument("--camera", default="-1")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--frames", type=int, default=5)
    args = parser.parse_args()
    if args.frames < 4:
        parser.error("At least four frames are required, including startup.")

    args.output.mkdir(parents=True, exist_ok=True)
    model = (
        mujoco.MjModel.from_xml_path(str(args.model))
        if args.model
        else mujoco.MjModel.from_xml_string(KNOWN_GOOD_XML)
    )
    data = mujoco.MjData(model)
    mujoco.mj_forward(model, data)
    camera = (
        int(args.camera)
        if args.camera.lstrip("-").isdigit()
        else args.camera
    )
    summary = {
        "mujocoVersion": mujoco.__version__,
        "backend": os.environ.get("MUJOCO_GL", "glfw"),
        "display": os.environ.get("DISPLAY", ""),
        "model": str(args.model) if args.model else "known_good",
        "camera": camera,
        "frames": [],
    }
    with mujoco.Renderer(model, height=240, width=320) as renderer:
        for frame_index in range(1, args.frames + 1):
            for _ in range(20):
                mujoco.mj_step(model, data)
            renderer.update_scene(data, camera=camera)
            pixels = renderer.render()
            stem = f"frame_{frame_index:04d}"
            np.save(args.output / f"{stem}.npy", pixels)
            Image.fromarray(pixels).save(args.output / f"{stem}.png")
            summary["frames"].append({
                "index": frame_index,
                "time": float(data.time),
                "shape": list(pixels.shape),
                "min": int(pixels.min()),
                "max": int(pixels.max()),
                "std": float(pixels.std()),
                "isNonconstant": bool(pixels.min() != pixels.max()),
            })
        for name, query in (
            ("glVendor", GL.GL_VENDOR),
            ("glRenderer", GL.GL_RENDERER),
            ("glVersion", GL.GL_VERSION),
        ):
            value = GL.glGetString(query)
            summary[name] = value.decode("ascii", errors="replace") if value else ""

    summary["passed"] = all(
        frame["isNonconstant"] for frame in summary["frames"][1:]
    )
    (args.output / "capture_info.json").write_text(
        json.dumps(summary, indent=2), encoding="ascii"
    )
    print(json.dumps(summary, indent=2), flush=True)
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())