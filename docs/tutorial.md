# Tutorial

Two single-screen rooms reached from **How To Play** on the title screen. They
teach the whole move set — move, jump, double jump, drop through, dash, pogo —
and the two orbs, and then put the player back on the menu.

## What it is made of

| Piece | Where |
| --- | --- |
| Room 1 | `src/levels/tutorial/TutorialLevel.tscn` (a plain `BaseLevel`) |
| Room 2 | `src/levels/tutorial/TutorialLevel2.tscn` (a plain `BaseLevel`) |
| How they are built | `tools/build_tutorial_level.gd` |
| How they are entered | `MainGame.load_tutorial()`, from `StartMenu` |
| Their order | `MainGame.TUTORIAL_ROOM_UIDS` |
| Their uids | `UIDs.TUTORIAL_ROOM_1_UID`, `UIDs.TUTORIAL_ROOM_2_UID` |

They sit in their own directory rather than in `src/levels/initial_levels`, which
is the directory [LevelPool](../tripleMLab/src/gameplay/systems/level_pool.gd)
deals runs from — a tutorial turning up as room three of a run would be a bad
surprise.

`load_tutorial()` is not a run: no map is generated, nothing is dealt, the fuse
is built but never ticked (`should_tick_time` is off on both scenes as well), and
there is no HUD. The first door leads to room 2; the second goes straight back to
the title screen. It is the only place in the game where the movement can be
tried with no clock — which is also why the orbs in it are free to touch.

## Why two rooms

A level is one fixed screen. The viewport is 320x180, every level is the same
42x23 tile grid, and there is no `Camera2D` anywhere in the game to scroll one.
Six mechanics plus two orbs do not fit in that with any air around them; the
first version of this was a single room and read as clutter. Splitting the course
in half is the only way to give it room.

## The course

**Room 1 — the ground moves and the orbs**

1. **Move** — flat ground.
2. **Jump** — a 16px step.
3. **Double jump** — a 48px wall; one jump reaches 26px, so it takes both.
4. **Drop through** — the top of that wall leads onto a drop-through platform,
   and a floor-to-ceiling pillar closes off the way ahead. Down + jump is the
   only way on.
5. **The orbs** — a red orb sitting in the corridor past the pillar (`-2 SEC`)
   and a blue one on the block after it (`+2 SEC`). With no clock running,
   touching either only flashes the player red or green, so the red one can be
   learned by walking into it rather than by losing a run to it.

**Room 2 — dash and pogo**

1. **Dash** — two 16px steps up onto a plateau roofed 4px over the player's
   head. That caps a jump there at 4px of rise, so a jump crosses 32px and the
   gap is 40px. A dash carries 36px flat plus what the fall adds — about 57px.
2. **Pogo** — the bumper sits at the right-hand edge of the landing terrace,
   close enough to overlap the player *standing still*. A pogo from a standstill
   rises 41px and clears the exit ledge by 9px; jumping into it first gives 35px
   of margin, and it can also be hit from the ground below.

## Forgiveness, and what is not gated

The ground on the bottom row of both rooms is unbroken, everything raised can be
walked off, and each mechanic's failure lands the player somewhere they can walk
out of: missing the dash drops them in a pit they hop 16px out of, and missing
the pogo drops them in a 16px gap they hop back out of.

Neither the dash nor the pogo is hard-gated, and that is deliberate. On one
320x180 screen, against a 55px double jump, every gate that actually holds works
out to about 4px of margin — and 4px is the difference between a room that
teaches you and a room that traps you. The original room was gated, and its pogo
is exactly where players got stuck: the bumper sat past the right-hand edge of
the exit ledge, so the bounce apexed off the end of it and only a frame-perfect
apex-pogo made the ~24px of drift. Both moves are now signposted and are the easy
route; a player determined to double-jump past one can. Nobody is stuck in the
room that teaches the controls.

## Changing it

The geometry is authored as ASCII art in `tools/build_tutorial_level.gd` — one
character per 8x8 tile, one map per room — and both scenes are generated from it:

```
godot --headless --editor --path tripleMLab --script res://tools/build_tutorial_level.gd
godot --headless --path tripleMLab --import
```

`--editor` is load-bearing and the bug it avoids is silent. In plain `--script`
mode the autoloads are added to the tree but their names are never registered as
global identifiers for the compiler, so `Global.main_game` in `orb.gd` fails to
resolve, the orbs instantiate without their script, and setting `type` on them
does nothing — every red orb is packed as a blue one, with no error. The second
pass registers the scenes' uids; the generator keeps the uid a file already has,
so a rebuild doesn't break `UIDs.TUTORIAL_ROOM_*`.

Three things to know before moving a tile:

* **Nothing may be thinner than two tiles.** The tileset paints terrain from a
  3x3 nine-slice, so a one-tile-thick slab has no tile to match and
  `set_cells_terrain_connect` drops it silently. The generator asserts on this
  rather than letting a hole through, and asserts on row length too.
* **Every distance is sized against `PlayerStats`.** Retuning jump or dash moves
  the line between "teaches the dash" and "the dash is pointless". The numbers
  the maps were drawn to: the player box is 7x12 with its feet at origin+8, a
  jump rises 26px, a double jump 55px, a dash carries 36px flat with its y
  frozen, and a pogo bounce rises 41px from wherever it is triggered.
* **A ceiling 4px over the player's head caps a jump at 4px.** That is the whole
  mechanism behind the dash corridor, and it is why the roof slab in room 2 sits
  where it does.
