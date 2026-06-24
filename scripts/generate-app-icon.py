#!/usr/bin/env python3
"""Generate gumimap AppIcon PNGs for AppIcon.appiconset."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / "gumimap-v2" / "Assets.xcassets" / "AppIcon.appiconset"

FILL = (250, 227, 122)  # #FAE37A
BORDER = (74, 133, 199)  # #4A85C7
BACKGROUND = (252, 245, 214)


def draw_pin(draw: ImageDraw.ImageDraw, cx: float, cy: float, scale: float) -> None:
    head_radius = 150 * scale
    head_center_y = cy - 70 * scale
    tail_tip_y = cy + 210 * scale
    tail_half_width = 52 * scale

    head_box = [
        cx - head_radius,
        head_center_y - head_radius,
        cx + head_radius,
        head_center_y + head_radius,
    ]
    border_width = max(8, int(18 * scale))

    draw.ellipse(head_box, fill=BORDER)
    inset = border_width
    draw.ellipse(
        [
            head_box[0] + inset,
            head_box[1] + inset,
            head_box[2] - inset,
            head_box[3] - inset,
        ],
        fill=FILL,
    )

    left = cx - tail_half_width
    right = cx + tail_half_width
    neck_y = head_center_y + head_radius * 0.55
    draw.polygon(
        [
            (left, neck_y),
            (right, neck_y),
            (cx, tail_tip_y),
        ],
        fill=BORDER,
    )
    inner_half = max(1, tail_half_width - border_width * 0.75)
    draw.polygon(
        [
            (cx - inner_half, neck_y + border_width * 0.4),
            (cx + inner_half, neck_y + border_width * 0.4),
            (cx, tail_tip_y - border_width * 0.8),
        ],
        fill=FILL,
    )


def make_icon(size: int, dark: bool = False) -> Image.Image:
    bg = (36, 48, 66) if dark else BACKGROUND
    image = Image.new("RGBA", (size, size), bg)
    draw = ImageDraw.Draw(image)

    margin = size * 0.08
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=size * 0.22,
        fill=FILL if not dark else (214, 186, 84),
    )

    draw_pin(draw, size / 2, size / 2 + size * 0.02, size / 1024)
    return image


def main() -> None:
    ICON_DIR.mkdir(parents=True, exist_ok=True)

    icons = {
        "AppIcon-1024.png": make_icon(1024, dark=False),
        "AppIcon-1024-dark.png": make_icon(1024, dark=True),
        "AppIcon-1024-tinted.png": make_icon(1024, dark=False),
    }

    for name, image in icons.items():
        path = ICON_DIR / name
        image.save(path, format="PNG", optimize=True)
        print(f"Wrote {path}")


if __name__ == "__main__":
    main()