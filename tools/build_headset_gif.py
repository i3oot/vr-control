#!/usr/bin/env python3
"""Render the reduced-density Y-up Quest 3 mesh as a wireframe turntable GIF.

Needs OpenSCAD and ffmpeg. First run `python3 tools/simplify_wireframe_meshes.py`.
Run from the plugin root:
  python3 tools/build_headset_gif.py
"""
import shutil
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models/vr-headset-wireframe.stl"
SCAD = ROOT / "assets/models/retro-vr-headset.scad"
DEST = ROOT / "assets/icons/headset-turntable.gif"
FRAMES, FPS = 48, 12
MODEL_SCALE = 3.4
START_ANGLE = 45  # Begin at the visor-forward three-quarter view.


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


def write_scene(center):
    cx, cy, cz = center
    SCAD.write_text(f'''// Reduced wireframe derivative of the Meta Quest 3 mesh by Elin (@ElinHohler), CC BY 4.0.
// Source: https://sketchfab.com/3d-models/meta-quest-3-65a813833dc04eeeb7d33bdca58c184c
// The source model is Y-up; its vertical top-to-bottom axis is Y.
// $t rotates around Y while the visor faces toward +Z.
rotate([0, 360*$t+{START_ANGLE}, 0])
  scale({MODEL_SCALE})
    translate([{-cx:.8f}, {-cy:.8f}, {-cz:.8f}])
      import("vr-headset-wireframe.stl", convexity=10);
''')


def main():
    openscad, ffmpeg = shutil.which("openscad"), shutil.which("ffmpeg")
    if not openscad or not ffmpeg:
        raise SystemExit("This renderer needs OpenSCAD and ffmpeg on PATH.")
    center, face_count = stl_center(SOURCE)
    write_scene(center)
    DEST.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="omarchy-vr-") as temp_dir:
        temp = Path(temp_dir)
        subprocess.run([
            openscad, "--quiet", f"--animate={FRAMES}",
            "--camera=0,0,4.3,0,0,0", "--projection=p",
            "--view=edges", "--colorscheme=Tomorrow Night", "--imgsize=384,288",
            "-o", str(temp / "turn.png"), str(SCAD),
        ], check=True, stdout=subprocess.DEVNULL)

        # Drop only the flat shaded fill and viewport background. The native
        # triangle edges remain as the complete, untampered wireframe.
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
            "-loop", "0", str(DEST),
        ], check=True)
    print(f"{DEST} ({face_count:,} reduced-detail triangles; vertical Y-axis rotation from {START_ANGLE}°)")


if __name__ == "__main__":
    main()
