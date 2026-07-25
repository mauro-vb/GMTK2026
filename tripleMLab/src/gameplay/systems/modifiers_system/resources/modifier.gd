class_name Modifier
extends Resource

# Signals
# Enums
enum Type { ENTER_LEVEL, EXIT_LEVEL, EVENT_BASED }
# Constants

# Exports
@export var type: Type = Type.EVENT_BASED
@export var stackable: bool = false
@export var modifier_name: String
@export var id: String
@export var icon: Texture 
@export_multiline var description: String


func trigger_modifier() -> void:
	pass
	
func deactivate_modifier() -> void:
	pass
	
func get_description() -> String:
	return description
