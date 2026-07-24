#!/usr/bin/env python3
"""Generates the burning-fuse pixel art for the map screen.

Everything here is hand-authored at the pixel level so the output is exact:
no anti-aliasing, no semi-transparent edges, and cords that tile seamlessly.

    python3 tools/gen_fuse_art.py

Writes into tripleMLab/assets/art/map/fuse/.
"""

from __future__ import annotations

import pathlib
import sys

from PIL import Image

OUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "tripleMLab" / "assets" / "art" / "map" / "fuse"

TRANSPARENT = (0, 0, 0, 0)


def rgb(value: str) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255)


# --- Cord palettes -----------------------------------------------------------
# Unburnt and burnt keep matching dark outlines: those two are the pair that
# actually stack, since the burnt line is drawn over the unburnt one as it grows.
#
# The dud is deliberately lighter than the suggested palette. Half of a 4px cord
# is outline, so the outline sets the value the eye reads from across the room --
# with a dark outline a dud rendered as a near-black bar, indistinguishable from
# a charred one at 640x360. A dud is never composited under anything (set_dud()
# refuses to touch a burnt fuse), so lifting it costs nothing and buys the three
# states three clearly separate values: warm tan, pale gray, near black.
CORDS = {
    "fuse_cord": {
        "outline": rgb("#2B1B10"),
        "body": rgb("#C89B5E"),
        "highlight": rgb("#EBCF9B"),
        "shadow": rgb("#8A6334"),
    },
    "fuse_cord_burnt": {
        "outline": rgb("#0E0C0B"),
        "body": rgb("#33302D"),
        "highlight": rgb("#575350"),
        "shadow": rgb("#1B1917"),
    },
    "fuse_cord_dud": {
        "outline": rgb("#6B6058"),
        "body": rgb("#ADA396"),
        "highlight": rgb("#C6BDB1"),
        "shadow": rgb("#8F8578"),
    },
}

CORD_W, CORD_H = 8, 4
# The braid rhythm repeats every 4px, which divides evenly into the 8px width,
# so column 7 sits against column 0 with no seam.
TWIST_PERIOD = 4


def make_cord(palette: dict[str, tuple[int, int, int, int]]) -> Image.Image:
    img = Image.new("RGBA", (CORD_W, CORD_H), TRANSPARENT)
    px = img.load()
    for x in range(CORD_W):
        px[x, 0] = palette["outline"]
        px[x, 3] = palette["outline"]
        px[x, 1] = palette["highlight"] if x % TWIST_PERIOD == 0 else palette["body"]
        px[x, 2] = palette["shadow"] if x % TWIST_PERIOD == 2 else palette["body"]
    return img


# --- Spark -------------------------------------------------------------------
# W = white-hot core, Y = yellow ring, O = orange outer, E = loose flung ember.
# The frames differ in core size and ember placement so the loop flickers
# rather than pulsing smoothly.
SPARK_COLORS = {
    "W": rgb("#FFFFFF"),
    "Y": rgb("#FFE24A"),
    "O": rgb("#FF7A18"),
    "E": rgb("#FF9A2E"),
    ".": TRANSPARENT,
}

SPARK_FRAMES = [
    [
        "....E...",
        "...OO...",
        "..OYYO..",
        ".OYWWYO.",
        ".OYWWYO.",
        "..OYYO..",
        "E..OO...",
        "........",
    ],
    [
        "........",
        "...OO..E",
        "..OYYO..",
        ".OYWWYO.",
        "..OYWYO.",
        "..OYYO..",
        "...O....",
        ".E......",
    ],
    [
        "........",
        "...O....",
        "..OYYO.E",
        ".OYWWYO.",
        "..OYYO..",
        "...OO...",
        "E.......",
        "........",
    ],
    [
        "...E....",
        "..OOOO..",
        ".OYYYYO.",
        ".OYWWYO.",
        ".OYWWYO.",
        ".OYYYYO.",
        "..OOOO..",
        ".......E",
    ],
]

FRAME_SIZE = 8


def make_spark() -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_SIZE * len(SPARK_FRAMES), FRAME_SIZE), TRANSPARENT)
    px = sheet.load()
    for index, frame in enumerate(SPARK_FRAMES):
        if len(frame) != FRAME_SIZE:
            raise ValueError("spark frame %d has %d rows" % (index, len(frame)))
        for y, row in enumerate(frame):
            if len(row) != FRAME_SIZE:
                raise ValueError("spark frame %d row %d is %d wide" % (index, y, len(row)))
            for x, key in enumerate(row):
                px[index * FRAME_SIZE + x, y] = SPARK_COLORS[key]
    return sheet


# --- Checks ------------------------------------------------------------------

def assert_binary_alpha(img: Image.Image, name: str) -> None:
    for _count, colour in img.getcolors(maxcolors=1 << 16):
        if colour[3] not in (0, 255):
            raise ValueError("%s has a semi-transparent pixel: %r" % (name, colour))


def assert_tiles(img: Image.Image, name: str) -> None:
    """A cord tiles cleanly when its last column continues the pattern into its first."""
    px = img.load()
    for y in range(img.height):
        left = px[0, y]
        right = px[img.width - 1, y]
        if left[3] != right[3]:
            raise ValueError("%s row %d breaks the tile seam" % (name, y))


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for name, palette in CORDS.items():
        img = make_cord(palette)
        assert_binary_alpha(img, name)
        assert_tiles(img, name)
        img.save(OUT_DIR / ("%s.png" % name))
        print("wrote %s.png (%dx%d)" % (name, img.width, img.height))

    spark = make_spark()
    assert_binary_alpha(spark, "fuse_spark")
    spark.save(OUT_DIR / "fuse_spark.png")
    print("wrote fuse_spark.png (%dx%d)" % (spark.width, spark.height))
    return 0


if __name__ == "__main__":
    sys.exit(main())
