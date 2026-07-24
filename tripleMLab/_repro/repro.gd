extends Node
## Headless repro driver for the "level auto-exits every other room" bug.
## Runs the real MainGame flow: map select -> level -> reach exit -> map -> next level.

var main: MainGame

func _ready() -> void:
	# Watchdog so a hang never blocks CI/terminal.
	get_tree().create_timer(30.0).timeout.connect(func():
		print("[REPRO] TIMEOUT watchdog hit, quitting")
		get_tree().quit(1)
	)
	_run()


func _ev(msg: String) -> void:
	print("[TIMELINE f%d/p%d] %s" % [Engine.get_process_frames(), Engine.get_physics_frames(), msg])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var main_scene: PackedScene = load("res://src/core/main_game/MainGame.tscn")
	main = main_scene.instantiate()
	add_child(main)
	await _frames(2)

	main.load_game()
	await _frames(2)

	# Pick a starting room on row 0 that is part of a path.
	var first_room: Room = null
	for room: Room in main.map.map_data[0]:
		if room.next_nodes.size() > 0:
			first_room = room
			break
	assert(first_room != null)

	# Timeline instrumentation
	main.player.tree_entered.connect(func(): _ev("player ENTER tree"))
	main.player.tree_exiting.connect(func(): _ev("player EXIT tree"))
	main.map.tree_entered.connect(func(): _ev("map ENTER tree"))
	main.map.tree_exiting.connect(func(): _ev("map EXIT tree"))

	var room: Room = first_room
	for level_index in 6:
		print("[REPRO] --- selecting room %d %s ---" % [level_index + 1, room])
		main.map._on_node_selected(room)
		var pre_xform: Transform2D = PhysicsServer2D.body_get_state(
			main.player.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
		print("[REPRO] IMMEDIATELY after select: server origin=%s node pos=%s" % [
			pre_xform.origin, main.player.global_position])
		await _frames(1)

		var lvl: BaseLevel = main._current_room as BaseLevel
		if lvl == null:
			print("[REPRO] level %d: _current_room is null right after select!" % (level_index + 1))
			break
		var n: int = level_index + 1
		lvl.tree_entered.connect(func(): _ev("level %d ENTER tree" % n))
		lvl.tree_exiting.connect(func(): _ev("level %d EXIT tree (queued free? %s)" % [n, lvl.is_queued_for_deletion()]))
		lvl.exited.connect(func(): _ev("level %d 'exited' signal emitted" % n))

		var srv_xform: Transform2D = PhysicsServer2D.body_get_state(
			main.player.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
		print("[REPRO] level %d: server-side body origin=%s node pos=%s" % [
			level_index + 1, srv_xform.origin, main.player.global_position])
		var spawn_pos: Vector2 = lvl.player_spawn.global_position
		var exit_pos: Vector2 = lvl.level_exit.global_position
		print("[REPRO] level %d: player=%s spawn=%s exit=%s dist_to_exit=%.1f" % [
			level_index + 1, main.player.global_position, spawn_pos, exit_pos,
			main.player.global_position.distance_to(exit_pos)])

		# Wait a few physics frames WITHOUT moving the player.
		var auto_exited: Array = [false]
		var cb: Callable = func(): auto_exited[0] = true
		lvl.exited.connect(cb)
		await _frames(10)

		if not is_instance_valid(lvl):
			print("[REPRO] level %d: LEVEL INSTANCE WAS FREED without emitting 'exited'! player=%s current_room=%s" % [
				level_index + 1, main.player.global_position, main._current_room])
			break
		if auto_exited[0]:
			print("[REPRO] level %d: AUTO-EXITED without player input! player=%s" % [
				level_index + 1, main.player.global_position])
		else:
			print("[REPRO] level %d: stable, walking player into exit" % (level_index + 1))
			var body_hit: Array = [false]
			var reach_hit: Array = [false]
			lvl.level_exit.body_entered.connect(func(b): body_hit[0] = true; print("[REPRO]   body_entered: %s" % b))
			lvl.level_exit.reached_exit.connect(func(): reach_hit[0] = true; print("[REPRO]   reached_exit fired"))
			main.player.global_position = exit_pos
			var waited: int = 0
			while not auto_exited[0] and waited < 60:
				await get_tree().physics_frame
				waited += 1
			if not auto_exited[0]:
				print("[REPRO] level %d: exit never fired?! diagnostics:" % (level_index + 1))
				print("[REPRO]   body_entered fired=%s reached_exit fired=%s" % [body_hit[0], reach_hit[0]])
				print("[REPRO]   player pos=%s inside_tree=%s" % [main.player.global_position, main.player.is_inside_tree()])
				print("[REPRO]   exit monitoring=%s monitorable=%s inside_tree=%s pos=%s" % [
					lvl.level_exit.monitoring, lvl.level_exit.monitorable,
					lvl.level_exit.is_inside_tree(), lvl.level_exit.global_position])
				print("[REPRO]   overlapping_bodies=%s" % [lvl.level_exit.get_overlapping_bodies()])
				print("[REPRO]   exited signal connections=%s" % [lvl.exited.get_connections()])
				print("[REPRO]   reached_exit connections=%s" % [lvl.level_exit.reached_exit.get_connections()])
				print("[REPRO]   body_entered connections=%s" % [lvl.level_exit.body_entered.get_connections()])
				break

		# Let the deferred exit_room run and map come back.
		await _frames(3)
		if not is_instance_valid(main.map) or main.map.get_parent() == null:
			print("[REPRO] level %d: map did not come back" % (level_index + 1))
			break

		room = main.map.last_room.next_nodes[0]

	print("[REPRO] done")
	get_tree().quit(0)
