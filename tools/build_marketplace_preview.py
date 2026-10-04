#!/usr/bin/env python3
"""Compose the marketplace preview from the existing mock-state screenshots."""

import base64
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def image(path, mime, x, y, width, height):
    data = base64.b64encode(path.read_bytes()).decode("ascii")
    return (
        f'<image href="data:{mime};base64,{data}" x="{x}" y="{y}" '
        f'width="{width}" height="{height}"/>'
    )


def main():
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="800" viewBox="0 0 1440 800">',
        '<rect width="1440" height="800" fill="#0b0c16"/>',
        image(ROOT / "assets/icons/vr.svg", "image/svg+xml", 48, 32, 42, 42),
        '<g font-family="monospace" fill="#e4e8ed">',
        '<text x="110" y="65" font-size="30" font-weight="700">VR Control</text>',
        '<text x="48" y="104" font-size="17" fill="#91a4bb">Omarchy workspaces in virtual reality · WiVRn + WayVR</text>',
    ]
    panels = [
        (48, "1 · Prepare this PC", "guide-page-1-prepare.png", 355),
        (510, "2 · Connect the headset", "guide-page-2-pair.png", 354),
        (972, "3 · Connection &amp; displays", "guide-page-3-connection.png", 508),
    ]
    for x, title, filename, height in panels:
        parts.append(f'<text x="{x}" y="150" font-size="17" fill="#6dd185">{title}</text>')
        parts.append(image(ROOT / "screenshots" / filename, "image/png", x, 176, 420, height))
    parts.extend([
        '<text x="48" y="751" font-size="15" fill="#91a4bb">Rendered example states · pairing code is illustrative · artwork credits in THIRD_PARTY_NOTICES.md</text>',
        '</g></svg>',
    ])
    with tempfile.TemporaryDirectory(prefix="vr-marketplace-preview-") as directory:
        source = Path(directory) / "preview.svg"
        source.write_text("\n".join(parts))
        subprocess.run(["rsvg-convert", "-o", str(ROOT / "preview.png"), str(source)], check=True)


if __name__ == "__main__":
    main()
