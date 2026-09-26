#!/usr/bin/env python3
"""Extract the full-detail left and right Touch Plus controllers from a GLB."""
import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models/quest3-controller-source.glb"
DEST = ROOT / "assets/models"


def read_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError(f"Not a valid GLB 2.0 file: {path}")
    json_len, chunk_type = struct.unpack_from("<I4s", data, 12)
    if chunk_type != b"JSON":
        raise ValueError("GLB has no JSON chunk")
    document = json.loads(data[20:20 + json_len])
    offset = 20 + json_len
    binary_len, binary_type = struct.unpack_from("<I4s", data, offset)
    if binary_type != b"BIN\x00":
        raise ValueError("GLB has no binary chunk")
    return document, data[offset + 8:offset + 8 + binary_len]


def accessor_bytes(document, binary, index):
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return accessor, view, offset


def vector3_accessor(document, binary, index):
    accessor, view, offset = accessor_bytes(document, binary, index)
    stride = view.get("byteStride", 12)
    return [struct.unpack_from("<3f", binary, offset + i * stride)
            for i in range(accessor["count"])]


def scalar_accessor(document, binary, index):
    accessor, view, offset = accessor_bytes(document, binary, index)
    formats = {5121: "B", 5123: "H", 5125: "I"}
    code = formats[accessor["componentType"]]
    stride = view.get("byteStride", struct.calcsize(code))
    return [struct.unpack_from("<" + code, binary, offset + i * stride)[0]
            for i in range(accessor["count"])]


def write_stl(path, triangles):
    points = [point for triangle in triangles for point in triangle]
    center = [
        (min(point[axis] for point in points) + max(point[axis] for point in points)) / 2
        for axis in range(3)
    ]
    with path.open("wb") as output:
        output.write(b"Omarchy VR full-detail Touch Plus controller".ljust(80, b"\0"))
        output.write(struct.pack("<I", len(triangles)))
        for triangle in triangles:
            vertices = [tuple(v[i] - center[i] for i in range(3)) for v in triangle]
            a, b, c = vertices
            ab = tuple(b[i] - a[i] for i in range(3))
            ac = tuple(c[i] - a[i] for i in range(3))
            normal = (ab[1] * ac[2] - ab[2] * ac[1],
                      ab[2] * ac[0] - ab[0] * ac[2],
                      ab[0] * ac[1] - ab[1] * ac[0])
            length = math.sqrt(sum(n * n for n in normal)) or 1
            normal = tuple(n / length for n in normal)
            output.write(struct.pack("<3f", *normal))
            for vertex in vertices:
                output.write(struct.pack("<3f", *vertex))
            output.write(b"\0\0")
    return len(triangles)


def main():
    document, binary = read_glb(SOURCE)
    # Object_2 contains the detached controllers, each at one side of the headset.
    mesh = document["meshes"][2]["primitives"][0]
    positions = vector3_accessor(document, binary, mesh["attributes"]["POSITION"])
    indices = scalar_accessor(document, binary, mesh["indices"])
    # Sketchfab's root maps source x/z/-y onto the plugin's x/y/z axes.
    positions = [(x / 900, z / 900, -y / 900) for x, y, z in positions]
    by_side = {"left": [], "right": []}
    for offset in range(0, len(indices), 3):
        triangle = [positions[index] for index in indices[offset:offset + 3]]
        side = "left" if sum(point[0] for point in triangle) < 0 else "right"
        by_side[side].append(triangle)
    DEST.mkdir(parents=True, exist_ok=True)
    for side, triangles in by_side.items():
        count = write_stl(DEST / f"quest3-controller-{side}.stl", triangles)
        print(f"{side}: {count:,} full-detail triangles")


if __name__ == "__main__":
    main()
