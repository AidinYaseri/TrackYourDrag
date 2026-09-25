#!/usr/bin/env python3
"""Picks an iOS simulator to build and test against.

CI runner images change their installed simulators between releases, so
hard-coding "iPhone 15" in a workflow breaks without warning. This reads the
list of simulators that are actually available and prints the UDID of the
newest iPhone on the newest iOS runtime.

    xcrun simctl list devices available --json | python3 Tools/pick_simulator.py
"""

from __future__ import annotations

import json
import re
import sys


def runtime_version(identifier: str) -> tuple[int, ...]:
    """Turns ...SimRuntime.iOS-18-1 into (18, 1) so runtimes sort numerically."""
    match = re.search(r"iOS-([\d-]+)", identifier)
    if not match:
        return ()
    return tuple(int(part) for part in match.group(1).split("-") if part.isdigit())


def device_rank(name: str) -> tuple[int, int]:
    """Highest model number first, then the plainest name of that model.

    Sorting by name alone would put "iPhone 9" above "iPhone 16", and preferring
    the shortest name picks "iPhone 16" over "iPhone 16 Pro Max".
    """
    numbers = [int(value) for value in re.findall(r"\d+", name)]
    return (max(numbers) if numbers else 0, -len(name))


def main() -> int:
    payload = json.load(sys.stdin)
    candidates = []

    for identifier, devices in payload.get("devices", {}).items():
        version = runtime_version(identifier)
        if not version:
            continue
        for device in devices:
            if not device.get("isAvailable", False):
                continue
            name = device.get("name", "")
            if "iPhone" not in name:
                continue
            candidates.append((version, device_rank(name), name, device["udid"]))

    if not candidates:
        print("No available iPhone simulator on this machine.", file=sys.stderr)
        return 1

    version, _, name, udid = max(candidates)
    readable = ".".join(str(part) for part in version)
    print(f"Selected {name} on iOS {readable}", file=sys.stderr)
    print(udid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
