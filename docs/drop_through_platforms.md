# Drop-through platforms

Hold **down** and press **jump** while standing on a drop-through platform and the player
falls through it instead of jumping.

This document covers the mechanic, the platform class hierarchy it sits in, the one-way
collision system it builds on, and why the implementation makes the choices it does.

---

## 1. The foundation: one-way platforms

Every platform in the game (`NormalPlatform`, `BreakingPlatform`, `DropThroughPlatform`)
derives from `JumpThroughPlatform` — an `AnimatableBody2D` with a one-way
`CollisionShape2D`. One-way collision means the player is stopped when landing on top but
passes freely when moving up through it from below.

**Collision layout**

| | value | where |
|---|---|---|
| Platform collision layer | 9 | `JumpThroughPlatform.COLLISION_LAYER` |
| Platform collision mask | 0 (platforms collide with nothing themselves) | `JumpThroughPlatform._ready()` |
| One-way direction | `Vector2(0, 1)` (blocks from above) | `JumpThroughPlatform._ready()` |
| One-way margin | 7.0 px | `JumpThroughPlatform.ONE_WAY_COLLISION_MARGIN` |
| Player collision layer | 2 | `Player.tscn` |
| `FloorCheck` mask | 256 (= layer 9) | `Player.tscn` |

### 1.1 Why the player toggles layer 9 every frame

Godot's built-in one-way collision alone isn't enough for a platformer: a body squeezing
past a platform's *side* edge can be caught by it, and a fast fall can tunnel straight
through. So `Player` does not permanently mask layer 9. Instead
`Player._update_platform_collision()` runs each physics frame and enables the layer-9
mask **only when a short downward `ShapeCast2D` (`FloorCheck`) sees a platform directly
beneath the feet**:

```gdscript
set_collision_mask_value(JUMP_THROUGH_PLATFORMS_LAYER, floor_check.is_colliding())
```

A downward ray can't be triggered by a platform's side edge, only by something actually
underfoot — which is what makes this robust where a `velocity.y > 0` check isn't.

The cast is also **stretched to cover the distance the player will travel this frame**
(`velocity.y * delta + FLOOR_CHECK_LOOKAHEAD_MARGIN`). Its resting length only clears the
feet by ~2px, but at `max_fall_speed` the player covers far more than that per tick;
without the look-ahead the feet step over the detection band, the mask is never enabled,
and the player tunnels through. This look-ahead matters to the drop-through code — see
§3.3.

It runs *after* `state_machine.physics_update()` and immediately before
`move_and_slide()`, so the look-ahead sees the velocity `move_and_slide` will actually
use.

---

## 2. Platform class hierarchy

```
AnimatableBody2D
└── JumpThroughPlatform            src/levels/level_objects/platforms/jump_through_platform.gd
    │   • layer 9, one-way from above, margin 7
    │   • _dynamic_sizing(): builds an N-tile-wide platform from left/center/right sprites
    │   • platform_height: px height of the art (default 6)
    ├── NormalPlatform             .../platforms/normal/normal_platform.gd
    ├── BreakingPlatform           .../platforms/breaking/breaking_platform.gd
    └── DropThroughPlatform        .../platforms/dropthrough_platforms/drop_through_platform.gd
            • platform_height = 5 (its art is 8x5, not 8x6)
            • otherwise pure marker type
```

`DropThroughPlatform` deliberately carries **no behaviour of its own**. Being droppable
isn't something the platform does — it's something the *player* is allowed to do to it.
The platform only has to be identifiable, and the class name is the identity:

```gdscript
if not collider is DropThroughPlatform:
    return []
```

The consequence worth knowing: this is an `is` check against a subclass, so
`NormalPlatform` and `BreakingPlatform` are **not** droppable, while any future subclass
of `DropThroughPlatform` automatically is.

### 2.1 `platform_height`

`_dynamic_sizing()` previously hardcoded a 6px platform height when sizing the collision
shape and the tiled center sprite region. The drop-through art is 8×5, so it was
stretching the region to 6px (tiling a 1px sliver of the texture back in) and making the
collision box 1px taller than the visual.

Height is now the `platform_height` var, which a subclass sets *before* calling
`super._ready()`. `NormalPlatform` and `BreakingPlatform` keep the 6.0 default and are
unchanged in behaviour.

---

## 3. The mechanic

### 3.1 Where it lives

The player follows a consistent `can_x()` / `consume_x()` convention for every ability
(jump, pogo, double jump, dash) — the state scripts ask, the player decides, the state
transitions. Drop-through follows it exactly:

```
StateIdle / StateRun .physics_update()
    ├── can_dash()        → DASH
    ├── can_pogo()        → POGO
    ├── not is_on_floor() → FALL
    ├── can_drop_through()  →  consume_drop_through()  →  FALL     ← new
    └── can_jump()        → JUMP
```

**Ordering is load-bearing.** The drop check sits immediately *before* `can_jump()`,
because both are satisfied by the same jump press. Checked in this order, down + jump
drops; checked the other way, it would always jump and the mechanic would be dead code.

Only `StateIdle` and `StateRun` check it — you have to be standing on the platform.
`StateFall`, `StateJump`, `StateDoubleJump`, `StatePogo` and `StateDash` are untouched.

### 3.2 Trigger conditions

```gdscript
func can_drop_through() -> bool:
    if not is_on_floor() or jump_buffer_timer <= 0.0:
        return false
    if not Input.is_action_pressed("down"):
        return false
    return not _get_platforms_underfoot().is_empty()
```

- **`jump_buffer_timer > 0.0`** rather than `Input.is_action_just_pressed("jump")`. The
  buffer is already set by `_update_timers()` on the jump press and lasts
  `stats.jump_buffer_time` (0.1s), so the down press and the jump press don't have to land
  on the same frame in either order. It's the same forgiveness window the normal jump
  gets, for free.
- **`down` is polled, not buffered.** It's a held modifier, not a discrete input, so
  `Input.is_action_pressed`. (Note `_direction_stack` only tracks left/right; vertical
  input is polled directly, matching how `jump` and `attack` are handled.)
- **`consume_jump()`** is called on the drop, zeroing `coyote_timer` and
  `jump_buffer_timer` so the jump doesn't also fire on the following frame.

### 3.3 Identifying what's underfoot

```gdscript
func _get_platforms_underfoot() -> Array[DropThroughPlatform]:
    var platforms: Array[DropThroughPlatform] = []
    floor_check.target_position.y = _floor_check_reach   # ← reset the look-ahead
    floor_check.force_shapecast_update()
    for i in floor_check.get_collision_count():
        var collider: Object = floor_check.get_collider(i)
        if not collider is DropThroughPlatform:
            return []
        platforms.append(collider)
    return platforms
```

Two subtleties:

**The cast is reset to its resting length first.** `FloorCheck` is shared with
`_update_platform_collision()`, which stretches it during falls (§1.1). On the frame the
player lands, the cast still holds the previous frame's extended reach — up to ~10px —
which would reach *past* the platform being stood on and pick up whatever sits below it.
Resetting to `_floor_check_reach` makes the query mean exactly "what am I standing on".
`_update_platform_collision()` re-sets `target_position` before its own cast, so nothing
leaks back the other way.

**All-or-nothing.** If *any* body underfoot isn't a `DropThroughPlatform`, the function
returns an empty array and the drop is refused. At a seam where a drop-through platform
butts against a solid one, the solid platform would hold the player up anyway — but the
jump would already have been consumed, silently eating the input. Refusing the drop means
the player gets their jump instead.

### 3.4 Executing the drop

```gdscript
func consume_drop_through() -> void:
    _dropped_platforms = _get_platforms_underfoot()
    for platform in _dropped_platforms:
        add_collision_exception_with(platform)
    _drop_through_timer = stats.drop_through_time
    velocity.y = stats.drop_through_velocity
    consume_jump()
```

**Collision exceptions, not the collision mask.** The obvious implementation is to clear
the layer-9 mask for a moment — the machinery is already there. But layer 9 is *every*
one-way platform in the level, so clearing it would let the player fall straight through
the next platform down as well. `add_collision_exception_with()` suppresses collision
with **only the specific platform instances being dropped through**, leaving everything
else in the fall path solid. Verified: with a second platform 60px below, the player drops
through the top one and lands on the lower one.

**Released on a timer, not on losing contact.** Ending the exception the moment
`FloorCheck` stops seeing the platform would re-enable collision while the player's body
is still inside the shape, where the 7px one-way margin can shove them back up. A fixed
`drop_through_time` (0.2s ≈ 12 frames) puts the player ~30px clear of a 5px platform
before collision returns — comfortably past the shape plus its margin. Because the
exception is per-instance, a generous window costs nothing.

**The downward nudge.** `velocity.y = stats.drop_through_velocity` (40 in
`player_stats.tres`). Without it,
`_apply_gravity()` early-returns while `is_on_floor()` is still true, so the first frame
of the drop has zero downward velocity and the player appears to hesitate. The nudge also
guarantees separation from the platform on the very first frame.

### 3.5 Releasing the exception

```gdscript
func _end_drop_through() -> void:
    for platform in _dropped_platforms:
        if is_instance_valid(platform):
            remove_collision_exception_with(platform)
    _dropped_platforms.clear()
```

Called from two places:

- `_update_timers()`, when `_drop_through_timer` hits zero.
- `reset_physics()`, which `MainGame.exit_room()` already calls on room exit. Rooms free
  their platforms, hence the `is_instance_valid()` guard — without it a room change
  mid-drop would touch freed objects.

---

## 4. Tunables

`PlayerStats` (`src/gameplay/player/player_stats.gd`), overridable per-resource in
`player_stats.tres`:

| stat | default | effect |
|---|---|---|
| `drop_through_velocity` | 80.0 (**40.0** in `player_stats.tres`) | initial downward speed. Raise for a snappier "yank" down, lower for a softer release. How fast the drop *reads* is governed far more by `max_fall_speed` and `fall_gravity_mult` — see [`player_movement_tuning.md`](player_movement_tuning.md) §4.3. |
| `drop_through_time` | 0.2 | how long the platform is ignored. Only needs to outlast the fall past the platform's shape + one-way margin; the per-instance exception means over-shooting is harmless. |

Reused from existing stats: `jump_buffer_time` sets how far apart the down and jump
presses may be.

`platform_height` on `JumpThroughPlatform` is per-subclass, not per-instance.

---

## 5. Verified behaviour

Exercised with a temporary headless harness (`godot --headless`), driving synthetic input
into a real `Player.tscn` against real platform instances:

| scenario | result |
|---|---|
| down + jump on a drop-through platform | falls through; never rises above its resting position |
| drop with another platform 60px below | passes the top platform, lands on the lower one |
| jump alone (no down) | normal jump, no drop |
| down + jump on a `NormalPlatform` | jumps — normal platforms aren't droppable |
| drop-through + solid platform at the same height underfoot | jumps; no half-drop, jump not eaten |
| drop-through 40 / 28 / 24 / 20 / 16 / 12px above a solid floor | lands on the floor at the correct height in every case, no pop-up — including the tight cases where the platform's shape still overlaps the player's body when the exception is released |
| collision-exception lifecycle | 0 → 1 on the drop frame → 0 twelve frames later; none leak |

The last row matters for level design: because the one-way margin ignores deep
penetration, **a drop-through platform placed close above a floor still behaves
correctly** — there is no minimum clearance to respect.

---

## 6. Level design notes

- Instance `src/levels/level_objects/platforms/dropthrough_platforms/DropThroughPlatform.tscn`
  and set `size` (tile count, 8px per tile). Everything else configures itself in
  `_ready()`.
- `TestLevel2.tscn` has one at `(136, 140)`, size 4 — 28px above the floor, reachable with
  a single jump from the ground, for manual testing.
- Its art is visually thinner (5px) than normal platforms (6px), which reads as
  "insubstantial" — worth keeping, it signals droppability without a tutorial.

---

## 7. Files

| file | change |
|---|---|
| `platforms/dropthrough_platforms/drop_through_platform.gd` | **new** — `DropThroughPlatform` marker class |
| `platforms/dropthrough_platforms/DropThroughPlatform.tscn` | script swapped from `JumpThroughPlatform` to `DropThroughPlatform` |
| `platforms/jump_through_platform.gd` | `platform_height` replaces the hardcoded 6px in `_dynamic_sizing()` |
| `gameplay/player/player.gd` | `can_drop_through()`, `consume_drop_through()`, `_end_drop_through()`, `_get_platforms_underfoot()`; timer tick; `reset_physics()` cleanup |
| `gameplay/player/player_stats.gd` | `drop_through_velocity`, `drop_through_time` |
| `gameplay/player/states/state_idle.gd` | drop check before the jump check |
| `gameplay/player/states/state_run.gd` | drop check before the jump check |
| `levels/test_levels/TestLevel2.tscn` | one `DropThroughPlatform` instance |
