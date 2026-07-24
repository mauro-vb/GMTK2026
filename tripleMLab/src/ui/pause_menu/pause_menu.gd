class_name PauseMenu
extends UIScreen
## In-run pause overlay. Lives on the PauseLayer (PROCESS_MODE_WHEN_PAUSED) so
## it animates while the tree is paused. Emits intent signals; MainGame owns
## what actually happens (unpausing, tearing down the run).
##
## Cancel behavior follows the "close topmost layer" rule:
##   settings open   -> UIScreen submenu handling closes settings
##   confirm open    -> back to the main pause list
##   otherwise       -> resume

signal resume_requested
signal abandon_requested

const SETTINGS_SCENE: PackedScene = preload("res://src/ui/settings_menu/SettingsMenu.tscn")

@onready var main_box: VBoxContainer = %MainBox
@onready var confirm_box: VBoxContainer = %ConfirmBox
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var abandon_button: Button = %AbandonButton
@onready var quit_button: Button = %QuitButton
@onready var confirm_abandon_button: Button = %ConfirmAbandonButton
@onready var cancel_abandon_button: Button = %CancelAbandonButton


func _ready() -> void:
	super()
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	settings_button.pressed.connect(func() -> void: open_submenu(SETTINGS_SCENE))
	abandon_button.pressed.connect(_show_confirm.bind(true))
	confirm_abandon_button.pressed.connect(func() -> void: abandon_requested.emit())
	cancel_abandon_button.pressed.connect(_show_confirm.bind(false))
	back_requested.connect(_on_back)

	# Desktop-only affordance; web builds live inside a page.
	quit_button.visible = not OS.has_feature("web")
	quit_button.pressed.connect(func() -> void: Global.main_game.quit_game())

	confirm_box.hide()


func _on_back() -> void:
	if confirm_box.visible:
		_show_confirm(false)
	else:
		resume_requested.emit()


func _show_confirm(show_confirm: bool) -> void:
	confirm_box.visible = show_confirm
	main_box.visible = not show_confirm
	if show_confirm:
		# Focus the safe option: backing out of an abandon should be effortless.
		cancel_abandon_button.grab_focus()
	else:
		abandon_button.grab_focus()
