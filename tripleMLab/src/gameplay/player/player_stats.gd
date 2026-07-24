extends Resource
class_name PlayerStats

@export var move_speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

@export var jump_velocity: float = -400.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 900.0
@export var jump_cut_multiplier: float = 0.5  # short-hop when jump released early

@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

# Asymmetric gravity + jump hang time (apex float)
@export var fall_gravity_mult: float = 1.5      # extra gravity while falling
@export var jump_hang_threshold: float = 50.0    # |velocity.y| below this = "near apex"
@export var jump_hang_gravity_mult: float = 0.5  # reduced gravity near apex
@export var jump_hang_accel_mult: float = 1.1    # bonus air control near apex
@export var jump_hang_max_speed_mult: float = 1.1  # bonus max speed near apex
