class_name UIScreen
extends Control
## Base class for every full-screen menu/overlay (start menu, pause menu,
## settings, game over). Provides the three things every screen needs and that
## are easy to forget per-screen:
##  - a short fade-in on appear and an awaitable fade-out on dismiss
##  - initial focus grab, so keyboard/controller users can always navigate
##  - uniform back handling: ui_cancel emits `back_requested`, the topmost
##    screen consumes the event (submenus close before their parent)
##
## Screens open submenus with `open_submenu()`: the parent hides and suspends
## its own back handling until the child reports back. This gives stacked-menu
## behavior (pause -> settings -> back) without a separate stack manager.

signal back_requested

const FADE_IN_TIME: float = 0.15
const FADE_OUT_TIME: float = 0.1

## Grabbed when the screen appears. Point this at the primary button.
@export var initial_focus: Control

var _submenu: UIScreen = null


func _ready() -> void:
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	grab_initial_focus()


func grab_initial_focus() -> void:
	if initial_focus != null:
		initial_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# While a submenu is open it owns the cancel action; this screen stays quiet.
	if _submenu != null:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


## Fades out and frees the screen. Await this before e.g. unpausing, so the
## fade still has processing time to run.
func dismiss() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	await tween.finished
	queue_free()


## Hides this screen and shows `scene` in its place (as a sibling, so it lives
## on the same canvas layer). When the child emits back_requested it is
## dismissed and this screen returns with focus restored.
func open_submenu(scene: PackedScene) -> void:
	var child: UIScreen = scene.instantiate() as UIScreen
	if child == null:
		push_error("UIScreen.open_submenu: '%s' is not a UIScreen" % scene.resource_path)
		return
	_submenu = child
	child.back_requested.connect(_on_submenu_back.bind(child))
	get_parent().add_child(child)
	hide()


func _on_submenu_back(child: UIScreen) -> void:
	_submenu = null
	await child.dismiss()
	show()
	grab_initial_focus()
