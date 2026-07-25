class_name NormalPlatform
extends JumpThroughPlatform

const SINGLE_TEXURE_UID: String = "uid://tn0cnmwdfhfw"

func _ready() -> void:
	super._ready()
	if size == 1:
		center_sprite.texture = load(SINGLE_TEXURE_UID)
