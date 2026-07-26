# Tutorial

A single-screen course reached from **How To Play** on the title screen. It
teaches the whole move set — move, jump, double jump, drop through, dash, pogo —
and then puts the player back on the menu.

## What it is made of

| Piece | Where |
| --- | --- |
| The level | `src/levels/tutorial/TutorialLevel.tscn` (a plain `BaseLevel`) |
| How it is built | `tools/build_tutorial_level.gd` |
| How it is entered | `MainGame.load_tutorial()`, from `StartMenu` |
| Its uid | `UIDs.TUTORIAL_LEVEL_UID` |

It sits in its own directory rather than in `src/levels/initial_levels`, which is
the directory [LevelPool](../tripleMLab/src/gameplay/systems/level_pool.gd) deals
runs from — a tutorial turning up as room three of a run would be a bad surprise.

`load_tutorial()` is not a run: no map is generated, nothing is dealt, the fuse
is built but never ticked (`should_tick_time` is off on the scene as well), and
there is no HUD. Reaching the exit door goes straight back to the title screen.
It is the only place in the game where the movement can be tried with no clock.

## The course

Left to right, each mechanic gates the one after it:

1. **Move** — flat ground.
2. **Jump** — a 16px step.
3. **Double jump** — a 48px wall; one jump reaches 28px, so it takes both.
4. **Drop through** — the top of that wall leads onto a drop-through platform in
   a pocket that a floor-to-ceiling pillar closes off ahead. Down + jump is the
   only way on.
5. **Dash** — a 40px gap under a ceiling 4px above the player's head. The ceiling
   caps a jump at 4px of rise, so a jump crosses ~26px and only a dash clears it.
   That ceiling is the underside of the exit ledge.
6. **Pogo** — a bumper over the landing block. A jump off the block tops out
   40px short of the ledge; bouncing off the bumper puts the player on it.

Two rules keep it forgiving:

* The ground on the bottom row is unbroken — a missed jump costs a walk back and
  never a restart.
* The way back up is open from wherever the player lands: the dash plateau has
  head-height under it, so falling into the gap leads back around to the climb
  step rather than into a hole.

## Changing it

The geometry is authored as ASCII art in `tools/build_tutorial_level.gd` — one
character per 8x8 tile — and the scene is generated from it:

```
godot --headless --path tripleMLab --script res://tools/build_tutorial_level.gd
godot --headless --path tripleMLab --import
```

The second pass registers the scene's uid; the generator keeps the uid the file
already has, so a rebuild doesn't break `UIDs.TUTORIAL_LEVEL_UID`.

Two things to know before moving a tile:

* **Nothing may be thinner than two tiles.** The tileset paints terrain from a
  3x3 nine-slice, so a one-tile-thick slab has no tile to match and
  `set_cells_terrain_connect` drops it silently. The generator asserts on this
  rather than letting a hole through.
* **Every distance is sized against `PlayerStats`.** Retuning jump or dash moves
  the line between "teaches the dash" and "the dash is optional". The numbers
  that matter: a jump rises 28px, a double jump 57px, a dash carries ~36px flat,
  and a pogo bounce rises ~41px from wherever it is triggered.
