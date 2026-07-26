@tool
class_name DropThroughPlatform
extends JumpThroughPlatform

# Marker type: the player checks for this class under its feet to decide whether
# jump + down should drop it through the platform instead of jumping.
# See Player.can_drop_through()

# Lifecycle
func _ready() -> void:
	platform_height = 5.0
	super._ready()
