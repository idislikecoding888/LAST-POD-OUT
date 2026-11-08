extends Camera3D
class_name IsometricCamera

## Bright orthographic shared camera for room readability.

@export_category("Camera Framing")
@export var follow_smoothing: float = 5.5
@export var orthographic_size: float = 58.0
@export var min_orthographic_size: float = 52.0
@export var max_orthographic_size: float = 64.0
@export var spread_zoom_multiplier: float = 0.28
@export var camera_distance: float = 58.0
@export_range(35.0, 65.0, 1.0) var camera_pitch_degrees: float = 48.0

@export_category("Camera Shake")
@export var shake_decay: float = 5.0

var manager: Variant
var shake_strength: float = 0.0
var _target_center: Vector3 = Vector3.ZERO


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = orthographic_size
	current = true
	make_current()


func configure(game_manager: Variant) -> void:
	manager = game_manager
	current = true
	make_current()


func kick_shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)


func _process(delta: float) -> void:
	var active_players: Array = []
	if manager != null and manager.has_method("get_living_players"):
		active_players = manager.get_living_players()

	var center: Vector3 = Vector3.ZERO
	var spread: float = 0.0

	if not active_players.is_empty():
		for player in active_players:
			center += player.global_position
		center /= float(active_players.size())

		for player in active_players:
			spread = maxf(spread, center.distance_to(player.global_position))

	_target_center = center

	var desired_size: float = clampf(
		orthographic_size + spread * spread_zoom_multiplier,
		min_orthographic_size,
		max_orthographic_size
	)
	size = lerpf(size, desired_size, 1.0 - exp(-follow_smoothing * delta))

	var pitch: float = deg_to_rad(camera_pitch_degrees)
	var offset: Vector3 = Vector3(
		0.0,
		sin(pitch) * camera_distance,
		cos(pitch) * camera_distance
	)

	var desired_position: Vector3 = center + offset
	global_position = global_position.lerp(
		desired_position,
		1.0 - exp(-follow_smoothing * delta)
	)

	var shake_offset: Vector3 = Vector3.ZERO
	if shake_strength > 0.001:
		var time_value: float = float(Time.get_ticks_msec()) * 0.045
		shake_offset = Vector3(
			sin(time_value) * shake_strength,
			cos(time_value * 1.31) * shake_strength * 0.45,
			sin(time_value * 0.73) * shake_strength * 0.3
		)
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)

	look_at(center + Vector3.UP * 0.65 + shake_offset, Vector3.UP)
