#!/usr/bin/env python3
"""Render README guide-page previews from fixed mock states.

These are static UI previews, not captures of a live headset or PC state.
"""

from html import escape
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
MOCKUPS = Path(__file__).resolve().parent / "mockups"
OUTPUT = ROOT / "screenshots"
MOCKUPS.mkdir(parents=True, exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)

BG = "#0b0c16"
SURFACE = "#11151e"
SURFACE_HOVER = "#17221f"
FG = "#e4e8ed"
SECONDARY = "#91a4bb"
ACCENT = "#6dd185"
WARN = "#e7bf69"
NEGATIVE = "#fa777c"
LINE = "#29333c"
FONT = "monospace"
WIDTH = 420

parts = []


def rect(x, y, w, h, r=0, fill="none", stroke="none", sw=1):
    parts.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" '
        f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
    )


def line(x1, y1, x2, y2, color=LINE, sw=1):
    parts.append(
        f'<path d="M{x1} {y1}H{x2}" fill="none" stroke="{color}" stroke-width="{sw}"/>'
    )


def text(x, y, value, size=12, color=FG, weight=400, anchor="start", letter=0):
    parts.append(
        f'<text x="{x}" y="{y}" fill="{color}" font-family="{FONT}" '
        f'font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" '
        f'letter-spacing="{letter}">{escape(value)}</text>'
    )


def button(x, y, w, label, primary=False, h=34):
    fill = SURFACE_HOVER if primary else "#10131b"
    stroke = "#73b981" if primary else "#272f3b"
    rect(x, y, w, h, 10, fill, stroke, 1)
    text(x + w / 2, y + h / 2 + 4, label, 11, FG, 650, "middle")


def start(stage, subtitle, height):
    parts.clear()
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{height}" '
        f'viewBox="0 0 {WIDTH} {height}">'
    )
    rect(1, 1, WIDTH - 2, height - 2, 13, BG, ACCENT, 2)
    text(20, 31, "VR Control", 16, FG, 700)
    text(20, 51, subtitle, 11, SECONDARY, 450, letter=0.3)
    text(WIDTH - 20, 33, "≡", 17, FG, 600, "end")
    line(12, 65, WIDTH - 12, 65, ACCENT, 1.5)

    button(12, 80, 55, "‹ Back", primary=False)
    button(WIDTH - 67, 80, 55, "Next ›", primary=False)
    left, right, gap = 12, WIDTH - 12, 6
    seg = (right - left - gap * 2) / 3
    for index in range(3):
        color = ACCENT if index < stage - 1 else (FG if index == stage - 1 else "#30343d")
        rect(left + index * (seg + gap), 121, seg, 3, 2, color, color)


def save(name):
    parts.append("</svg>")
    svg_path = MOCKUPS / f"{name}.svg"
    png_path = OUTPUT / f"{name}.png"
    svg_path.write_text("\n".join(parts), encoding="utf-8")
    subprocess.run(["rsvg-convert", "-o", str(png_path), str(svg_path)], check=True)


def page_prepare():
    start(1, "Prepare this PC", 355)
    rows = [
        ("WiVRn", "READY", ACCENT),
        ("WayVR", "INACTIVE", WARN),
        ("Firewall", "PORT BLOCKED", NEGATIVE),
    ]
    top = 143
    for index, (title, status, color) in enumerate(rows):
        y = top + index * 51
        text(24, y + 22, title, 13, FG, 650)
        text(WIDTH - 39, y + 22, status, 10, color, 700, "end", 0.3)
        text(WIDTH - 20, y + 22, "+", 13, SECONDARY, 400, "end")
        if index < len(rows) - 1:
            line(16, y + 42, WIDTH - 16, y + 42, LINE, 1)
    button(14, 310, WIDTH - 28, "Configure software", True, 36)
    save("guide-page-1-prepare")


def page_pair():
    start(2, "Connect the headset", 354)
    text(20, 156, "Pair your headset", 13, FG, 700)
    text(20, 178, "Open WiVRn on the headset and enter the temporary", 10, SECONDARY)
    text(20, 194, "pairing code.", 10, SECONDARY)

    rect(14, 207, WIDTH - 28, 79, 12, "#13221d", "#42684d", 1)
    text(WIDTH / 2, 230, "PAIRING CODE · ENTER IN THE HEADSET", 10, SECONDARY, 650, "middle", 0.8)
    refresh_x, refresh_y = WIDTH - 45, 211
    rect(refresh_x, refresh_y, 28, 28, 8, SURFACE_HOVER, "#42684d", 1)
    parts.append(
        f'<path d="M17.65 6.35A7.95 7.95 0 0 0 12 4a8 8 0 1 0 7.93 9h-2.02A6 6 0 1 1 12 6c1.66 0 3.14.69 4.22 1.78L13 11h7V4z" '
        f'transform="translate({refresh_x + 4} {refresh_y + 4})" fill="{FG}"/>'
    )
    text(WIDTH / 2, 269, "133742", 25, ACCENT, 700, "middle", 3)

    button(14, 300, WIDTH - 28, "Install app on headset", True, 36)
    save("guide-page-2-pair")


def tinted_frame(source, frame, output, tint, trim=False):
    command = ["magick", f"{source}[{frame}]", "-coalesce"]
    if trim:
        command += ["-trim", "+repage"]
    command += ["-fill", tint, "-colorize", "62%", "-channel", "A",
                "-evaluate", "multiply", "0.68", "+channel", str(output)]
    subprocess.run(command, check=True)


def page_connection():
    headset_name = "Meta Quest 3"
    start(3, "Headset connected", 508)

    art_y = 140
    rect(14, art_y, WIDTH - 28, 110, 14, "#121922", "#42684d", 1)
    tile_y = art_y + 8
    rect(78, tile_y, 62, 94, 13, "#15231d", "#42684d", 1)
    rect(148, tile_y, 124, 94, 14, "#15231d", "#42684d", 1)
    rect(280, tile_y, 62, 94, 13, "#15231d", "#42684d", 1)

    icons = ROOT / "assets" / "icons"
    frames = [
        ("controller-right-turntable.gif", 13, "mock-left-controller.png", 97, 176, 24, 44, True),
        ("headset-turntable.gif", 46, "mock-headset.png", 164, 151, 93, 77, False),
        ("controller-left-turntable.gif", 13, "mock-right-controller.png", 299, 176, 24, 44, True),
    ]
    for source_name, frame, output_name, x, y, w, h, trim in frames:
        out = MOCKUPS / output_name
        tinted_frame(icons / source_name, frame, out, FG, trim=trim)
        parts.append(
            f'<image href="{output_name}" x="{x}" y="{y}" width="{w}" height="{h}" '
            'preserveAspectRatio="xMidYMid meet"/>'
        )
    text(109, 236, "L", 10, FG, 650, "middle")
    text(311, 236, "R", 10, FG, 650, "middle")
    text(WIDTH / 2, 270, f"Connected to {headset_name}", 9, SECONDARY, 400, "middle")

    rect(14, 286, WIDTH - 28, 205, 13, SURFACE, "#29343e", 1)
    text(28, 310, "VR displays", 12, FG, 700)
    text(28, 326, "Add virtual screens and route workspaces.", 9, SECONDARY)
    text(28, 357, "Virtual screens · 1 / 4", 10, FG, 500)
    button(347, 337, 27, "−", False, 30)
    button(378, 337, 27, "+", True, 30)

    line(26, 377, WIDTH - 26, 377, LINE, 1)
    text(28, 401, "eDP-1 · WS 1", 10, SECONDARY)
    button(309, 385, 92, "Move here", False, 30)
    line(26, 417, WIDTH - 26, 417, LINE, 1)
    text(28, 443, "VR-SCREEN-1 · WS 3", 10, SECONDARY)
    button(278, 427, 92, "Move here", False, 30)
    button(374, 427, 27, "×", False, 30)
    save("guide-page-3-connection")


page_prepare()
page_pair()
page_connection()
