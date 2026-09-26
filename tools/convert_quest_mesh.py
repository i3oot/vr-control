#!/usr/bin/env python3
"""Convert the attributed Sketchfab GLB to a centered binary STL.

Needs Assimp and Python VTK. The source triangle mesh is kept at full detail.
"""
import shutil
import subprocess
import tempfile
from pathlib import Path

from vtkmodules.vtkFiltersCore import vtkCleanPolyData
from vtkmodules.vtkIOGeometry import vtkOBJReader, vtkSTLWriter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models/vr-headset-source.glb"
DEST = ROOT / "assets/models/vr-headset.stl"


def main():
    assimp = shutil.which("assimp")
    if not assimp:
        raise SystemExit("Mesh conversion needs Assimp on PATH.")

    with tempfile.TemporaryDirectory(prefix="omarchy-vr-mesh-") as temp:
        obj_path = Path(temp) / "source.obj"
        subprocess.run([assimp, "export", str(SOURCE), str(obj_path)], check=True,
                       stdout=subprocess.DEVNULL)

        reader = vtkOBJReader()
        reader.SetFileName(str(obj_path))
        reader.Update()

        clean = vtkCleanPolyData()
        clean.SetInputConnection(reader.GetOutputPort())
        clean.SetToleranceIsAbsolute(True)
        clean.SetAbsoluteTolerance(1e-6)
        clean.Update()

        mesh = clean.GetOutput()
        DEST.parent.mkdir(parents=True, exist_ok=True)
        writer = vtkSTLWriter()
        writer.SetFileName(str(DEST))
        writer.SetInputData(mesh)
        writer.SetFileTypeToBinary()
        if not writer.Write():
            raise SystemExit(f"Failed to write {DEST}")

        print(f"{DEST} ({mesh.GetNumberOfPoints()} vertices, "
              f"{mesh.GetNumberOfCells()} full-detail faces)")


if __name__ == "__main__":
    main()
