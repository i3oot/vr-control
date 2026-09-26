# VR Control UX state mockups

The PNGs in `mockups/` are static UI mockups, not screenshots of live system
status. They use a compact synthwave palette. Each guided state shows one
step at a time, with Back/Next navigation. The panel returns to the live step
when reopened. The mockups do not change the running headset or firewall.

The README guide previews are generated separately from fixed mock states to
match the current three-page guide. Their package, pairing, and monitor values
are illustrative:

```sh
python3 debug/render_guide_screenshots.py
```

This writes `screenshots/guide-page-1-prepare.png`,
`screenshots/guide-page-2-pair.png`, and
`screenshots/guide-page-3-connection.png`.

Included states:

- `01-setup-missing.png` — missing packages and Avahi; UFW inactive.
- `02-pc-ready-firewall-closed.png` — PC ready; no plugin-tagged firewall rules.
- `03-pc-ready-firewall-open.png` — LAN-scoped WiVRn UFW rules present.
- `04-pairing-code.png` — temporary example PIN. The code is mock data only.
- `05-headset-connected.png` — headset connected; battery/controller telemetry
  unavailable through WiVRn's plugin control API.
- `06-about-licenses.png` — maintainer, dependencies, licenses, and sources.
- `07-manual-navigation.png` — reviewing PC setup while the live state is step 3.
- `contact-sheet.png` — all seven states together.

Regenerate the SVG and PNG mockups after changing their layout:

```sh
python3 debug/render_mockups.py
magick montage debug/mockups/0[1-7]-*.png -tile 4x2 -geometry 500x760+18+18 -background '#080910' debug/mockups/contact-sheet.png
```
