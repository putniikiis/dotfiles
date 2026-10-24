#!/usr/bin/env python3
"""Detect connected DRM outputs and suggest Niri output blocks.

Prints JSON to stdout for install.sh. Prefers portable connector names
(eDP-1, HDMI-A-1) over make/model strings.
"""
from __future__ import annotations

import json
import math
import os
import re
import subprocess
import sys
from pathlib import Path

DRM = Path("/sys/class/drm")


def read_text(path: Path) -> str:
    try:
        return path.read_text(errors="ignore").strip()
    except OSError:
        return ""


def connector_name(card_conn: str) -> str:
    # card1-HDMI-A-1 -> HDMI-A-1 ; card0-eDP-1 -> eDP-1
    return re.sub(r"^card\d+-", "", card_conn)


def parse_modes(modes_path: Path) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    seen: set[tuple[int, int]] = set()
    for line in read_text(modes_path).splitlines():
        m = re.match(r"^(\d+)x(\d+)", line.strip())
        if not m:
            continue
        pair = (int(m.group(1)), int(m.group(2)))
        if pair not in seen:
            seen.add(pair)
            out.append(pair)
    return out


def edid_info(edid_path: Path) -> dict:
    info: dict = {"name": "", "width_mm": 0, "height_mm": 0, "preferred": None}
    if not edid_path.is_file() or edid_path.stat().st_size == 0:
        return info
    try:
        proc = subprocess.run(
            ["edid-decode", str(edid_path)],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        text = proc.stdout + "\n" + proc.stderr
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        return info

    # Display product name
    m = re.search(r"Display Product Name:\s*'([^']+)'", text)
    if not m:
        m = re.search(r"Monitor name:\s*(.+)", text)
    if m:
        info["name"] = m.group(1).strip()

    m = re.search(r"Maximum image size:\s*(\d+)\s*cm\s*x\s*(\d+)\s*cm", text)
    if m:
        info["width_mm"] = int(m.group(1)) * 10
        info["height_mm"] = int(m.group(2)) * 10

    # Preferred timing: "2560x1440 143.998 Hz" or similar
    m = re.search(
        r"(?:Preferred|First detailed) timing[^\n]*\n\s*(\d+)x(\d+)\s+([\d.]+)\s*Hz",
        text,
        re.I,
    )
    if not m:
        m = re.search(r"Detailed mode:\s*(\d+)x(\d+).*?([\d.]+)\s*Hz", text, re.I | re.S)
    if m:
        info["preferred"] = {
            "w": int(m.group(1)),
            "h": int(m.group(2)),
            "hz": float(m.group(3)),
        }
    return info


def suggest_scale(w: int, h: int, width_mm: int, height_mm: int) -> float:
    if width_mm > 0 and height_mm > 0:
        diag = math.hypot(width_mm / 25.4, height_mm / 25.4)
        if diag > 0:
            ppi = math.hypot(w, h) / diag
            if ppi >= 180:
                return 2.0
            if ppi >= 160:
                return 1.6
            if ppi >= 140:
                return 1.5
            if ppi >= 120:
                return 1.25
            return 1.0
    # No physical size from EDID — only bump scale for dense laptop panels.
    if h >= 2160:
        return 2.0
    # 2.8K-class laptop panels (e.g. 2880×1800) usually want ~1.6
    if h >= 1800 and w >= 2880:
        return 1.6
    if h >= 1600 and w >= 2560:
        return 1.5
    return 1.0


def pick_mode(modes: list[tuple[int, int]], preferred: dict | None) -> tuple[int, int]:
    if preferred:
        pref = (preferred["w"], preferred["h"])
        if pref in modes:
            return pref
    if not modes:
        return (1920, 1080)
    # Prefer native-looking (largest area that is not exotic 4K on a QHD panel
    # when a mid resolution dominates). Take first (often preferred) else max area.
    return modes[0]


def detect() -> list[dict]:
    outputs: list[dict] = []
    if not DRM.is_dir():
        return outputs

    for entry in sorted(DRM.iterdir()):
        if not entry.name.startswith("card"):
            continue
        if "-" not in entry.name:
            continue
        status = read_text(entry / "status").lower()
        if status != "connected":
            continue
        name = connector_name(entry.name)
        modes = parse_modes(entry / "modes")
        edid = edid_info(entry / "edid")
        w, h = pick_mode(modes, edid.get("preferred"))
        scale = suggest_scale(w, h, edid.get("width_mm", 0), edid.get("height_mm", 0))
        is_internal = name.startswith("eDP") or name.startswith("LVDS") or name.startswith("DSI")
        outputs.append(
            {
                "connector": name,
                "sysfs": entry.name,
                "internal": is_internal,
                "mode": f"{w}x{h}",
                "width": w,
                "height": h,
                "scale": scale,
                "make_model": edid.get("name") or "",
                "width_mm": edid.get("width_mm", 0),
                "height_mm": edid.get("height_mm", 0),
            }
        )

    # Internal first, then by connector name
    outputs.sort(key=lambda o: (not o["internal"], o["connector"]))
    return outputs


def layout_positions(outputs: list[dict]) -> list[dict]:
    x = 0
    for i, o in enumerate(outputs):
        logical_w = int(round(o["width"] / o["scale"]))
        logical_h = int(round(o["height"] / o["scale"]))
        o["x"] = x
        o["y"] = 0
        o["logical_width"] = logical_w
        o["logical_height"] = logical_h
        o["focus_at_startup"] = i == 0
        x += logical_w
    return outputs


def render_kdl(outputs: list[dict], home: str, kb_layout: str, opts: dict) -> str:
    lines: list[str] = [
        "// Auto-generated by install.sh / scripts/detect-outputs.py",
        "// Regenerated safely with: ./install.sh --fix-outputs",
        "// Machine-specific paths and optional helpers are gated on file presence.",
        "",
    ]
    for o in outputs:
        lines.append(f'output "{o["connector"]}" {{')
        lines.append(f'    mode "{o["mode"]}"')
        # Keep scale readable (1 / 1.25 / 1.5 / 1.6 / 2)
        scale = o["scale"]
        scale_s = str(int(scale)) if float(scale).is_integer() else f"{scale:.2f}".rstrip("0").rstrip(".")
        lines.append(f"    scale {scale_s}")
        lines.append('    transform "normal"')
        lines.append(f"    position x={o['x']} y={o['y']}")
        if o.get("focus_at_startup"):
            lines.append("    focus-at-startup")
        lines.append("}")
        lines.append("")

    lines += [
        "input {",
        "    keyboard {",
        "        xkb {",
        f'            layout "{kb_layout}"',
        '            options "grp:alt_shift_toggle,compose:rctrl,ctrl:nocaps"',
        "        }",
        "        numlock",
        "    }",
        "    touchpad {",
        "        tap",
        "        natural-scroll",
        "    }",
        "}",
        "",
        "cursor {",
        '    xcursor-theme "capitaine-cursors-light"',
        "    xcursor-size 24",
        "    hide-when-typing",
        "}",
        "",
        "layout {",
        "    gaps 10",
        "    shadow {",
        "        softness 16",
        "        spread 3",
        "        offset x=0 y=3",
        '        color "#0007"',
        "    }",
        "}",
        "",
    ]

    binds = [
        "binds {",
        '    Ctrl+Alt+Delete allow-inhibiting=false { spawn "inir" "session" "toggle"; }',
        '    Mod+L allow-when-locked=true { spawn "inir" "lock" "activate"; }',
        '    Mod+Ctrl+P { spawn "inir" "settingsNav" "page" "28"; }',
    ]

    mr = Path(home) / ".local/share/muslim-reminder/run.sh"
    mt = Path(home) / ".local/share/muslim-reminder/trigger.sh"
    if opts.get("muslim") and mr.is_file() and mt.is_file():
        lines.append(f'spawn-at-startup "{mr}"')
        lines.append("")
        binds.append(f'    Mod+Ctrl+O {{ spawn "{mt}"; }}')

    binds.append("}")
    binds.append("")
    lines.extend(binds)

    arzopa = Path(home) / ".local/bin/arzopa-picture-balance"
    if (
        opts.get("arzopa")
        and arzopa.is_file()
        and any("ARZOPA" in (o.get("make_model") or "").upper() for o in outputs)
    ):
        lines.append(f'spawn-at-startup "{arzopa}"')
        lines.append("")

    return "\n".join(lines) + "\n"


def main() -> int:
    args = sys.argv[1:]
    home = os.environ.get("HOME") or str(Path.home())
    kb = os.environ.get("NIRI_KB_LAYOUT", "us,ru")
    as_kdl = "--kdl" in args
    outputs = layout_positions(detect())
    if not outputs:
        # Fallback so validate still has something sane
        outputs = layout_positions(
            [
                {
                    "connector": "eDP-1",
                    "sysfs": "",
                    "internal": True,
                    "mode": "1920x1080",
                    "width": 1920,
                    "height": 1080,
                    "scale": 1.0,
                    "make_model": "",
                    "width_mm": 0,
                    "height_mm": 0,
                }
            ]
        )

    if as_kdl:
        opts = {
            "muslim": "--with-muslim" in args,
            "arzopa": "--with-arzopa" in args,
        }
        sys.stdout.write(render_kdl(outputs, home, kb, opts))
        return 0

    json.dump({"outputs": outputs, "kb_layout": kb}, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
