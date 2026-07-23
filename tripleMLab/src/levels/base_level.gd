@abstract
class_name BaseLevel
extends Node2D
## Abstract class for all levels of all kinds

@abstract func get_default_player_spawn() -> Vector2

## Whether the run countdown should tick while this level is active.
## Overridden by levels where time can stand still (e.g. ShopLevel with the
## Chrono Anchor relic).
func should_tick_time() -> bool:
	return true
