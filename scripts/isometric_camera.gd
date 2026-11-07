extends Camera3D
class_name IsometricCamera
## One shared 45-degree isometric camera; tracks active-player midpoint and clamps zoom.

@export var follow_smoothing: float = 5.5
@export var base_distance: float = 17.0
@export var min_zoom_distance: float = 14.0
@export var max_zoom_distance: float = 24.0
@export var spread_zoom_multiplier: float = 0.58
@export var camera_height_ratio: float = 0.82
@export var camera_pitch_degrees: float = 45.0
@export var shake_decay: float = 5.0

var manager
var shake_strength: float = 0.0
var _rest_position: Vector3 = Vector3.ZERO

func configure(game_manager) -> void:
	manager = game_manager

func kick_shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)

func _process(delta: float) -> void:
	if manager == null:
		return
	var active_players = manager.get_living_players()
	if active_players.is_empty():
		return
	var center := Vector3.ZERO
	for player in active_players:
		center += player.global_position
	center /= float(active_players.size())
	var max_spread := 0.0
	for player in active_players:
		max_spread = maxf(max_spread, center.distance_to(player.global_position))
	var distance := clampf(base_distance + max_spread * spread_zoom_multiplier, min_zoom_distance, max_zoom_distance)
	var pitch := deg_to_rad(camera_pitch_degrees)
	var offset := Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	_rest_position = center + offset
	global_position = global_position.lerp(_rest_position, 1.0 - exp(-follow_smoothing * delta))
	var shake_offset := Vector3.ZERO
	if shake_strength > 0.001:
		var t := float(Time.get_ticks_msec()) * 0.045
		shake_offset = Vector3(sin(t) * shake_strength, cos(t * 1.31) * shake_strength * 0.45, sin(t * 0.73) * shake_strength * 0.3)
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
	look_at(center + Vector3.UP * 0.55 + shake_offset, Vector3.UP)
