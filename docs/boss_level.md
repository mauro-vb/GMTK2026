# The Barrage — the final room

The last node on the map is a single screen, seventy seconds long, with nothing in it that has
health. There is no boss to hit. **The boss is the barrage**, and the fight is won by still
being there when it stops.

What the player spends to get there is the run's clock. Every orb that connects costs three
seconds off `TimeSystem`, and hitting zero ends the run — so **the seconds carried into the
room are the health bar**, and the number that has been counting down all game becomes, for
one room, an HP meter.

This document covers that inversion and what it forced, the arena, the three phases, the hit
rules, and the map wiring that took `Room.Type.FINAL` from a dead end to a room.

---

## 1. Seconds as health

### 1.1 Why the clock has to stop

`BossLevel.tscn` sets `should_tick_time = false`, so `MainGame.enter_room()` leaves
`TimeSystem.ticking` off for the whole fight. The run clock does not drain here. The only
thing in the game that removes seconds in this room is getting hit.

That is not a difficulty concession, it is what makes the reading work. Leave the drain on and
two things break at once:

- **The number stops meaning HP.** A bar that falls whether or not you are being hit is not a
  health bar, it is a countdown with damage on top. The player cannot learn "that orb cost me
  three" from a number that was already moving.
- **The fight stops being winnable on merit.** Seventy seconds of drain means anyone who walks
  in on less than seventy seconds loses no matter how well they dodge, and anyone who walks in
  on two hundred can eat a dozen hits. The room would be graded on the map, not on the fight.

With the drain off, the fight is the same length for everyone and the HUD's second count only
ever moves when the player is hit.

### 1.2 The fight has its own clock

The seventy seconds are counted by `BossLevel._fight_time`, incremented in
`_physics_process` and unrelated to `TimeSystem` in every way. Phases, ramps and the survival
bar all read it. `TimeSystem` is only ever touched in one place — `BossLevel.report_hit()` —
and only to take three seconds away.

### 1.3 Damage does not go through ModifiersSystem

`BossProjectile` is deliberately **not** an `Orb`. An `Orb` is a pickup: it asks
`ModifiersSystem.is_orb_blocked()`, runs its value past `modify_orb_value()`, and fires
`HOT_ORB_TOUCHED`. Every one of those is a hook a run can use to switch the boss off — a
player holding **Coating** would make the entire fight free.

So the barrage calls `Global.main_game.time_system.remove_time()` directly and nothing gets a
vote. A run's modifiers decide how many seconds the player arrives with; they do not get to
decide whether the boss is real.

### 1.4 `time_expired` does not fire here

The rest of the game ends a run on `TimeSystem.time_expired`, which `MainGame` connects in
`load_game()`. In this room that signal never fires, because `TimeSystem` only emits it from
its own `_process`, which returns early while `ticking` is false:

```gdscript
func _process(delta: float) -> void:
    if not ticking:
        return
    ...
    if current_time == 0.0 and not _expired_emitted:
        ...
        time_expired.emit()
```

`ticking` is false for this whole room by design (§1.1). Nothing upstream will ever notice
this death, so the room has to notice it itself — in `report_hit()`, at the moment the seconds
are spent. `_on_defeated()` then does by hand exactly what `MainGame._on_time_expired()` does
for every other room: `player.explode()`, then `end_run(false)`. The last room does not get to
end the run in its own private way.

---

## 2. The arena

One fixed 320x180 screen. Levels carry no `Camera2D`, so there is nothing to scroll and
nowhere off-screen to retreat to.

| | |
|---|---|
| Floor surface | y = 168, flat, wall to wall |
| Walls | two tile columns each side, full height |
| `%PlayerSpawn` | (80, 160) |
| `%LevelExit` | (160, 90) — hidden and `monitoring = false` until the fight is survived |
| `%Phase2Platforms` | `NormalPlatform` (`size = 4`) at (64, 128), (160, 96), (256, 128) |

Three surfaces, in a rising staircase: the floor, the two outer platforms 40px above it, and
the middle platform 32px above those. The outer pair is deliberately the easy hop — a standing
jump clears 40px comfortably — and the middle one is reached from them rather than from the
floor. Phase 3 reads directly off those three heights (§3.3).

The exit sits on the middle platform, so the platform that phase 2 hands the player is also
the thing they stand on to leave.

### 2.1 Two nodes that fight back

`LevelExit._ready()` switches its own `monitoring` back **on** two physics frames after the
scene loads. Setting it false once in `BossLevel._ready()` is simply undone, so
`_disable_exit()` waits those frames out before having the last word.

`JumpThroughPlatform._ready()` puts itself on collision layer 9. Child `_ready()` runs before
the parent's, so `BossLevel._ready()` takes the phase-2 platforms straight back off it. They
are re-enabled by `_reveal_platforms()` — and only *after* the reveal tween finishes, because
an `AnimatableBody2D` rising through the player would shove them, and being shoved by the
scenery is not something a player can read as their own mistake.

---

## 3. The phases

Total fight seventy seconds, three phases, one script. Phase parameters are `const`s at the
top of `boss_level.gd` — ramped ones authored as `Vector2(start_of_phase, end_of_phase)` and
read off the phase's own progress by `_ramp()` — so tuning the fight means editing that block
and nothing else.

| | Phase | Window | Teaches | Interval | Speed |
|---|---|---|---|---|---|
| 1 | Ground rush | 0–20s | the jump | 1.4s → 0.55s | 60 → 110 px/s |
| 2 | Rain | 20–42s | keep moving | 1.2s → 0.7s | 90 → 130 px/s |
| 3 | Crossfire | 42–70s | read and position | both streams at 70%, sweep every 5s | 95 px/s (sweep) |

### 3.1 Ground rush — rhythm

Orbs enter off-screen right at x = 336, at y = 160, travelling flat and left. Nothing else
happens. The floor surface is at 168 and the player's body is 12px tall, so y = 160 sits
squarely in a standing player: there is no crouch and nowhere to sidestep to, and the only
answer is a jump.

The cadence is a metronome, not a roll. `_tick_rush()` resets its accumulator **to** the
interval rather than adding it on, so a frame spike does not queue up a catch-up burst and
break the groove the phase exists to teach.

### 3.2 Rain — position

The three platforms rise and fade in, and orbs start falling.

Each drop takes the player's x from **`RAIN_LEAD` (0.8s) before it spawns**, out of a short
ring of samples kept by `_record_position()`. Standing still means the drop is already aimed
at you; moving means it is aimed at where you were. That is the whole phase.

Nothing falls unannounced. Every drop is a `Telegraph` — a dimmed, shrunk, pulsing copy of the
orb's own texture parked at the top of the screen in the target lane for 0.5s first. Because
the marker goes up half a second before the orb spawns and the sample is taken 0.8s before
*that spawn*, the lane is read from 0.3s before the marker appears:

```gdscript
var lane_x: float = _position_at(_fight_time - (RAIN_LEAD - RAIN_TELEGRAPH))
```

### 3.3 Crossfire — layering

Both earlier streams keep running at 70% of the rate they finished on, and every five seconds
a vertical wall of orbs enters from the right with exactly one gap in it. The gap alternates
between three heights, in order:

| Gap centre | Where the player has to be |
|---|---|
| 162 | on the floor |
| 122 | on an outer platform |
| 90 | on the middle platform |

Each is a standing player's midpoint on one of the arena's three surfaces (§2), so the gaps
and the platform heights are one set of numbers wearing two hats — **move a platform and the
gap that belongs to it has to move with it**, or the sweep starts asking for a height nothing
in the room lets you stand at.

The wall is telegraphed by two markers on the gap's edges, 0.8s before it enters — the only
thing worth reading about a wall is where the hole in it is.

The difficulty here is meant to come from three readable patterns overlapping, not from
density. At 320x180 a real bullet-hell is unreadable, so every orb in this phase is
individually dodgeable and the sweep is slower than the ground stream so the two read as
separate things arriving.

**One deviation from the brief.** It asked for a 1.5-tile gap (12px). The player's body is
itself 12px tall, so that is a hole they cannot fit through at any height.
`SWEEP_GAP_HALF_HEIGHT` is 14, leaving 20px of daylight for a 12px body — still something you
have to be lined up with, but something that exists.

---

## 4. Getting hit

| | |
|---|---|
| Cost | 3.0 seconds, straight to `TimeSystem` |
| Invulnerability | 0.6s |
| Feedback | player sprite flashes on a 0.075s beat, red screen flash, 0.25s shake |

`BossProjectile` carries no damage rule of its own. It reports to `BossLevel.report_hit()`,
which returns whether the hit landed — the invulnerability window belongs to the fight, not to
any one orb. A refused hit means the orb **keeps flying** rather than being consumed:
"projectiles pass through" has to mean the rest of the wall is still there when the window
closes, not that the player is briefly a vacuum.

### 4.1 Screen shake without a camera

Levels have no `Camera2D`, so the shake goes on `Viewport.canvas_transform`. That moves
everything drawn in world space — arena, orbs, player — without displacing a single physics
body, and `CanvasLayer`s sit outside it so the HUD stays nailed down. The offset is rounded to
whole pixels, because the project renders at 320x180 with integer scaling and a half-pixel
offset would smear the whole screen.

`_exit_tree()` puts it back to zero. The viewport outlives the room; the player is only
re-parented out of it, so its `modulate` is restored there too.

---

## 5. Win and lose

`_fight_time` reaching seventy stops spawning, frees every live projectile and pending
telegraph, and fades `%LevelExit` in. From there it is `BaseLevel`'s — `reached_exit` →
`_on_exit_reached()` → `exit()` — and the room ends like any other.

**Win.** Because `MainGame` sets `_in_final_room` on the way into a `FINAL` room, `exit_room()`
turns walking out of it into `end_run(true)` rather than another trip to the map. The boss
needs no part in that beyond opening its exit.

**Lose.** The clock reaching zero runs `_on_defeated()`: spawning stops, the field is cleared,
the player detonates, and `MainGame.end_run(false)` puts up the same `RunEndScreen` every other
death in the game puts up. There is no retry logic in this room — `RunEndScreen` owns that
choice, and `MainGame.restart_run()` answers it.

---

## 6. The HUD

A `CanvasLayer` inside `BossLevel.tscn` carrying one bar, themed from
`src/ui/themes/main_theme.tres`, plus the `ColorRect` used for the hit flash. No text.

The bar is a contained 112x7 strip, centred horizontally and sitting at y=22 — low enough to
clear the fuse and readout `FuseBar` puts in the top-left. It is drawn as a 1px-bordered box with
rounded ends and anti-aliasing off, in the tileset's own navy and red. It shows the fight's
**remaining** time and **drains right to left**, so the red is always what is still coming.

Two notches are cut into it at the phase boundaries, built in `_build_phase_ticks()` from
`PHASE_END_TIMES` rather than authored into the scene, so the marks and the phases they mark
cannot drift apart. They are positioned by time *remaining* — phase 1 is the rightmost slice —
and coloured to match the bar's background, so a phase change reads as the red edge passing
through a gap in itself. A side effect worth keeping: a notch is only visible while it is
still inside the red, so what the bar shows is the boundaries still ahead of you.

**Nothing is captioned.** There is no phase name, no "SURVIVED", no "OUT OF TIME". A phase is
meant to be recognised by what starts happening — platforms appearing, orbs falling, a wall
arriving — and a label naming it is the same information twice, in the form nobody reads while
dodging. Winning is announced by the barrage stopping and the exit fading in; losing is
announced by the clock hitting zero.

The second count is **not** duplicated here either. `FuseBar` is already on screen and already
shows it, and in this room that fuse *is* the health bar (§1) — it stops burning down on its
own and only shortens when the player is hit.

---

## 7. Map wiring

**None, in the end.** `LevelPool` deals the last room out of `res://src/levels/final_level/`,
and `MainGame.enter_room()` already routes `Room.Type.FINAL` through `enter_level()`. The boss
lives in that directory, so it is dealt as the final level by existing into it — no uid in
`UIDs`, no branch in `Room.apply_type_scene()`, no case in `MainGame`.

That is the point of the pool (see its class doc): a final level that has to be registered
somewhere is a final level somebody forgets to re-register. It also means swapping the boss for
a different last room is a file move.

The boss is a `BaseLevel` like any other, so `enter_level()` needed no changes: player spawn
placement, the HUD, the `ENTER_LEVEL`/`EXIT_LEVEL` modifier hooks and teardown all come for
free. Nothing in `MainGame` knows this is a boss, only that it is the last room.

---

## 8. Files

| | |
|---|---|
| `src/levels/level_objects/boss_projectile/` | `boss_projectile.gd`, `BossProjectile.tscn` |
| `src/levels/final_level/` | `boss_level.gd`, `BossLevel.tscn` — the pool deals whatever is here |
| `src/debug/BossCheck.tscn` | headless sanity check — `godot --headless res://src/debug/BossCheck.tscn` |
| `src/debug/BossPlaytest.tscn` | drops straight into the fight, with keys to jump phases |

No enemy framework, no state machine, no `EntityRoot`, no new autoloads, no spawner nodes and
no new art: projectiles and telegraphs are both `assets/art/level_elements/HotOrb.png`, the
arena is the existing tileset, and the platforms are stock `NormalPlatform`s.

`BossCheck` reaches the phases by writing `_fight_time` directly rather than sitting through
seventy seconds; everything downstream of that — phase entry, telegraphs, spawning, hits, the
retry, the win — is the real path.
