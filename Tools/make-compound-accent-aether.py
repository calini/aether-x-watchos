#!/usr/bin/env python3
# Copyright 2026 Calin Ilie.
#
# SPDX-License-Identifier: AGPL-3.0-only.
# Please see LICENSE files in the repository root for full details.

"""Recolours Compound's accent tokens from Element green to Aether's teal (#33D8DD).

Adds an "aether" scale next to Compound's green one, in OKLCH with the Aether hue: the darker steps keep
green's lightness, and green900 and above are shifted to sit around the base colour. Chroma keeps green's
ratio to green900. The accent tokens then point at the new scale.
Success tokens stay green, since there green means "it worked".
Run it after Tools/make-compound-colors-dark.py, and again after re-importing compound-design-tokens.
"""

import json
import math
import re
from pathlib import Path

PACKAGE = Path(__file__).resolve().parent.parent / "Packages/CompoundDesignTokens/Sources/CompoundDesignTokens"
COLORS = PACKAGE / "Colors.xcassets"
BASE = "#33D8DD"
# Green step -> Aether step. green900 maps onto BASE itself.
STEPS = {"green200": "aether200", "alphaGreen300": "alphaAether300", "green400": "aether400",
         "green700": "aether700", "green800": "aether800", "green900": "aether900",
         "green1000": "aether1000", "green1100": "aether1100"}
# The steps drawn around the base colour. Darker steps are subtle backgrounds and keep green's lightness.
BRIGHT_STEPS = {"green900", "green1000", "green1100"}
# Keeps the brightest steps a visible tint rather than white.
MAX_LIGHTNESS = 0.95
ACCENT_TOKENS = ["bgAccentHovered", "bgAccentPressed", "bgAccentRest", "bgAccentSelected", "bgAccentSubtle",
                 "bgBadgeAccent", "borderAccentPrimary", "borderAccentSubtle", "iconAccentPrimary",
                 "iconAccentTertiary", "textActionAccent", "textBadgeAccent"]


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def rgb_to_oklch(rgb):
    r, g, b = (srgb_to_linear(c) for c in rgb)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    b_ = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return lightness, math.hypot(a, b_), math.atan2(b_, a)


def oklch_to_rgb(lightness, chroma, hue):
    a, b = chroma * math.cos(hue), chroma * math.sin(hue)
    l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (lightness - 0.0894841775 * a - 1.2914855480 * b) ** 3
    linear = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
              -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
              -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return tuple(linear_to_srgb(c) if c > 0 else 0.0 for c in linear), all(-1e-4 <= c <= 1 + 1e-4 for c in linear)


def in_gamut(lightness, chroma, hue):
    """Reduces chroma until the colour fits in sRGB."""
    while chroma > 0:
        rgb, fits = oklch_to_rgb(lightness, chroma, hue)
        if fits:
            return tuple(min(max(c, 0.0), 1.0) for c in rgb)
        chroma -= 0.002
    return oklch_to_rgb(lightness, 0, hue)[0]


def components(entry):
    c = entry["color"]["components"]
    return tuple(float(c[k]) for k in ("red", "green", "blue")), c["alpha"]


def appearance_key(entry):
    return tuple(sorted((a["appearance"], a["value"]) for a in entry.get("appearances", [])))


def load(name):
    return json.loads((COLORS / f"{name}.colorset" / "Contents.json").read_text())


def make_scale():
    base = tuple(int(BASE[i:i + 2], 16) / 255 for i in (1, 3, 5))
    base_l, base_c, base_h = rgb_to_oklch(base)
    anchor = {appearance_key(e): rgb_to_oklch(components(e)[0]) for e in load("green900")["colors"]}
    default_l, default_c, _ = anchor[()]

    for green, aether in STEPS.items():
        contents = load(green)
        for entry in contents["colors"]:
            rgb, alpha = components(entry)
            lightness, chroma, _ = rgb_to_oklch(rgb)
            if green in BRIGHT_STEPS:
                # Shifted with the base, which is much lighter than green900.
                lightness = min(base_l + lightness - default_l, MAX_LIGHTNESS)
            new = in_gamut(lightness, base_c * chroma / default_c, base_h)
            entry["color"]["components"] = {"alpha": alpha, "red": f"{new[0]:.4f}",
                                            "green": f"{new[1]:.4f}", "blue": f"{new[2]:.4f}"}
        if aether == "aether900":
            # The default entry is exactly the base colour, not a round trip of it.
            contents["colors"][0]["color"]["components"].update(
                {k: f"{v:.4f}" for k, v in zip(("red", "green", "blue"), base)})
        directory = COLORS / f"{aether}.colorset"
        directory.mkdir(exist_ok=True)
        (directory / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def add_core_tokens():
    path = PACKAGE / "CompoundCoreColorTokens.swift"
    source = path.read_text()
    for green, aether in STEPS.items():
        line = f'    public static let {aether} = Color("{aether}", bundle: Bundle.module)\n'
        if line not in source:
            anchor = f'    public static let {green} = Color("{green}", bundle: Bundle.module)\n'
            source = source.replace(anchor, anchor + line)
    path.write_text(source)


def point_accent_tokens():
    path = PACKAGE / "CompoundColorTokens.swift"
    source = path.read_text()
    for token in ACCENT_TOKENS:
        pattern = rf"(public let {token} = CompoundCoreColorTokens\.)(\w+)"
        match = re.search(pattern, source)
        if match is None:
            raise SystemExit(f"Token {token} not found")
        if match.group(2) in STEPS:
            source = source.replace(match.group(0), match.group(1) + STEPS[match.group(2)])
    path.write_text(source)


def main():
    make_scale()
    add_core_tokens()
    point_accent_tokens()
    print(f"Accent tokens now use the {BASE} scale")


if __name__ == "__main__":
    main()
