#!/usr/bin/env python3
"""Render reduced-density Touch Plus controller meshes as separate GIFs.

Needs OpenSCAD and ffmpeg. First run `python3 tools/simplify_wireframe_meshes.py`.
"""
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRAMES, FPS = 48, 12
MODEL_SCALE = 3.4
START_ANGLE = 90
CAMERA_DISTANCE = 1.5


def stl_center(path):
    data = path.read_bytes()
    count = struct.unpack_from("<I", data, 80)[0]
    if len(data) != 84 + count * 50:
        raise ValueError(f"Not a binary STL: {path}")
    mins, maxs = [float("inf")] * 3, [float("-inf")] * 3
    for offset in range(84, len(data), 50):
        for vertex in range(3):
            point = struct.unpack_from("<3f", data, offset + 12 + vertex * 12)
            for axis, value in enumerate(point):
                mins[axis] = min(mins[axis], value)
                maxs[axis] = max(maxs[axis], value)
    return [(mins[i] + maxs[i]) / 2 for i in range(3)], count


def render_one(side, openscad, ffmpeg):
    source = ROOT / f"assets/models/quest3-controller-{side}-wireframe.stl"
    scene = ROOT / f"assets/models/retro-quest3-controller-{side}.scad"
    destination = ROOT / f"assets/icons/controller-{side}-turntable.gif"
    center, face_count = stl_center(source)
    cx, cy, cz = center
    scene.write_text(f'''// Reduced wireframe derivative of the Meta Touch Plus {side} controller by AVILOV, CC BY 4.0.
// Source model and license information: THIRD_PARTY_NOTICES.md.
// Rotate around the vertical Y axis.
rotate([0, 360*$t+{START_ANGLE}, 0])
  rotate([-90, 0, 0])
  scale({MODEL_SCALE})
    translate([{-cx:.8f}, {-cy:.8f}, {-cz:.8f}])
      import("quest3-controller-{side}-wireframe.stl", convexity=10);
''')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f"omarchy-vr-{side}-") as temp_dir:
        temp = Path(temp_dir)
        subprocess.run([
            openscad, "--quiet", f"--animate={FRAMES}",
            f"--camera=0,0,{CAMERA_DISTANCE},0,0,0", "--projection=p",
            "--view=edges", "--colorscheme=Tomorrow Night", "--imgsize=384,288",
            "-o", str(temp / "turn.png"), str(scene),
        ], check=True, stdout=subprocess.DEVNULL)
        key_filter = (
            "colorkey=0xC0D0DE:0.19:0.04,"
            "colorkey=0x1D1F21:0.14:0.04,"
            "scale=256:192:flags=lanczos,format=rgba"
        )
        subprocess.run([
            ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
            "-framerate", str(FPS), "-i", str(temp / "turn%05d.png"),
            "-vf", f"{key_filter},palettegen=reserve_transparent=on:transparency_color=000000",
            str(temp / "palette.png"),
        ], check=True)
        subprocess.run([
            ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
            "-framerate", str(FPS), "-i", str(temp / "turn%05d.png"),
            "-i", str(temp / "palette.png"),
            "-lavfi", f"{key_filter}[x];[x][1:v]paletteuse=alpha_threshold=96",
            "-loop", "0", str(destination),
        ], check=True)
    print(f"{destination} ({face_count:,} reduced-detail triangles)")


def main():
    openscad, ffmpeg = shutil.which("openscad"), shutil.which("ffmpeg")
    if not openscad or not ffmpeg:
        raise SystemExit("This renderer needs OpenSCAD and ffmpeg on PATH.")
    for side in ("left", "right"):
        render_one(side, openscad, ffmpeg)


if __name__ == "__main__":
    main()
