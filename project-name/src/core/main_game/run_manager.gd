class_name RunManager
extends Node
## Stores the current run's progression.
## Does not load levels or show UI.
## MainGame drives the flow and asks RunManager what comes next.

signal current_node_changed(node: RunNode)
signal run_completed

var _root_node: RunNode = null
var _current_node: RunNode = null


func start_run(root: RunNode) -> void:
	_root_node = root
	_current_node = root

	current_node_changed.emit(_current_node)


func get_current_node() -> RunNode:
	return _current_node


func get_current_level() -> PackedScene:
	if _current_node == null:
		return null

	return _current_node.level_scene


func get_available_paths() -> Array[RunNode]:
	if _current_node == null:
		return []

	return _current_node.next_nodes


func choose_path(node: RunNode) -> bool:
	if _current_node == null:
		return false

	if not _current_node.next_nodes.has(node):
		push_error("Attempted to choose an invalid path.")
		return false

	_current_node = node
	current_node_changed.emit(_current_node)

	return true


func complete_current_node() -> void:
	if _current_node == null:
		return

	if _current_node.next_nodes.is_empty():
		run_completed.emit()
