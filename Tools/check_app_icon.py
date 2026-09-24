#!/usr/bin/env python3
"""Checks the generated app icon is something iOS will actually accept.

Reads the PNG header directly rather than pulling in an image library, and
fails if the icon is the wrong size or carries an alpha channel, which App
Store submission rejects.
"""

from __future__ import annotations

import struct
import sys

ICON_PATH = "Tracky/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
TRUECOLOUR_NO_ALPHA = 2


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else ICON_PATH
    with open(path, "rb") as handle:
        header = handle.read(26)

    if header[:8] != PNG_SIGNATURE:
        print(f"{path} is not a PNG", file=sys.stderr)
        return 1

    width, height, depth, colour = struct.unpack(">IIBB", header[16:26])
    print(f"{path}: {width}x{height}, {depth}-bit, colour type {colour}")

    if (width, height) != (1024, 1024):
        print(f"expected 1024x1024, got {width}x{height}", file=sys.stderr)
        return 1

    if colour != TRUECOLOUR_NO_ALPHA:
        print(
            f"app icons must have no alpha channel (colour type {colour})",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
