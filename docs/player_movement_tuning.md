# Player movement tuning

The player moved too fast, and the drop-through fall in particular read as a yank rather
than a fall. This pass slows the whole movement set down and rebuilds the jump around a
concrete spec — **clear a 3-tile ledge, clear a 5-tile gap** — aiming for a heavier,
Hollow-Knight-ish weight instead of the previous twitchy feel.

Every value lives in `player_stats.tres`. No gameplay code changed; the only code edit is
a stale comment in `player.gd`.

---

## 1. Measurement basis

| | value | source |
|---|---|---|
| Tile | 8 × 8 px | `level_tileset.tres` (`tile_size`, `texture_region_size`) |
| Player collision | 12 × 20 px (**2.5 tiles tall**) | `Player.tscn` |
| Physics tick | 60 Hz | `project.godot` leaves the default |
| Viewport | 320 × 180 | `project.godot` |
| Platform thickness | 5 px | `DropThroughPlatform.tscn` |

**Numbers here come from simulation, not algebra.** `_apply_gravity()` switches between
four different gravity multipliers depending on `velocity.y`, and the apex hang band means
the ascent and descent aren't the same curve — closed-form `v²/2g` disagrees with the
engine by several px, which matters when the whole spec turns on a 3.6px margin.
`tools/sim_player_movement.py` reproduces the integration frame for frame (§8).

---

## 2. Before → after

| stat | before | after | note |
|---|---|---|---|
| `move_speed` | 125.0 | **63.0** | the headline change |
| `acceleration` | 800.0 | **420.0** | ~0.15s to top speed, unchanged in *feel* |
| `friction` | 550.0 | **340.0** | ~0.19s to a stop, short skid |
| `jump_velocity` | -250.0 | **-200.0** | |
| `gravity` | 700.0 | **620.0** | base; the multipliers do the shaping |
| `max_fall_speed` | 500.0 | **210.0** | biggest contributor to the drop-through fix |
| `coyote_time` | 0.1 | **0.12** | slower game, slightly more forgiving |
| `jump_buffer_time` | 0.1 | **0.12** | also widens the down+jump drop window |
| `ascend_gravity_mult` | 1.2 | **1.15** | |
| `fall_gravity_mult` | 1.5 *(was inheriting the script default)* | **1.35** | now set explicitly |
| `jump_hang_threshold` | 20.0 | **40.0** | doubles the apex float band |
| `jump_hang_gravity_mult` | 0.5 *(script default)* | **0.45** | now set explicitly |
| `jump_cut_gravity_mult` | 2.0 | 2.0 | unchanged |
| `pogo_velocity` | -270.0 | **-215.0** | keeps its ~1.08× ratio to the jump |
| `double_jump_velocity` | -230.0 | **-180.0** | keeps its ~0.90× ratio to the jump |
| `dash_speed` | 220.0 | **165.0** | |
| `dash_duration` | 0.17 | **0.22** | |
| `drop_through_velocity` | 80.0 *(script default)* | **40.0** | now set explicitly |
| `drop_through_time` | 0.2 | 0.2 | unchanged |

Two of the previous values (`fall_gravity_mult`, `jump_hang_gravity_mult`) were never in
the `.tres` at all — they were silently inheriting `player_stats.gd`'s defaults, which are
tuned for a completely different scale (`move_speed = 300`, `gravity = 1200`). Everything
the jump depends on is now written explicitly in the resource, so the feel no longer
changes if someone touches a script default.

---

## 3. Resulting arcs

| | before | after |
|---|---|---|
| Jump apex | 35.2px (4.41 tiles) | **27.6px (3.45 tiles)** |
| Jump span | 78.3px (9.79 tiles) | **45.8px (5.72 tiles)** |
| Jump airtime | 0.62s | **0.70s** |
| Short hop (jump released instantly) | 20.3px | **14.5px** |
| Jump + double jump apex | 64.8px (8.09 tiles) | **50.3px (6.29 tiles)** |
| Jump + double jump span | 129.0px (16.12 tiles) | **75.2px (9.40 tiles)** |
| Pogo apex | 41.4px (5.18 tiles) | **32.1px (4.01 tiles)** |
| Dash distance | 37.4px (4.68 tiles) | **36.3px (4.54 tiles)** |
| Terminal fall | 500px/s (62.5 tiles/s) | **210px/s (26.2 tiles/s)** |
| Full-screen fall | 0.36s | **0.86s** |
| Full-screen run | 2.56s | **5.08s** |
| Drop-through travel | 43.9px, exits at 308px/s | **29.6px, exits at 210px/s** |

Against the spec, single jump, running start:

| target | margin |
|---|---|
| 2-tile ledge (16px) | clears by 11.6px |
| **3-tile ledge (24px)** | **clears by 3.6px** ✅ |
| 4-tile ledge (32px) | fails by 4.4px |
| 4-tile gap (32px) | clears by 13.8px |
| **5-tile gap (40px)** | **clears by 5.8px** ✅ |
| 6-tile gap (48px) | fails by 2.2px |

Both boundaries are clean: 3 yes / 4 no, 5 yes / 6 no.

---

## 4. Why these numbers

### 4.1 Floatiness and horizontal reach are the same dial

This is the constraint that decided everything else, and it isn't obvious going in.

For a fixed jump height, gravity sets the airtime: `t_up = sqrt(2h/g)`. Lower gravity —
a floatier, heavier, more deliberate jump — means *more* time in the air. But horizontal
reach is just `move_speed × airtime`. So **"floatier" and "shorter horizontal reach" pull
against each other**, and with the height pinned at 3 tiles you cannot have both a floaty
arc and a fast run speed without overshooting the 5-tile gap.

Working backwards: a 3-tile apex with a genuinely floaty ~0.70s airtime allows roughly
`46px / 0.70s ≈ 65px/s` of run speed if the span is to stay near 5 tiles. That is where
`move_speed = 63` comes from — it is not a taste call, it's the value the rest of the spec
forces. A snappier, higher-gravity jump would have permitted a faster run, but that's the
feel we were moving away from.

### 4.2 Landing on the boundaries

`jump_velocity` was swept against the two "must fail" cases. At -190 the apex clears a
3-tile ledge by only 1.1px, which is inside the noise of a 60Hz discrete step. At -204 the
span reaches 48.4px and a 6-tile gap becomes jumpable, breaking the other end of the spec.

`-200` sits in the middle with a 3.6px vertical margin, and pairing it with `move_speed 63`
(rather than 65) pushes the 6-tile gap back out of reach by 2.2px. `max_fall_speed` turned
out to be irrelevant to the arc — 210 and 240 produce identical jumps, because the jump's
own landing speed never reaches either — so it was chosen purely for how sustained falls
read.

### 4.3 The drop-through fall

The complaint was about the drop specifically, but the initial nudge was the smaller half
of the problem:

- `drop_through_velocity` 80 → 40 halves the initial kick, so the drop starts as a release
  rather than a shove. It's still non-zero for the reason §3.4 of
  [`drop_through_platforms.md`](drop_through_platforms.md) gives — at zero the first frame
  visibly hesitates.
- `max_fall_speed` 500 → 210 and `fall_gravity_mult` 1.5 → 1.35 are what actually fix it.
  The old drop hit **308px/s within the 0.2s window and was still accelerating** toward a
  500px/s terminal; it now levels off at 210px/s. A full-screen fall went from 0.36s to
  0.86s.

`drop_through_time` stays at 0.2s. The window still needs to outlast the fall past the
platform's 5px shape plus its 7px one-way margin, and it comfortably does — 29.6px of
travel, down from 43.9px. Shortening it would have been the wrong lever anyway: the drop
felt fast because the *fall* was fast, not because the window was long.

### 4.4 Hollow Knight cross-check

Converting HK's units to this project's screen:

| | Hollow Knight | this project (after) |
|---|---|---|
| Screen crossing at run speed | ~4.6s | 5.08s |
| Jump span as % of screen width | ~16% | 14% |
| Jump apex as % of screen height | ~25% | 15% |

Run speed and horizontal reach land almost exactly on HK. **Jump height does not, and
can't** — see §7.

---

## 5. Feel changes beyond the raw numbers

**The apex hang band doubled.** `jump_hang_threshold` 20 → 40 means the reduced-gravity
band (`jump_hang_gravity_mult`, plus the `jump_hang_accel_mult` / `jump_hang_max_speed_mult`
air-control bonuses in `apply_horizontal_movement()`) now covers roughly the top 3px of the
arc in both directions instead of a sliver. This is most of what makes the jump read as
*heavy and floaty* rather than merely *slow* — the player hangs at the top and steers,
instead of tracing a symmetric parabola.

**Coyote and buffer both widened to 0.12s.** At the old speed 0.1s was ~12px of travel; at
63px/s it's ~7.5px, so the windows had effectively tightened even though the numbers hadn't
changed. The bump restores the old forgiveness in *distance* terms. This also widens the
gap allowed between the down and jump presses for a drop-through, since that reuses
`jump_buffer_time`.

**Dash distance was deliberately preserved** (37.4px → 36.3px, a 3% change) by trading
speed for duration. Everything else shrank by a third, so the dash is now *relatively* much
stronger — roughly 2.6× run speed instead of 1.8×. That's both HK-accurate and the
conservative choice for level design, since any existing geometry built around a dash gap
still works.

---

## 6. Level design implications

**Single-jump reach dropped a lot.** From 4 tiles up / 9.8 tiles across to 3 up / 5.7
across — the horizontal reach nearly halved. Any layout authored against the old arc needs
a pass. The double jump now covers 6.3 up / 9.4 across, which is close to what a *single*
jump used to do, so some jumps that were free will now cost the double jump.

**Known casualty: the `TestLevel2` drop-through platform.** Its top face is at world
y=140; the floor below it (columns 18–22 of the tilemap) is at y=168 — a **28px** rise.
The new apex is 27.6px, so it is now **0.4px out of reach from below**. It's still
approachable from the y=136 plateau on its left, and still reachable with the double jump,
but the single-jump path the drop-through test rig was built around is gone. Worth either
dropping that platform a tile or accepting the plateau approach — a level-design call, so
this pass left the geometry alone.

Quick budget for new geometry, single jump from a running start:

| | reachable |
|---|---|
| Ledge | up to 3 tiles |
| Gap | up to 5 tiles |
| Ledge, with double jump | up to 6 tiles |
| Gap, with double jump | up to 9 tiles |
| Gap, with dash | +4.5 tiles |

---

## 7. The 3-tile spec is short for the reference feel

Flagged because it will come up again: the player's collision box is 20px, **2.5 tiles**
tall. A 3-tile jump clears its own head by half a tile. Hollow Knight's jump is roughly
**3× the Knight's height**, which on this grid would be ~8 tiles.

The spec was built as asked and the numbers above are what it produces, but if the jump
ends up feeling cramped in practice, that ratio is the reason — not the gravity curve. The
fix is to scale the whole arc rather than nudge individual stats: raise `jump_velocity` and
`move_speed` together and re-run §8 to find the new ledge/gap boundaries.

If "3 tiles" was ever meant against a 16px grid rather than the tileset's actual 8px, that
would be exactly this rescale.

---

## 8. Re-tuning

`tools/sim_player_movement.py` reads `player_stats.gd`'s defaults, layers `player_stats.tres`
on top (Godot's own resolution order) and reports the arcs. It can't drift from the project.

```sh
python3 tools/sim_player_movement.py

# try values without touching the resource
python3 tools/sim_player_movement.py --set jump_velocity=-210 --set move_speed=70
```

It prints apex/span/airtime for jump, short hop, double jump, pogo and dash, the
ledge/gap margins from §3, and the drop-through travel. To reproduce the "before" column
of this document, override the seventeen pre-change values listed in §2.

---

## 9. Files

| file | change |
|---|---|
| `gameplay/player/resources/player_stats.tres` | all values in §2 |
| `gameplay/player/player.gd` | comment only — the look-ahead note cited "15px per physics tick", true only at the old `max_fall_speed` |
| `tools/sim_player_movement.py` | **new** — the simulation behind every number here |
| `docs/drop_through_platforms.md` | the two `drop_through_velocity` figures it quoted |

No gameplay logic changed. The state machine, the drop-through mechanic and the platform
classes are all untouched.
