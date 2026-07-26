# Levels

## Adding a level to the run

Drop the `.tscn` into `tripleMLab/src/levels/initial_levels/`. That is the whole
process — nothing has to be registered and no uid has to be copied anywhere.

`LevelPool` (`src/gameplay/systems/level_pool.gd`) scans that directory when a
map is generated and deals every LEVEL room out of it. Levels come from a
shuffled bag, so a run uses every level in the directory once before it repeats
any of them.

A level must extend `BaseLevel` and contain a `PlayerSpawn` and a `LevelExit`
marked as scene-unique (`%`) — see `src/levels/LevelTemplate.tscn`.

`src/levels/test_levels/` is deliberately *not* scanned. Anything in there stays
out of the rotation.

## The final level

The last room on every map is `Room.Type.FINAL`, and it loads a scene from
`tripleMLab/src/levels/final_level/`. Put exactly one `.tscn` in there and it
becomes the run's finale; put several and one is picked at random per run.

Walking into that level's exit ends the run in a win (`MainGame.end_run(true)`).

If the directory is empty the pool logs a warning and falls back to an ordinary
level, so a build always finishes rather than dead-ending on a room that won't
load.

## Losing

`TimeSystem` emits `time_expired` when the fuse reaches zero.
`MainGame._on_time_expired()` plays the player's `detonation` animation, then
shows the same run-end screen with the loss wording. "Try Again" tears the run
down (`_teardown_run`) and deals a fresh map without going back to the title.
