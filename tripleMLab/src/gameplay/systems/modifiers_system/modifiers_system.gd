class_name ModifiersSystem
extends Node

# Signals
signal modifier_added(modifier: Modifier)
signal modifier_removed(modifier: Modifier)

# Enums
# Constants

# Exports

# Public
var modifiers: Array[Modifier] = []
# Private
# On Ready

# Static

# Lifecycle
func _ready() -> void:
	pass

# Public
func activate_modifiers(type: Modifier.Type) -> void:
	if type == Modifier.Type.EVENT_BASED:
		return
	var filter: Callable = func(m: Modifier) -> bool: return m.type == type
	for modifier: Modifier in modifiers.filter(filter):
		modifier.trigger_modifier()


func add_modifier(modifier: Modifier) -> void:
	if has_modifier(modifier.id) and not modifier.stackable:
		return
	if modifier.type == Modifier.Type.EVENT_BASED:
		modifier.trigger_modifier()
	modifiers.append(modifier)
	modifier_added.emit(modifier)
	
func remove_modifier(modifier: Modifier) -> void:
	if not has_modifier(modifier.id):
		push_error("Couldn't remove %s, because it doesn't exist" % [modifier.modifier_name])
		return
	modifiers.erase(modifier)
	modifier_removed.emit(modifier)
		
func has_modifier(id: String) -> bool:
	for modifier: Modifier in modifiers:
		if modifier.id == id:
			return true
			
	return false
