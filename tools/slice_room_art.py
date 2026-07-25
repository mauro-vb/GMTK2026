#!/usr/bin/env python3
"""Slices the room-icon sheets into one sprite per map room type.

The source sheets are large (each item is ~200px on a 1024px sheet) while the
map draws icons at roughly 32px, so every sprite is trimmed to its own content
and box-fitted into ICON_BOX. Downscaling uses LANCZOS rather than NEAREST:
the sources are not clean 1:1 pixel art, and at a 6x reduction area-averaging
keeps the silhouette readable where point-sampling would shred it.

    python3 tools/slice_room_art.py [items.png levels.png]

Reads from ~/Desktop/placeholder by default, writes into
tripleMLab/assets/art/map/rooms/.
"""

from __future__ import annotations

import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "tripleMLab" / "assets" / "art" / "map" / "rooms"
DEFAULT_SRC = pathlib.Path.home() / "Desktop" / "placeholder"

## Longest side of a finished icon, in map pixels. Cords run to node centres
## and pass under the icons, so this is set against MapGenerator's 42px step
## and 38px lane to leave a useful length of fuse showing between neighbours.
ICON_BOX = 26

## Alpha at or below this is background. The sheets are cleanly keyed, so this
## only has to survive the odd stray edge pixel.
ALPHA_FLOOR = 8

## Sprites are named in reading order, left to right then top to bottom.
SHEETS: dict[str, list[str]] = {
    "items.png": [
        "crate",
        "crate_burnt",
        "shop_cart",
        "chest",
        "barrel",
        "crate_tarp",
    ],
    "levels.png": [
        "entrance_timber",
        "entrance_door",
        "entrance_cave",
        "entrance_rails_boarded",
        "entrance_boarded",
        "entrance_collapsed",
        "entrance_tunnel",
        "entrance_tunnel_lit",
    ],
}


def spans(flags: list[bool]) -> list[tuple[int, int]]:
    """Runs of True, as [start, end) pairs: one per row or column of items."""
    result: list[tuple[int, int]] = []
    start: int | None = None
    for index, flag in enumerate(flags):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            result.append((start, index))
            start = None
    if start is not None:
        result.append((start, len(flags)))
    return result


def occupancy(image: Image.Image) -> tuple[list[bool], list[bool]]:
    width, height = image.size
    pixels = image.load()
    columns = [False] * width
    rows = [False] * height

    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] > ALPHA_FLOOR:
                columns[x] = True
                rows[y] = True

    return columns, rows


def merge_thin(runs: list[tuple[int, int]], minimum: int) -> list[tuple[int, int]]:
    """Folds slivers into the previous run.

    One sheet has a stray 10px band where a wisp of smoke rises clear of its
    tile; without this it would be read as an extra row of items.
    """
    merged: list[tuple[int, int]] = []
    for run in runs:
        if run[1] - run[0] >= minimum:
            merged.append(run)
        elif merged:
            merged[-1] = (merged[-1][0], run[1])
        else:
            merged.append(run)
    return merged


def fit(image: Image.Image) -> Image.Image:
    """Trims to content, then scales the long side down to ICON_BOX."""
    box = image.getbbox()
    if box is not None:
        image = image.crop(box)

    scale = ICON_BOX / max(image.size)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.LANCZOS)


def slice_sheet(path: pathlib.Path, names: list[str]) -> int:
    sheet = Image.open(path).convert("RGBA")
    columns, rows = occupancy(sheet)
    # An item is at least a third of a cell; anything thinner is a stray wisp.
    column_runs = merge_thin(spans(columns), sheet.width // 12)
    row_runs = merge_thin(spans(rows), sheet.height // 8)

    cells = [(cx, cy) for cy in row_runs for cx in column_runs]
    if len(cells) != len(names):
        raise SystemExit(
            "%s: found %d cells (%d cols x %d rows) but have %d names"
            % (path.name, len(cells), len(column_runs), len(row_runs), len(names))
        )

    for name, ((left, right), (top, bottom)) in zip(names, cells):
        icon = fit(sheet.crop((left, top, right, bottom)))
        icon.save(OUT_DIR / f"{name}.png")
        print("  %-24s %2dx%-2d" % (name + ".png", icon.width, icon.height))

    return len(cells)


def main(argv: list[str]) -> int:
    sources = [pathlib.Path(a) for a in argv[1:]] or [DEFAULT_SRC / n for n in SHEETS]
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for source in sources:
        names = SHEETS.get(source.name)
        if names is None:
            raise SystemExit(f"no sprite names registered for {source.name}")
        if not source.exists():
            raise SystemExit(f"missing sheet: {source}")

        print(f"{source.name} ->")
        slice_sheet(source, names)

    print(f"wrote to {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
