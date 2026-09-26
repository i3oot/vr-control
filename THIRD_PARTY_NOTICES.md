# Third-Party Notices

This file records the external software and artwork used by the Omarchy VR
Control plugin, with the upstream project and license information.

## Plugin

The plugin manifest declares the plugin code as MIT licensed. See
[`manifest.json`](manifest.json).

## Bundled artwork

| Item | Use | Source | License |
| --- | --- | --- | --- |
| `assets/icons/vr.svg` | Bar icon and Nerd Fonts `nf-cod-vr` (`U+EC18`) equivalent | [Microsoft vscode-codicons `vr.svg`](https://github.com/microsoft/vscode-codicons/blob/main/src/icons/vr.svg) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); attribution: Microsoft, [Codicons](https://github.com/microsoft/vscode-codicons) |
| `assets/models/vr-headset-source.glb` | Source Meta Quest 3 model | [“Meta Quest 3” by Elin (@ElinHohler) on Sketchfab](https://sketchfab.com/3d-models/meta-quest-3-65a813833dc04eeeb7d33bdca58c184c) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/models/vr-headset.stl` | Centered full-detail mesh (76,260 triangles) | Derived from [“Meta Quest 3” by Elin](https://sketchfab.com/3d-models/meta-quest-3-65a813833dc04eeeb7d33bdca58c184c) by [`tools/convert_quest_mesh.py`](tools/convert_quest_mesh.py) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/models/vr-headset-wireframe.stl` | Reduced-density wireframe mesh (19,064 triangles) | Derived from `vr-headset.stl` by [`tools/simplify_wireframe_meshes.py`](tools/simplify_wireframe_meshes.py) using VTK quadric decimation | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/models/retro-vr-headset.scad` | Reduced-density mesh import and vertical Y-axis turntable scene | Generated from the simplified mesh by [`tools/build_headset_gif.py`](tools/build_headset_gif.py) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/icons/headset-turntable.gif` | 360° wireframe render used in the panel header (256×192) | Rendered from the OpenSCAD scene | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); attribution below |
| `assets/models/quest3-controller-source.glb` | Source Quest 3 headset, strap, and Touch Plus controllers | [“Oculus Quest 3” by AVILOV on Sketchfab](https://sketchfab.com/3d-models/oculus-quest-3-f4b794fc21784cd2a78392af05e0b597) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/models/quest3-controller-left.stl`, `quest3-controller-right.stl` | Centered full-detail left/right controllers (16,358 and 14,734 triangles) | Extracted from the AVILOV model by [`tools/convert_quest_controllers.py`](tools/convert_quest_controllers.py) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/models/quest3-controller-left-wireframe.stl`, `quest3-controller-right-wireframe.stl` | Reduced-density wireframe meshes (4,088 and 3,683 triangles) | Derived from the full-detail meshes by [`tools/simplify_wireframe_meshes.py`](tools/simplify_wireframe_meshes.py) using VTK quadric decimation | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/models/retro-quest3-controller-left.scad`, `retro-quest3-controller-right.scad` | Reduced-density mesh imports and vertical Y-axis turntable scenes | Generated from the simplified meshes by [`tools/build_controller_gifs.py`](tools/build_controller_gifs.py) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `assets/icons/controller-left-turntable.gif`, `controller-right-turntable.gif` | Separate 360° wireframe renders used in the panel header (256×192 each) | Rendered from the OpenSCAD scenes | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); attribution below |

The VR icon is distributed under Creative Commons Attribution 4.0
International. The original SVG is bundled locally so the bar does not depend
on Nerd Font coverage.

The headset asset is “Meta Quest 3” by Elin (@ElinHohler), available from
Sketchfab under CC BY 4.0. All 76,260 source triangles remain in the bundled
full-detail mesh. The runtime wireframe uses a 19,064-triangle derivative made
with VTK quadric decimation. The OpenSCAD scene and animated GIF are derivatives
and retain the source attribution. The panel applies the active Omarchy accent
color at runtime.

The controller assets are “Oculus Quest 3” by AVILOV, available from Sketchfab
under CC BY 4.0. The left and right Touch Plus controllers are extracted from
the source scene's detached controller geometry. All 31,092 source triangles
remain in the full-detail meshes. The runtime wireframes use reduced derivatives
with 4,088 and 3,683 triangles, made with VTK quadric decimation. The OpenSCAD
scenes and animated GIFs are derivatives and retain this attribution. The
panel applies the active Omarchy accent color at runtime.

## Setup software

The setup action installs these packages on the host. Package versions are
resolved by the configured Arch/AUR repositories at install time.

| Package | Role | Upstream | License |
| --- | --- | --- | --- |
| `wivrn-dashboard` | WiVRn pairing and server UI | [WiVRn/WiVRn](https://github.com/WiVRn/WiVRn) · [AUR package](https://aur.archlinux.org/packages/wivrn-dashboard) | GPL-3.0-or-later |
| `wivrn-server` | WiVRn streaming service; dependency of `wivrn-dashboard` | [WiVRn/WiVRn](https://github.com/WiVRn/WiVRn) · [AUR package](https://aur.archlinux.org/packages/wivrn-server) | GPL-3.0-or-later |
| `wayvr` | Desktop overlay for VR | [wayvr-org/wayvr](https://github.com/wayvr-org/wayvr) · [AUR package](https://aur.archlinux.org/packages/wayvr) | GPL-3.0-or-later |
| `xrizer` | OpenVR-to-OpenXR runtime for OpenVR games | [Supreeeme/xrizer](https://github.com/Supreeeme/xrizer) · [AUR package](https://aur.archlinux.org/packages/xrizer) | GPL-3.0-or-later |
| `avahi` | Local network discovery for headset pairing | [avahi/avahi](https://github.com/avahi/avahi) · [Arch package](https://archlinux.org/packages/extra/x86_64/avahi/) | LGPL-2.1-or-later |

The WiVRn, WayVR, and XRizer license identifiers above match upstream package
metadata. Each upstream project includes its corresponding license text. Avahi
is installed from the Arch repositories through `omarchy pkg add avahi`.
