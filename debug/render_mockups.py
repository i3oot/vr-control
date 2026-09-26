#!/usr/bin/env python3
"""Render static SVG UX state mockups using the plugin's current palette."""

from html import escape
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent / "mockups"
OUT.mkdir(parents=True, exist_ok=True)

BG = "#080511"
PANEL = "#0d0a19"
CARD = "#141022"
LINE = "#38264e"
FG = "#f5edff"
MUTED = "#a497b5"
ACCENT = "#ff54d8"
CYAN = "#73eaff"
GOOD = "#73eaff"
WARN = "#ffd27a"
RED = "#ff779d"

WIDTH, HEIGHT = 500, 760
parts = []
frame_height = HEIGHT


def rect(x, y, w, h, radius, fill, stroke=None, sw=1):
    stroke = stroke or fill
    parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')


def text(x, y, value, size=13, color=FG, weight=400, family="Inter, sans-serif", letter=0):
    parts.append(f'<text x="{x}" y="{y}" fill="{color}" font-family="{family}" font-size="{size}" font-weight="{weight}" letter-spacing="{letter}">{escape(value)}</text>')


def multiline(x, y, values, size=12, color=MUTED, leading=17, weight=400):
    for index, value in enumerate(values):
        text(x, y + index * leading, value, size, color, weight)


def button(x, y, label, primary=False, danger=False, width=None):
    width = width or max(76, len(label) * 6.4 + 24)
    fill = "#ff54d824" if primary else "#ff54d80b"
    stroke = "#ff54d880" if primary else "#ff54d82a"
    color = ACCENT if primary else (RED if danger else FG)
    rect(x, y, width, 32, 9, fill, stroke)
    text(x + width / 2, y + 21, label, 11, color, 600, family="Inter, sans-serif")
    parts[-1] = parts[-1].replace(f'x="{x + width / 2}"', f'x="{x + width / 2}" text-anchor="middle"')
    return width


def card(y, height, icon, title, detail, status="warn", lines=None, buttons=None, code=None, images=False):
    x, w = 26, 448
    rect(x, y, w, height, 13, "url(#cardFill)", "#ff54d82c")
    rect(x + 1, y + 14, 2, height - 28, 1, "url(#neonLine)")
    text(x + 16, y + 27, icon, 19, ACCENT, 600)
    text(x + 47, y + 25, title, 14, FG, 650)
    dot_color = GOOD if status == "good" else (WARN if status == "warn" else MUTED)
    rect(x + w - 21, y + 18, 8, 8, 4, dot_color)
    text(x + 47, y + 45, detail, 11, MUTED)
    body_y = y + 66
    if lines:
        for index, (left, right) in enumerate(lines):
            text(x + 47, body_y + index * 17, left, 11, MUTED)
            text(x + w - 16, body_y + index * 17, right, 11, FG, 500)
            parts[-1] = parts[-1].replace(f'x="{x + w - 16}"', f'x="{x + w - 16}" text-anchor="end"')
        body_y += len(lines) * 17 + 5
    if buttons:
        bx = x + 47
        for label, primary, danger, bwidth in buttons:
            bx += button(bx, body_y, label, primary, danger, bwidth) + 8
        body_y += 42
    if code:
        rect(x + 47, body_y - 2, w - 63, 61, 10, "#ff54d812", "#73eaff62")
        text(x + w / 2 + 8, body_y + 14, "EXAMPLE CODE · MOCKUP ONLY", 9, MUTED, 700, letter=1)
        parts[-1] = parts[-1].replace(f'x="{x + w / 2 + 8}"', f'x="{x + w / 2 + 8}" text-anchor="middle"')
        text(x + w / 2 + 8, body_y + 48, code, 27, ACCENT, 700, family="monospace", letter=5)
        parts[-1] = parts[-1].replace(f'x="{x + w / 2 + 8}"', f'x="{x + w / 2 + 8}" text-anchor="middle"')
        body_y += 69
    if images:
        art_x, art_y, art_w, art_h = x + 48, body_y - 2, w - 64, 65
        rect(art_x, art_y, art_w, art_h, 10, "#73eaff0a", "#73eaff52")
        asset_names = ["headset-turntable", "controller-left-turntable", "controller-right-turntable"]
        image_width = 86
        for index, asset in enumerate(asset_names):
            source = ROOT / "assets" / "icons" / f"{asset}.gif"
            frame_path = OUT / f"{asset}.png"
            subprocess.run([
                "magick", f"{source}[0]", "-fill", CYAN,
                "-colorize", "62%", str(frame_path)
            ], check=True)
            ix = art_x + 23 + index * 104
            parts.append(f'<image href="{asset}.png" x="{ix}" y="{art_y + 4}" width="{image_width}" height="56" preserveAspectRatio="xMidYMid meet" opacity="0.88"/>')
        body_y += 72


def step(y, number, title, state, done=False):
    fill = "#ff54d824" if done else "#ff54d80a"
    stroke = ACCENT if done else "#ff54d85e"
    rect(28, y, 27, 27, 14, fill, stroke)
    text(41.5, y + 18, number, 12, FG, 700)
    parts[-1] = parts[-1].replace('font-weight="700"', 'font-weight="700" text-anchor="middle"')
    text(65, y + 14, title, 14, FG, 700)
    text(65, y + 30, state, 10, ACCENT if done else MUTED, 500)


def stage_nav(y, number, live=None):
    button(42, y, "‹ Back", width=88)
    text(250, y + 20, f"STEP {number} OF 3" if live is None else f"BROWSING · LIVE STEP {live}", 9, ACCENT if live else MUTED, 700, letter=0.8)
    parts[-1] = parts[-1].replace('x="250"', 'x="250" text-anchor="middle"')
    button(370, y, "Next ›", width=88)
    rect(42, y + 37, 416, 2, 1, "#ffffff18")
    width = 416 / 3
    rect(42 + (number - 1) * width, y + 36, width - 3, 4, 2, ACCENT)


def start(title, guided=True, height=HEIGHT):
    global frame_height
    frame_height = height
    parts.clear()
    parts.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{height}" viewBox="0 0 {WIDTH} {height}">')
    parts.append('<defs><linearGradient id="panelFill" x1="0" y1="0" x2="0.9" y2="1"><stop offset="0" stop-color="#100c20"/><stop offset="1" stop-color="#0b0917"/></linearGradient><linearGradient id="cardFill" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#171027"/><stop offset="1" stop-color="#110e20"/></linearGradient><linearGradient id="neonLine" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff54d8"/><stop offset="1" stop-color="#73eaff"/></linearGradient></defs>')
    rect(0, 0, WIDTH, height, 0, BG)
    text(26, 23, f"UX STATE MOCKUP  /  {title.upper()}", 9, MUTED, 700, letter=1.2)
    rect(16, 39, 468, height - 55, 18, "url(#panelFill)", "#49325c")
    text(37, 77, "VR Control", 19, FG, 700)
    text(37, 98, "WiVRn streaming · WayVR desktop", 11, MUTED)
    rect(399, 55, 32, 32, 9, "#ffffff0a", "#ffffff25")
    text(415, 76, "i", 17, FG, 500)
    parts[-1] = parts[-1].replace('x="415"', 'x="415" text-anchor="middle"')
    rect(439, 55, 32, 32, 9, "#ffffff0a", "#ffffff25")
    text(455, 76, "↻", 16, FG, 500)
    parts[-1] = parts[-1].replace('x="455"', 'x="455" text-anchor="middle"')
    rect(37, 116, 426, 2, 1, "url(#neonLine)")
    if guided:
        text(37, 145, "GUIDED SETUP", 10, MUTED, 700, letter=1.2)


def save(name):
    parts.append("</svg>")
    svg_path = OUT / f"{name}.svg"
    png_path = OUT / f"{name}.png"
    svg_path.write_text("\n".join(parts), encoding="utf-8")
    subprocess.run(["rsvg-convert", "-o", str(png_path), str(svg_path)], check=True)


def screen_missing():
    start("PC setup missing", height=680)
    step(161, "1", "Prepare this PC", "Needs attention")
    stage_nav(198, 1)
    card(245, 96, "◉", "WiVRn server", "Not installed · setup can install it", "warn", buttons=[("Install VR stack", True, False, 123)])
    card(353, 137, "⌘", "Components & discovery", "Some components still need setup", "warn", lines=[("WayVR", "Missing"), ("XRizer", "Missing"), ("Avahi discovery", "Not running")])
    card(502, 103, "⛨", "WiVRn firewall", "UFW is not active · controls unavailable", "none", buttons=[("Unavailable", False, False, 94)])
    save("01-setup-missing")


def screen_ready(firewall_open):
    title = "PC ready · firewall open" if firewall_open else "PC ready · firewall closed"
    start(title, height=665)
    step(161, "1", "Prepare this PC", "Start WiVRn server")
    stage_nav(198, 1)
    card(245, 88, "◉", "WiVRn server", "Installed · ready to start", "warn", buttons=[("Start server", True, False, 94), ("Dashboard", False, False, 83)])
    card(345, 128, "⌘", "Components & discovery", "Required packages and Avahi are ready", "good", lines=[("WayVR", "Installed"), ("XRizer", "Installed"), ("Avahi discovery", "Running")])
    card(485, 110, "⛨", "WiVRn firewall", "Open · private LAN only · 5353 / 9757" if firewall_open else "No plugin rules · existing rules may still allow traffic", "good" if firewall_open else "warn", buttons=[("Open ports", True, False, 94), ("Close plugin rules", False, True, 132)])
    save("03-pc-ready-firewall-open" if firewall_open else "02-pc-ready-firewall-closed")


def screen_pairing():
    start("pairing code", height=520)
    step(161, "2", "Connect the headset", "Pairing enabled · temporary PIN")
    stage_nav(198, 2)
    card(245, 237, "◉", "Pair your headset", "Open WiVRn on the headset and enter this code", "warn", buttons=[("Get pairing code", True, False, 124), ("Install app ↗", False, False, 116)], code="482 913")
    save("04-pairing-code")


def screen_connected():
    start("headset connected", height=610)
    step(161, "3", "Start the VR desktop", "Ready")
    stage_nav(198, 3)
    card(245, 177, "◉", "Headset connected", "Quest 3", "good", images=True)
    card(440, 101, "▣", "WayVR desktop", "Installed · ready to launch", "warn", buttons=[("Launch WayVR", True, False, 112)])
    save("05-headset-connected")


def screen_about():
    start("about and licenses", guided=False, height=710)
    text(37, 145, "ABOUT VR CONTROL", 10, MUTED, 700, letter=1.2)
    card(161, 88, "♙", "Maintainer", "i3oot · Omarchy VR Control · MIT", "good")
    card(263, 203, "▦", "Required VR stack", "Dependencies and license identifiers", "good", lines=[("WiVRn server + dashboard", "GPL-3.0-or-later"), ("WayVR", "GPL-3.0-or-later"), ("XRizer", "GPL-3.0-or-later"), ("Avahi", "LGPL-2.1-or-later")])
    card(482, 161, "◇", "Bundled artwork", "Quest 3 wireframes and Codicons icon", "good", lines=[("Headset + controllers", "CC BY 4.0"), ("VR icon", "CC BY 4.0")], buttons=[("Sources & license notes ↗", True, False, 182)])
    save("06-about-licenses")


def screen_manual_navigation():
    start("manual guide navigation", height=720)
    step(161, "1", "Prepare this PC", "Browsing an earlier step")
    stage_nav(198, 1, live=3)
    card(245, 88, "◉", "WiVRn server", "Running · headset connected", "good", buttons=[("Dashboard", False, False, 83), ("Disable autostart", False, False, 128)])
    card(345, 128, "⌘", "Components & discovery", "All required components are ready", "good", lines=[("WayVR", "Installed"), ("XRizer", "Installed"), ("Avahi discovery", "Running")])
    card(485, 110, "⛨", "WiVRn firewall", "LAN rules configured", "good", buttons=[("Open ports", False, False, 94), ("Close plugin rules", False, True, 132)])
    button(73, 625, "Return to current step · 3", True, width=354)
    save("07-manual-navigation")


screen_missing()
screen_ready(False)
screen_ready(True)
screen_pairing()
screen_connected()
screen_about()
screen_manual_navigation()
