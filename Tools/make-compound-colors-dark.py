#!/usr/bin/env python3
# Copyright 2026 Calin Ilie.
#
# SPDX-License-Identifier: AGPL-3.0-only.
# Please see LICENSE files in the repository root for full details.

"""Makes the Compound colour assets resolve to their dark values on watchOS.

watchOS asset catalogs ignore the "luminosity: dark" appearance, so every Compound token resolved to
its light value (e.g. bgSubtleSecondary as #F0F2F5), even though watchOS is always dark. This copies each
colorset's dark value (and dark high-contrast value) over the default entries and drops the dark ones.
Run it again after re-importing compound-design-tokens.
"""

import json
from pathlib import Path

COLORS = Path(__file__).resolve().parent.parent / "Packages/CompoundDesignTokens/Sources/CompoundDesignTokens/Colors.xcassets"


def appearance_key(entry):
    return frozenset((a["appearance"], a["value"]) for a in entry.get("appearances", []))


def make_dark(colorset):
    contents_path = colorset / "Contents.json"
    contents = json.loads(contents_path.read_text())
    by_key = {appearance_key(entry): entry for entry in contents["colors"]}

    dark = by_key.get(frozenset({("luminosity", "dark")}))
    if dark is None:
        return False
    dark_high_contrast = by_key.get(frozenset({("luminosity", "dark"), ("contrast", "high")}), dark)

    colors = [{"idiom": "universal", "color": dark["color"]}]
    if frozenset({("contrast", "high")}) in by_key:
        colors.append({"idiom": "universal",
                       "appearances": [{"appearance": "contrast", "value": "high"}],
                       "color": dark_high_contrast["color"]})

    contents["colors"] = colors
    contents_path.write_text(json.dumps(contents, indent=2) + "\n")
    return True


def main():
    changed = sum(make_dark(colorset) for colorset in sorted(COLORS.glob("*.colorset")))
    print(f"Made {changed} colour sets dark in {COLORS}")


if __name__ == "__main__":
    main()
