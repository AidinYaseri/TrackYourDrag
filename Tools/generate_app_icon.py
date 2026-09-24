#!/usr/bin/env python3
"""Renders the Tracky app icon.

The icon is the same mark the app draws in SwiftUI (`TrackyMark`): a 270-degree
speedometer sweep open at the bottom, a needle dot at the upper right, and a "T"
whose stem leans like a racing line.

Everything is rasterised from signed distance fields with analytic
anti-aliasing, using only the standard library, and written straight out as a
PNG. Run it from the repository root:

    python3 Tools/generate_app_icon.py

It rewrites Tracky/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
and a smaller Docs/icon-preview.png for the README.
"""

from __future__ import annotations

import math
import os
import struct
import zlib

# Canvas ------------------------------------------------------------------

SIZE = 1024
MARK = SIZE * 0.64          # side of the mark's bounding box
CX = CY = SIZE / 2.0

# Mark geometry (mirrors TrackyMark.swift) --------------------------------

RADIUS = 0.46 * MARK        # sweep radius
HALF_STROKE = 0.0460 * MARK # half the sweep's stroke width
ARC_START = 135.0           # degrees, clockwise from +x with y pointing down
ARC_END = 405.0             # 270 degrees of sweep, open at the bottom

# Colours -----------------------------------------------------------------

ACCENT = (0x37, 0xE3, 0xFF)
ACCENT_ALT = (0x7C, 0x5C, 0xFF)
BG_TOP = (0x0C, 0x12, 0x19)
BG_BOTTOM = (0x04, 0x06, 0x0A)

AA = 1.3  # anti-aliasing width, pixels


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return low if value < low else (high if value > high else value)


def coverage(distance: float) -> float:
    """Signed distance (negative inside) to 0..1 coverage."""
    return clamp(0.5 - distance / AA)


# Signed distance fields --------------------------------------------------


def sd_arc(x: float, y: float) -> float:
    dx = x - CX
    dy = y - CY
    r = math.hypot(dx, dy)
    angle = math.degrees(math.atan2(dy, dx)) % 360.0
    unwrapped = angle if angle >= ARC_START else angle + 360.0
    if ARC_START <= unwrapped <= ARC_END:
        return abs(r - RADIUS) - HALF_STROKE
    # Outside the sweep: distance to the nearer round cap.
    best = float("inf")
    for cap in (ARC_START, ARC_END):
        theta = math.radians(cap)
        capx = CX + RADIUS * math.cos(theta)
        capy = CY + RADIUS * math.sin(theta)
        best = min(best, math.hypot(x - capx, y - capy))
    return best - HALF_STROKE


def sd_circle(x: float, y: float, cx: float, cy: float, radius: float) -> float:
    return math.hypot(x - cx, y - cy) - radius


def sd_round_rect(
    x: float, y: float, cx: float, cy: float, half_w: float, half_h: float, radius: float
) -> float:
    qx = abs(x - cx) - (half_w - radius)
    qy = abs(y - cy) - (half_h - radius)
    outside = math.hypot(max(qx, 0.0), max(qy, 0.0))
    inside = min(max(qx, qy), 0.0)
    return outside + inside - radius


def make_convex_edges(points):
    """Pre-computes outward unit normals for a convex polygon."""
    count = len(points)
    centroid_x = sum(p[0] for p in points) / count
    centroid_y = sum(p[1] for p in points) / count
    edges = []
    for index in range(count):
        x0, y0 = points[index]
        x1, y1 = points[(index + 1) % count]
        nx, ny = (y1 - y0), -(x1 - x0)
        length = math.hypot(nx, ny)
        nx, ny = nx / length, ny / length
        # Flip so the normal points away from the middle of the shape.
        if (centroid_x - x0) * nx + (centroid_y - y0) * ny > 0:
            nx, ny = -nx, -ny
        edges.append((x0, y0, nx, ny))
    return edges


def sd_convex(x: float, y: float, edges) -> float:
    worst = -1e9
    for x0, y0, nx, ny in edges:
        worst = max(worst, (x - x0) * nx + (y - y0) * ny)
    return worst


# The "T" -----------------------------------------------------------------

LEFT = CX - MARK / 2
TOP = CY - MARK / 2

CROSSBAR = dict(
    cx=LEFT + MARK * 0.50,
    cy=TOP + MARK * 0.295,
    half_w=MARK * 0.275,
    half_h=MARK * 0.060,
    radius=MARK * 0.030,
)

# The stem leans right and runs out through the open bottom of the sweep, so the
# letter reads as a line taken through a corner rather than a plain "T".
STEM_EDGES = make_convex_edges(
    [
        (LEFT + MARK * 0.443, TOP + MARK * 0.355),
        (LEFT + MARK * 0.557, TOP + MARK * 0.355),
        (LEFT + MARK * 0.645, TOP + MARK * 1.000),
        (LEFT + MARK * 0.530, TOP + MARK * 1.000),
    ]
)


def mark_distance(x: float, y: float) -> float:
    return min(
        sd_arc(x, y),
        sd_round_rect(x, y, **CROSSBAR),
        sd_convex(x, y, STEM_EDGES),
    )


# Painting ----------------------------------------------------------------


def mix(a, b, t: float):
    t = clamp(t)
    return (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )


def background(x: float, y: float, size: int):
    base = mix(BG_TOP, BG_BOTTOM, y / size)
    # Soft accent glow behind the top of the mark.
    glow_distance = math.hypot(x - size / 2, y + size * 0.05)
    glow = clamp(1.0 - glow_distance / (size * 0.75)) ** 2 * 0.28
    return mix(base, ACCENT, glow)


def render(size: int) -> bytes:
    scale = size / SIZE
    rows = []
    for py in range(size):
        row = bytearray()
        y = (py + 0.5) / scale
        for px in range(size):
            x = (px + 0.5) / scale
            red, green, blue = background(x * scale, y * scale, size)
            alpha = coverage(mark_distance(x, y) * scale)
            if alpha > 0.0:
                # The mark takes a diagonal gradient, top-left to bottom-right.
                t = ((x - LEFT) + (y - TOP)) / (2 * MARK)
                mark = mix(ACCENT, ACCENT_ALT, t)
                red, green, blue = mix((red, green, blue), mark, alpha)
            row += bytes((int(red + 0.5), int(green + 0.5), int(blue + 0.5)))
        rows.append(bytes(row))
    return rows


# PNG ---------------------------------------------------------------------


def write_png(path: str, size: int, rows) -> None:
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)  # 8-bit truecolour
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(png)


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    targets = [
        (os.path.join(
            root, "Tracky/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
        ), SIZE),
        (os.path.join(root, "Docs/icon-preview.png"), 256),
    ]
    for path, size in targets:
        write_png(path, size, render(size))
        print(f"wrote {path} ({size}x{size})")


if __name__ == "__main__":
    main()
