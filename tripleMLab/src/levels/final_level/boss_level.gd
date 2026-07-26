class_name BossLevel
extends BaseLevel
## The Barrage — the final room. One screen, no enemy, seventy seconds.
##
## There is nothing here with health. The boss *is* the barrage, and the fight is
## won by still being alive when it stops. What the player spends to get there is
## the run's clock: [b]the seconds carried into this room are the health bar[/b],
## and every orb that connects takes [constant HIT_COST] of them.
##
## That is why the scene sets `should_tick_time = false`. If the clock also
## drained on its own, two things would break at once — the second count would
## stop reading as HP, because it would be falling whether or not the player was
## being hit, and the fight would be unwinnable for anyone who walked in on less
## than seventy seconds no matter how well they dodged. With the drain off, the
## number in the HUD only ever moves when the player is hit, and the fight is
## the same length for everybody. The seventy seconds are counted by
## [member _fight_time] here, which has nothing to do with [TimeSystem].
##
## One script owns all three phases: a phase, an elapsed timer, and a spawn
## accumulator per stream. Every number the fight is made of is a const at the
## top of this file, so tuning it means editing that block and nothing else.
##
## Phases, in order (see [enum Phase]):
## [codeblock]
## 0-20s  GROUND RUSH  orbs along the floor, from the right. The answer is a jump.
## 20-42s RAIN         orbs fall on where the player was 0.8s ago. Three platforms appear.
## 42-70s CROSSFIRE    both streams at 70% rate, plus a wall with one gap in it.
## [/codeblock]

# Signals

# Enums
enum Phase { GROUND_RUSH, RAIN, CROSSFIRE }

# Constants
const PROJECTILE_SCENE: PackedScene = preload("res://src/levels/level_objects/boss_projectile/BossProjectile.tscn")
## Telegraph markers are the projectile's own texture, dimmed and shrunk — the
## marker and the thing it promises should obviously be the same object.
const MARKER_TEXTURE: Texture2D = preload("uid://dl6hdiixm8xoi")

# --- Arena -------------------------------------------------------------------
const ARENA_WIDTH: float = 320.0
## Where an orb is parked when it is meant to be off-screen right, and the
## height a falling one starts at.
const OFFSCREEN_RIGHT_X: float = 336.0
const OFFSCREEN_TOP_Y: float = -8.0
## Keeps a falling orb's lane off the side walls, where it would be undodgeable.
const SPAWN_MARGIN_X: float = 16.0

# --- Phases ------------------------------------------------------------------
## The second each phase ends on, indexed by [enum Phase]. The last entry is the
## whole fight, and the only place its length is written down.
const PHASE_END_TIMES: Array[float] = [20.0, 42.0, 70.0]

## Ramped values are authored as Vector2(start_of_phase, end_of_phase) and read
## off the phase's own progress — see [method _ramp].

# --- Phase 1: ground rush ----------------------------------------------------
const RUSH_INTERVAL: Vector2 = Vector2(1.4, 0.55)
const RUSH_SPEED: Vector2 = Vector2(60.0, 110.0)
## Orb centre height along the floor. The floor surface is at y=168 and the
## player's body is 12px tall, so 160 sits squarely in a standing player: no
## crouch, no sidestep, the only answer is the jump this phase is teaching.
const RUSH_Y: float = 160.0

# --- Phase 2: rain -----------------------------------------------------------
const RAIN_INTERVAL: Vector2 = Vector2(1.2, 0.7)
const RAIN_SPEED: Vector2 = Vector2(90.0, 130.0)
## How far back a drop samples the player's x when it picks a lane. Standing
## still means the drop is already aimed at you; moving means it is aimed at
## where you were.
const RAIN_LEAD: float = 0.8
## How long the marker is up before the drop it announces. No falling orb ever
## appears without one.
const RAIN_TELEGRAPH: float = 0.5
const RAIN_MARKER_Y: float = 8.0

# --- Phase 3: crossfire ------------------------------------------------------
## Phases 1 and 2 keep running underneath the sweeps, at this fraction of the
## spawn rate they finished on. Layering readable patterns is what makes this
## phase hard; at 320x180 raising the density instead just makes it noise.
const CROSSFIRE_STREAM_RATE: float = 0.7
const SWEEP_PERIOD: float = 5.0
const SWEEP_TELEGRAPH: float = 0.8
## Kept a little under the ground stream's top speed, so the wall reads as its
## own thing arriving rather than as the rush suddenly getting taller.
const SWEEP_SPEED: float = 95.0
## Centre-to-centre spacing of the wall's orbs. At 8px across they leave 4px
## between them, which nothing the player is 7x12 fits through.
const SWEEP_ORB_SPACING: float = 12.0
const SWEEP_TOP_Y: float = 12.0
const SWEEP_BOTTOM_Y: float = 160.0
## Distance from the gap's centre to the centre of the nearest orb either side.
## The brief asked for a 1.5-tile gap (12px), but the player's body is itself
## 12px tall — that is a hole they cannot fit through at any height. 14 leaves
## 20px of daylight for a 12px body: still something you have to be lined up
## with, but something that exists.
const SWEEP_GAP_HALF_HEIGHT: float = 14.0
## Gap centres, cycled in order. Each one is a standing player's midpoint on one
## of the three surfaces the arena offers — the floor at 168, the two outer
## platforms at 128, and the middle platform at 96 — so the read is always
## "where is the hole, and what do I have to be standing on to be in it".
## These track the platform heights in BossLevel.tscn; move a platform and the
## gap that belongs to it moves with it.
const SWEEP_GAP_CENTRES: Array[float] = [162.0, 122.0, 90.0]
## Where the two gap-edge markers sit, just inside the right wall.
const SWEEP_MARKER_X: float = 306.0

# --- Getting hit -------------------------------------------------------------
const HIT_COST: float = 3.0
const INVULNERABLE_TIME: float = 0.6
## Half-period of the invulnerability flash.
const FLASH_INTERVAL: float = 0.075
const FLASH_ALPHA: float = 0.25
const HIT_FLASH_ALPHA: float = 0.45
const HIT_FLASH_TIME: float = 0.18
const SHAKE_STRENGTH: float = 3.0
const SHAKE_TIME: float = 0.25

# --- Presentation ------------------------------------------------------------
const MARKER_MODULATE: Color = Color(0.45, 0.09, 0.11)
const MARKER_SCALE: float = 0.7
const MARKER_PULSE_SPEED: float = 9.0
const MARKER_MIN_ALPHA: float = 0.3

## The notches cut into the survival bar at each phase boundary. Coloured to
## match the bar's own background, so a phase change reads as the red passing a
## gap in itself rather than as a line drawn on top of it.
const PHASE_TICK_COLOR: Color = Color(0.16862746, 0.16078432, 0.28235295)
const PHASE_TICK_WIDTH: float = 1.0

const PLATFORM_REVEAL_TIME: float = 0.5
## How far below their resting place the phase-2 platforms start.
const PLATFORM_REVEAL_RISE: float = 10.0
const EXIT_REVEAL_TIME: float = 0.6

## How much player-position history is kept, in seconds. Only needs to cover
## RAIN_LEAD with room to spare.
const HISTORY_LENGTH: float = 2.0

# Exports

# Public

# Private
var _fighting: bool = false
## Seconds survived. The fight's own clock, deliberately unrelated to
## [TimeSystem] — see this class's doc comment.
var _fight_time: float = 0.0
var _phase: Phase = Phase.GROUND_RUSH

var _rush_timer: float = 0.0
var _rain_timer: float = 0.0
var _sweep_timer: float = 0.0
var _next_gap_index: int = 0

var _invulnerable_time: float = 0.0
var _flash_time: float = 0.0
var _shake_time: float = 0.0

var _telegraphs: Array[Telegraph] = []
## Samples of where the player has been, as Vector2(fight_time, x).
var _position_history: Array[Vector2] = []

var _platform_tween: Tween = null

var _time_system: TimeSystem = null
var _player: Player = null

# On Ready
@onready var projectiles: Node2D = %Projectiles
@onready var markers: Node2D = %Markers
@onready var phase_2_platforms: Node2D = %Phase2Platforms
@onready var survival_bar: ProgressBar = %SurvivalBar
@onready var hit_flash: ColorRect = %HitFlash

# Static


## A spawn that has been announced but not yet fired. Everything the barrage
## throws after phase 1 goes through one of these, because the rule the fight is
## built on is that nothing appears without having been promised first.
class Telegraph:
	var markers: Array[Sprite2D] = []
	var remaining: float = 0.0
	var duration: float = 0.0
	## Called once, when `remaining` runs out.
	var spawn: Callable


# Lifecycle
func _ready() -> void:
	super._ready()

	if Global.main_game == null:
		push_error("BossLevel needs MainGame — the fight spends the run's clock.")
		return

	_time_system = Global.main_game.time_system
	_player = Global.main_game.player

	_build_phase_ticks()
	_disable_exit()
	_start_fight()


func _physics_process(delta: float) -> void:
	_update_invulnerability(delta)
	_update_shake(delta)

	if not _fighting:
		return

	_fight_time += delta
	_record_position()
	_update_phase()
	_update_telegraphs(delta)
	_update_spawning(delta)
	_update_hud()

	if _fight_time >= _fight_duration():
		_on_survived()


func _exit_tree() -> void:
	# Neither of these lives on this scene, so neither is cleaned up by the room
	# being freed: the viewport survives the room, and the player is only
	# re-parented out of it.
	_set_canvas_offset(Vector2.ZERO)
	if _player != null:
		_player.modulate.a = 1.0
		_player.can_move = true


# Public
## Reports that a projectile reached the player. Returns whether the hit landed
## — false means the player is inside the invulnerability window and the caller
## should keep flying rather than being consumed.
##
## The whole damage rule lives here rather than in [BossProjectile] because the
## invulnerability window is a property of the fight, not of any one orb.
func report_hit() -> bool:
	if not _fighting or _invulnerable_time > 0.0:
		return false

	_invulnerable_time = INVULNERABLE_TIME
	_flash_time = 0.0
	_shake_time = SHAKE_TIME
	_flash_screen()

	# Straight at the clock. See BossProjectile's class doc for why this doesn't
	# go anywhere near ModifiersSystem.
	_time_system.remove_time(HIT_COST)

	# TimeSystem emits time_expired — the signal MainGame ends the run on — only
	# from its own _process, which returns early while `ticking` is false. It is
	# false for this whole room by design, so nothing upstream will ever notice
	# this death and the room has to notice it itself, here, at the moment the
	# seconds are spent.
	if _time_system.current_time <= 0.0:
		_on_defeated()

	return true


# Private
## Puts every fight-local counter back to its opening value. Called on entry and
## again on each retry, which is what lets the retry stay in place instead of
## reloading the scene.
func _start_fight() -> void:
	_fight_time = 0.0
	_phase = Phase.GROUND_RUSH
	_rush_timer = RUSH_INTERVAL.x
	_rain_timer = 0.0
	_sweep_timer = 0.0
	_next_gap_index = 0
	_invulnerable_time = 0.0
	_flash_time = 0.0
	_position_history.clear()

	_hide_platforms()
	_enter_phase()
	_update_hud()
	_fighting = true


func _fight_duration() -> float:
	return PHASE_END_TIMES[PHASE_END_TIMES.size() - 1]


func _phase_at(time: float) -> Phase:
	if time < PHASE_END_TIMES[Phase.GROUND_RUSH]:
		return Phase.GROUND_RUSH
	if time < PHASE_END_TIMES[Phase.RAIN]:
		return Phase.RAIN
	return Phase.CROSSFIRE


func _update_phase() -> void:
	var phase: Phase = _phase_at(_fight_time)
	if phase == _phase:
		return

	_phase = phase
	_enter_phase()


## Nothing announces a phase change. A phase is meant to be recognised by what
## starts happening — platforms appearing, orbs falling — not read off a caption.
func _enter_phase() -> void:
	match _phase:
		Phase.RAIN:
			_reveal_platforms()
			# Start on a telegraph rather than a drop, so the phase opens with a
			# marker the same as every drop after it.
			_rain_timer = 0.0
		Phase.CROSSFIRE:
			_sweep_timer = 0.0


## How far through the current phase the fight is, 0 to 1.
func _phase_progress() -> float:
	var from: float = 0.0 if _phase == Phase.GROUND_RUSH else PHASE_END_TIMES[_phase - 1]
	var to: float = PHASE_END_TIMES[_phase]
	return clampf(inverse_lerp(from, to, _fight_time), 0.0, 1.0)


## Reads a Vector2(start_of_phase, end_of_phase) tunable at the given progress.
static func _ramp(from_to: Vector2, progress: float) -> float:
	return lerpf(from_to.x, from_to.y, progress)


func _update_spawning(delta: float) -> void:
	var progress: float = _phase_progress()

	match _phase:
		Phase.GROUND_RUSH:
			_tick_rush(delta, _ramp(RUSH_INTERVAL, progress), _ramp(RUSH_SPEED, progress))
		Phase.RAIN:
			_tick_rain(delta, _ramp(RAIN_INTERVAL, progress), _ramp(RAIN_SPEED, progress))
		Phase.CROSSFIRE:
			# Both earlier streams carry on at the speed they ended on, spaced
			# out by CROSSFIRE_STREAM_RATE. The new thing in this phase is the
			# sweep; the old things staying recognisable is the point.
			_tick_rush(delta, RUSH_INTERVAL.y / CROSSFIRE_STREAM_RATE, RUSH_SPEED.y)
			_tick_rain(delta, RAIN_INTERVAL.y / CROSSFIRE_STREAM_RATE, RAIN_SPEED.y)
			_tick_sweep(delta)


func _tick_rush(delta: float, interval: float, speed: float) -> void:
	_rush_timer -= delta
	if _rush_timer > 0.0:
		return

	# Reset to the interval rather than adding it on: this cadence is meant to
	# be a metronome the player can lock onto, not a queue that catches up after
	# a frame spike.
	_rush_timer = interval
	_spawn_projectile(Vector2(OFFSCREEN_RIGHT_X, RUSH_Y), Vector2(-speed, 0.0))


func _tick_rain(delta: float, interval: float, speed: float) -> void:
	_rain_timer -= delta
	if _rain_timer > 0.0:
		return

	_rain_timer = interval
	_announce_drop(speed)


func _tick_sweep(delta: float) -> void:
	_sweep_timer -= delta
	if _sweep_timer > 0.0:
		return

	_sweep_timer = SWEEP_PERIOD
	_announce_sweep()


func _announce_drop(speed: float) -> void:
	# RAIN_LEAD is measured back from the moment the orb spawns, and the orb
	# spawns RAIN_TELEGRAPH from now — so the sample is only the difference ago.
	var lane_x: float = _position_at(_fight_time - (RAIN_LEAD - RAIN_TELEGRAPH))
	lane_x = clampf(lane_x, SPAWN_MARGIN_X, ARENA_WIDTH - SPAWN_MARGIN_X)

	_add_telegraph(
		RAIN_TELEGRAPH,
		[Vector2(lane_x, RAIN_MARKER_Y)],
		func() -> void:
			_spawn_projectile(Vector2(lane_x, OFFSCREEN_TOP_Y), Vector2(0.0, speed))
	)


func _announce_sweep() -> void:
	var gap_centre: float = SWEEP_GAP_CENTRES[_next_gap_index]
	_next_gap_index = (_next_gap_index + 1) % SWEEP_GAP_CENTRES.size()

	# Two markers, one on each edge of the gap. The only thing worth reading
	# about a wall is where the hole in it is.
	_add_telegraph(
		SWEEP_TELEGRAPH,
		[
			Vector2(SWEEP_MARKER_X, gap_centre - SWEEP_GAP_HALF_HEIGHT),
			Vector2(SWEEP_MARKER_X, gap_centre + SWEEP_GAP_HALF_HEIGHT),
		],
		func() -> void: _spawn_sweep(gap_centre)
	)


func _spawn_sweep(gap_centre: float) -> void:
	var y: float = SWEEP_TOP_Y
	while y <= SWEEP_BOTTOM_Y:
		if absf(y - gap_centre) >= SWEEP_GAP_HALF_HEIGHT:
			_spawn_projectile(Vector2(OFFSCREEN_RIGHT_X, y), Vector2(-SWEEP_SPEED, 0.0))
		y += SWEEP_ORB_SPACING


func _spawn_projectile(at: Vector2, velocity: Vector2) -> void:
	var projectile: BossProjectile = PROJECTILE_SCENE.instantiate()
	projectile.position = at
	projectile.velocity = velocity
	projectile.boss_level = self
	projectiles.add_child(projectile)


func _add_telegraph(duration: float, marker_positions: Array[Vector2], spawn: Callable) -> void:
	var telegraph: Telegraph = Telegraph.new()
	telegraph.duration = duration
	telegraph.remaining = duration
	telegraph.spawn = spawn

	for marker_position: Vector2 in marker_positions:
		telegraph.markers.append(_make_marker(marker_position))

	_telegraphs.append(telegraph)


func _make_marker(at: Vector2) -> Sprite2D:
	var marker: Sprite2D = Sprite2D.new()
	marker.texture = MARKER_TEXTURE
	marker.modulate = MARKER_MODULATE
	marker.scale = Vector2.ONE * MARKER_SCALE
	marker.position = at
	markers.add_child(marker)
	return marker


func _update_telegraphs(delta: float) -> void:
	# Backwards, because a telegraph that fires is removed on the spot.
	for index: int in range(_telegraphs.size() - 1, -1, -1):
		var telegraph: Telegraph = _telegraphs[index]
		telegraph.remaining -= delta

		if telegraph.remaining > 0.0:
			_pulse(telegraph)
			continue

		telegraph.spawn.call()
		_free_telegraph(telegraph)
		_telegraphs.remove_at(index)


func _pulse(telegraph: Telegraph) -> void:
	var elapsed: float = telegraph.duration - telegraph.remaining
	var alpha: float = lerpf(MARKER_MIN_ALPHA, 1.0, absf(sin(elapsed * MARKER_PULSE_SPEED)))
	for marker: Sprite2D in telegraph.markers:
		marker.modulate.a = alpha


func _free_telegraph(telegraph: Telegraph) -> void:
	for marker: Sprite2D in telegraph.markers:
		marker.queue_free()
	telegraph.markers.clear()


func _clear_field() -> void:
	for projectile: Node in projectiles.get_children():
		projectile.queue_free()
	for telegraph: Telegraph in _telegraphs:
		_free_telegraph(telegraph)
	_telegraphs.clear()


func _record_position() -> void:
	if _player == null:
		return

	_position_history.append(Vector2(_fight_time, _player.global_position.x))
	while not _position_history.is_empty() and _position_history[0].x < _fight_time - HISTORY_LENGTH:
		_position_history.remove_at(0)


## The player's x at the given fight time, or the closest sample either side of
## it. Falls back to the middle of the arena before anything has been recorded.
func _position_at(time: float) -> float:
	if _position_history.is_empty():
		return ARENA_WIDTH * 0.5

	for sample: Vector2 in _position_history:
		if sample.x >= time:
			return sample.y

	return _position_history[_position_history.size() - 1].y


## The bar shows time *left* in the fight, draining right to left: the red is
## what is still coming, and the phase notches are where its edge will be when
## the pattern changes.
func _update_hud() -> void:
	var remaining: float = 1.0 - clampf(_fight_time / _fight_duration(), 0.0, 1.0)
	survival_bar.value = remaining * survival_bar.max_value


## One notch per phase boundary, placed from PHASE_END_TIMES so the marks on the
## bar and the phases they mark cannot drift apart. Positions are measured as
## time *remaining*, because that is what the bar draws — phase 1 is the
## rightmost slice. The last entry is the end of the fight, which is already the
## left end of the bar.
func _build_phase_ticks() -> void:
	var duration: float = _fight_duration()

	for index: int in PHASE_END_TIMES.size() - 1:
		var at: float = 1.0 - PHASE_END_TIMES[index] / duration
		var tick: ColorRect = ColorRect.new()
		tick.color = PHASE_TICK_COLOR
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.anchor_left = at
		tick.anchor_right = at
		tick.anchor_top = 0.0
		tick.anchor_bottom = 1.0
		tick.offset_left = 0.0
		tick.offset_right = PHASE_TICK_WIDTH
		# Inset so a notch reads as a gap in the red, not as a break in the
		# bar's own frame.
		tick.offset_top = 1.0
		tick.offset_bottom = -1.0
		survival_bar.add_child(tick)


func _update_invulnerability(delta: float) -> void:
	if _invulnerable_time <= 0.0:
		return

	_invulnerable_time -= delta
	if _invulnerable_time <= 0.0:
		_invulnerable_time = 0.0
		_set_player_alpha(1.0)
		return

	_flash_time += delta
	var lit: bool = fmod(_flash_time, FLASH_INTERVAL * 2.0) < FLASH_INTERVAL
	_set_player_alpha(1.0 if lit else FLASH_ALPHA)


func _set_player_alpha(alpha: float) -> void:
	if _player == null:
		return
	_player.modulate.a = alpha


func _flash_screen() -> void:
	hit_flash.color.a = HIT_FLASH_ALPHA
	create_tween().tween_property(hit_flash, "color:a", 0.0, HIT_FLASH_TIME)


func _update_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return

	_shake_time = maxf(_shake_time - delta, 0.0)
	if _shake_time == 0.0:
		_set_canvas_offset(Vector2.ZERO)
		return

	var strength: float = SHAKE_STRENGTH * (_shake_time / SHAKE_TIME)
	_set_canvas_offset(Vector2(randf_range(-strength, strength), randf_range(-strength, strength)))


## Levels carry no Camera2D, so the shake goes on the viewport's canvas
## transform. That moves everything drawn in world space — arena, orbs, player —
## without displacing a single physics body, and CanvasLayers sit outside it, so
## the HUD stays nailed down. Rounded to whole pixels because the project renders
## at 320x180 with integer scaling and a half-pixel offset would smear it.
func _set_canvas_offset(offset: Vector2) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return

	var canvas_transform: Transform2D = viewport.canvas_transform
	canvas_transform.origin = offset.round()
	viewport.canvas_transform = canvas_transform


func _hide_platforms() -> void:
	if _platform_tween != null:
		_platform_tween.kill()
		_platform_tween = null

	phase_2_platforms.modulate.a = 0.0
	_set_platforms_solid(false)


## The platforms fade and rise into place, and only start colliding once they
## have arrived: an AnimatableBody2D moving up through the player would shove
## them, and being shoved by the scenery is not a hit the player can read.
func _reveal_platforms() -> void:
	if _platform_tween != null:
		_platform_tween.kill()

	_platform_tween = create_tween().set_parallel()
	_platform_tween.tween_property(phase_2_platforms, "modulate:a", 1.0, PLATFORM_REVEAL_TIME)

	for platform: Node2D in phase_2_platforms.get_children():
		var resting: Vector2 = platform.position
		platform.position = resting + Vector2(0.0, PLATFORM_REVEAL_RISE)
		(
			_platform_tween
			. tween_property(platform, "position", resting, PLATFORM_REVEAL_TIME)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)

	_platform_tween.chain().tween_callback(_set_platforms_solid.bind(true))


func _set_platforms_solid(solid: bool) -> void:
	for platform: JumpThroughPlatform in phase_2_platforms.get_children():
		platform.set_collision_layer_value(JumpThroughPlatform.COLLISION_LAYER, solid)


func _disable_exit() -> void:
	level_exit.hide()
	level_exit.monitoring = false

	# LevelExit switches its own monitoring back on two physics frames into its
	# _ready(), so turning it off once here would simply be undone. Wait that
	# out before having the last word.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	if is_instance_valid(level_exit):
		level_exit.monitoring = false


func _reveal_exit() -> void:
	level_exit.modulate.a = 0.0
	level_exit.show()

	var tween: Tween = create_tween()
	tween.tween_property(level_exit, "modulate:a", 1.0, EXIT_REVEAL_TIME)
	tween.tween_callback(func() -> void: level_exit.monitoring = true)


func _on_survived() -> void:
	_fighting = false
	_clear_field()
	survival_bar.value = 0.0
	# From here BaseLevel takes over: reached_exit -> _on_exit_reached -> exit().
	_reveal_exit()


## The barrage took the last of the clock.
##
## The death is spelled out here rather than left to [MainGame] because the
## signal MainGame listens for cannot fire in this room (see [method _ready]).
## What it does is deliberately identical to dying anywhere else — the same
## detonation, then the same run-end screen — so the last room does not end the
## run in its own private way.
func _on_defeated() -> void:
	if not _fighting:
		return

	_fighting = false
	_clear_field()

	if _player != null:
		await _player.explode()

	if not is_inside_tree():
		return

	Global.main_game.end_run(false)
