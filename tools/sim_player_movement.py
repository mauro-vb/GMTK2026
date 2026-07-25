#!/usr/bin/env python3
"""Simulate the player's jump arc from the real PlayerStats values.

Mirrors Player._apply_gravity() and Player.apply_horizontal_movement() frame for
frame at the project's 60Hz physics tick, so the numbers it prints are what the
engine actually produces rather than a closed-form approximation. The asymmetric
gravity and the apex hang band make the closed form disagree by a few px.

Reads the script defaults out of player_stats.gd, then layers player_stats.tres
on top -- the same resolution order Godot uses -- so it can never drift from the
values in the project.

Usage:
    python3 tools/sim_player_movement.py
    python3 tools/sim_player_movement.py --set jump_velocity=-210 --set move_speed=70
"""

import argparse
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
STATS_GD = REPO / "tripleMLab/src/gameplay/player/player_stats.gd"
STATS_TRES = REPO / "tripleMLab/src/gameplay/player/resources/player_stats.tres"

TILE = 8.0  # px, from level_tileset.tres
DT = 1.0 / 60.0  # project.godot leaves physics/common/physics_ticks_per_second at 60
PLAYER_HEIGHT = 20.0  # px, CollisionShape2D in Player.tscn
VIEWPORT = (320.0, 180.0)


def load_stats():
    """Script defaults, then .tres overrides -- Godot's own resolution order."""
    gd = STATS_GD.read_text()
    stats = {
        m[1]: float(m[2])
        for m in re.finditer(r"@export var (\w+): (?:float|int) = (-?[\d.]+)", gd)
    }
    if not stats:
        sys.exit(f"no @export floats found in {STATS_GD}")
    tres = STATS_TRES.read_text()
    stats.update(
        {m[1]: float(m[2]) for m in re.finditer(r"^(\w+) = (-?[\d.]+)$", tres, re.M)}
    )
    return stats


def gravity_mult(vy, s, jump_cut=False):
    """Player._apply_gravity()'s multiplier ladder, in the same order."""
    if jump_cut and vy < 0:
        return s["jump_cut_gravity_mult"]
    if abs(vy) < s["jump_hang_threshold"]:
        return s["jump_hang_gravity_mult"]
    if vy < 0:
        return s["ascend_gravity_mult"]
    if vy > 0:
        return s["fall_gravity_mult"]
    return 1.0


def step_vy(vy, s, jump_cut=False):
    return min(vy + s["gravity"] * gravity_mult(vy, s, jump_cut) * DT, s["max_fall_speed"])


def step_vx(vx, s, direction=1.0, vy=0.0):
    """Player.apply_horizontal_movement(), including the near-apex bonuses."""
    target = direction * s["move_speed"]
    accel = s["acceleration"]
    if abs(vy) < s["jump_hang_threshold"]:
        target *= s["jump_hang_max_speed_mult"]
        accel *= s["jump_hang_accel_mult"]
    if direction != 0.0:
        delta = target - vx
        step = accel * DT
    else:
        delta = -vx
        step = s["friction"] * DT
    return (vx + delta) if abs(delta) <= step else vx + (step if delta > 0 else -step)


def arc(s, v0, second_jump=None, running_start=True, jump_cut_after=None):
    """One jump from ground level until the feet return to it.

    Returns (apex_px, horizontal_px, airtime_s). y is negative-up, matching Godot.
    """
    y = 0.0
    vy = v0
    x = 0.0
    vx = s["move_speed"] if running_start else 0.0
    t = 0.0
    apex = 0.0
    fired = second_jump is None
    while t < 5.0:
        if not fired and vy >= 0.0:
            vy = second_jump
            fired = True
        cut = jump_cut_after is not None and t >= jump_cut_after
        vy = step_vy(vy, s, cut)
        vx = step_vx(vx, s, 1.0, vy)
        y += vy * DT
        x += vx * DT
        t += DT
        apex = min(apex, y)
        if y >= 0.0:
            break
    return -apex, x, t


def drop_through(s):
    """Distance the feet travel while the dropped platform is ignored."""
    y = 0.0
    vy = s["drop_through_velocity"]
    t = 0.0
    while t < s["drop_through_time"]:
        vy = step_vy(vy, s)
        y += vy * DT
        t += DT
    return y, vy


def tiles(px):
    return f"{px:6.1f}px ({px / TILE:.2f} tiles)"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="override a stat without touching the .tres")
    args = ap.parse_args()

    s = load_stats()
    for override in args.set:
        key, _, value = override.partition("=")
        if key not in s:
            sys.exit(f"unknown stat {key!r}")
        s[key] = float(value)

    h, w, t = arc(s, s["jump_velocity"])
    hd, wd, td = arc(s, s["jump_velocity"], s["double_jump_velocity"])
    hp, _, _ = arc(s, s["pogo_velocity"])
    hs, _, ts = arc(s, s["jump_velocity"], jump_cut_after=0.0)
    dy, dv = drop_through(s)

    print(f"tile {TILE:.0f}px | player {PLAYER_HEIGHT:.0f}px tall "
          f"({PLAYER_HEIGHT / TILE:.2f} tiles) | {DT * 1000:.2f}ms tick\n")
    print(f"  jump        apex {tiles(h)}   span {tiles(w)}   air {t:.2f}s")
    print(f"  short hop   apex {tiles(hs)}                              air {ts:.2f}s")
    print(f"  jump + dbl  apex {tiles(hd)}   span {tiles(wd)}   air {td:.2f}s")
    print(f"  pogo        apex {tiles(hp)}")
    print(f"  dash        {tiles(s['dash_speed'] * s['dash_duration'])}   "
          f"over {s['dash_duration']:.2f}s")
    print()

    print("  single jump reach:")
    for n in range(2, 5):
        margin = h - n * TILE
        verdict = f"CLEARS by {margin:5.1f}px" if margin > 0 else f"fails  by {-margin:5.1f}px"
        print(f"    ledge {n} tiles ({n * TILE:2.0f}px): {verdict}")
    for n in range(4, 7):
        margin = w - n * TILE
        verdict = f"CLEARS by {margin:5.1f}px" if margin > 0 else f"fails  by {-margin:5.1f}px"
        print(f"    gap   {n} tiles ({n * TILE:2.0f}px): {verdict}")
    print()

    print(f"  drop-through  {dy:5.1f}px in {s['drop_through_time']}s, "
          f"exit speed {dv:3.0f}px/s")
    print(f"  terminal fall {s['max_fall_speed']:5.0f}px/s "
          f"= {s['max_fall_speed'] / TILE:.1f} tiles/s, "
          f"{VIEWPORT[1]:.0f}px screen in {VIEWPORT[1] / s['max_fall_speed']:.2f}s")
    print(f"  run speed     {s['move_speed']:5.0f}px/s, "
          f"{VIEWPORT[0]:.0f}px screen in {VIEWPORT[0] / s['move_speed']:.2f}s")


if __name__ == "__main__":
    main()
