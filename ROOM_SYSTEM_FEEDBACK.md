# Room system — bug diagnosis & feedback

## The "kicked out every second level" bug

### Symptom
Finish level 1, pick the next node on the map, and the new level immediately
dumps you back on the map. It then works again for the next level, and breaks
on the one after — every two levels.

### Diagnosis (verified with a headless repro, not guessed)
The player node is reused across rooms: `exit_room()` removes it from the tree
and `enter_level()` re-adds it. When it was removed, the player was standing on
the previous level's `LevelExit`.

`BaseLevel._ready()` correctly moves the node to `PlayerSpawn` — but the
**physics server** only picks up a body's new position on its next physics
step, and Area2D overlap pairing inside that step runs against the body's
*stale* transform. So for one physics tick, the player's physics body is still
at the old level's exit position. Since every level is currently the same
scene, that stale position exactly overlaps the *new* level's `LevelExit` →
`body_entered` fires on tick one → `reached_exit` → `exited` → `exit_room()`.

This was confirmed empirically: right after entering level 2,
`PhysicsServer2D.body_get_state(...)` reports the body at `(453, 310)` (the
exit) while the node reports `(163, 312)` (the spawn). Neither
`force_update_transform()` nor a direct `PhysicsServer2D.body_set_state()`
write closes the gap before the pairing happens.

The every-two-levels rhythm falls out naturally: a broken level ends with the
player *at spawn* (they never moved), so the next level enters cleanly; a
cleanly played level ends with the player *at the exit*, so the level after
breaks. Mauro's hypothesis — "the player starts in the exit's position" — was
right, just one layer down: it's the physics body, not the visible node.

### Fix
`level_exit.gd` now arms itself only after the first physics tick
(`monitoring = false` in `_ready()`, re-enabled two physics frames later).
By then the player's body has synced to the spawn position, so the exit only
ever sees real overlaps. No changes to the room-loading system.

Note the fix is not "same scene twice" specific: any future level whose exit
happens to sit near where the previous level's exit was would have had the
same bug.

### Repro / regression check
`tripleMLab/_repro/` contains a headless driver that plays 6 consecutive
levels through the real map → level → exit → map flow:

```
cd tripleMLab && godot --headless _repro/Repro.tscn
```

Before the fix it prints `LEVEL INSTANCE WAS FREED without emitting 'exited'`
on level 2; after the fix all six levels enter stably and exit only when the
player is walked into the exit. Feel free to delete the folder if you don't
want it in the repo.

---

## What's good about the system

- **Container-based scene management in `MainGame`.** One `load_scene` /
  `unload_scene` / `change_scene` API keyed by `SceneContainer`, with tracked
  active instances per container. Simple, predictable, and it makes the
  map ↔ room swap easy to reason about (which is exactly what made this bug
  diagnosable).
- **`RoomScene` as a minimal contract.** Rooms only need to emit `exited`;
  `MainGame` doesn't care what happens inside. The
  `CONNECT_DEFERRED | CONNECT_ONE_SHOT` connection is a nice touch — it avoids
  freeing the level mid-physics-callback and can't double-fire.
- **Keeping one persistent `Player` and reparenting it** is the right call for
  a run-based game (upgrades/state carry across rooms for free). The bug was
  an engine quirk of this pattern, not a flaw in the pattern itself.
- **The map generator** is a clean Slay-the-Spire-style implementation:
  path crossing prevention, weighted room types, rule hooks
  (no early heals, no consecutive shops) already stubbed for tuning.
- **TODO discipline.** The TODOs in `main_game.gd` accurately describe the
  known gaps (room type routing, transitions) and even sketch the intended
  final shape. Genuinely helpful when reading the code cold.
- **`UIDs` autoload** keeps scene references in one place instead of magic
  strings scattered around.

## What could be improved

- **`LevelExit` accepts any body.** `_on_body_entered(_body)` fires for
  whatever matches the collision mask. It works today because mask layer 2 is
  player-only, but an enemy or projectile on that layer would end the level.
  Cheap guard: `if _body is Player:`.
- **Player velocity carries across rooms.** Only position is reset in
  `_place_player_at_spawn()`; `velocity` survives from the previous level, so
  the player enters a new level with whatever momentum they exited with.
  Consider `player.velocity = Vector2.ZERO` alongside the position reset.
- **Room type is ignored on selection.** `load_game()` connects
  `map.selected` to `enter_room(room.scene_uid, Room.Type.LEVEL)` — hardcoded
  `LEVEL`, so SHOP/HEAL nodes silently load as combat levels. Already noted in
  the TODOs; flagging it because `Room` *does* carry `type` and `scene_uid`,
  so the plumbing is nearly there: `enter_room(room.scene_uid, room.type)`.
- **Selection is emitted from an animation method track.** `MapNode`'s
  `selected` signal fires from a call-method key at the end of the "selected"
  animation. That couples game flow to animation data: re-timing or replacing
  the animation can silently break room entry, and the 0.5 s delay is
  invisible in code. Safer: emit from `_on_input_event` and let the animation
  be purely cosmetic (or `await animation_player.animation_finished` in code).
- **`enter_room` error path leaves the game stuck.** If `_current_room` ends
  up null (e.g. a SHOP node today), the map has already been removed from the
  tree and nothing re-adds it — the run soft-locks with a `push_error`. Until
  the other room types exist, either route unknown types back to
  `world.add_child(map)` or only remove the map after the room loaded.
- **`Map.unlock_next_nodes()` trusts `last_room`.** It dereferences
  `last_room` unconditionally; if `exit_room()` ever runs without a prior
  selection (or after a future "restart run"), it null-crashes. A one-line
  guard makes it safe.
- **Minor:** `map_widht_pixels` typo in `map.gd`; `RoomScene`'s doc comment
  says "emit `finished`" but the signal is named `exited`.
