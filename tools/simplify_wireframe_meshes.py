#!/usr/bin/env python3
"""Create reduced-detail STL derivatives for the runtime wireframe GIFs.

Needs Python VTK. Original attributed source STLs remain unchanged.
Run this before rebuilding the headset and controller GIFs.
"""
from pathlib import Path

from vtkmodules.vtkFiltersCore import vtkQuadricDecimation
from vtkmodules.vtkIOGeometry import vtkSTLReader, vtkSTLWriter


ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "assets/models"
TARGET_REDUCTION = 0.95
SOURCES = (
    "vr-headset.stl",
    "quest3-controller-left.stl",
    "quest3-controller-right.stl",
)


def simplify(source: Path, destination: Path) -> None:
    reader = vtkSTLReader()
    reader.SetFileName(str(source))
    reader.Update()
    source_faces = reader.GetOutput().GetNumberOfCells()

    decimator = vtkQuadricDecimation()
    decimator.SetInputConnection(reader.GetOutputPort())
    decimator.SetTargetReduction(TARGET_REDUCTION)
    decimator.VolumePreservationOn()
    decimator.AttributeErrorMetricOff()
    decimator.Update()
    mesh = decimator.GetOutput()

    writer = vtkSTLWriter()
    writer.SetFileName(str(destination))
    writer.SetFileTypeToBinary()
    writer.SetInputData(mesh)
    if not writer.Write():
        raise SystemExit(f"Failed to write {destination}")

    print(f"{source.name}: {source_faces:,} → {mesh.GetNumberOfCells():,} triangles ({destination.name})")


def main() -> None:
    for name in SOURCES:
        source = MODELS / name
        destination = MODELS / f"{source.stem}-wireframe.stl"
        simplify(source, destination)


if __name__ == "__main__":
    main()
