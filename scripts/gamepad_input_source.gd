extends "res://scripts/input_source.gd"
class_name GamepadInputSource
## Xbox-style controller implementation. Keeps the real Godot device ID.

@export_range(0, 3, 1) var device_id: int = 0
@export_range(0.05, 0.8, 0.01) var stick_deadzone: float = 0.18
@export_range(0.05, 0.9, 0.01) var trigger_threshold: float = 0.38
var _previous: Dictionary = {}

func move_vector() -> Vector2:
	var value := Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)
	if value.length() < stick_deadzone:
		return Vector2.ZERO
	return value.limit_length(1.0)

func aim_vector(_player: Node3D, _camera: Camera3D) -> Vector3:
	var value := Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	)
	if value.length() < stick_deadzone:
		return Vector3.ZERO
	value = value.limit_length(1.0)
	return Vector3(value.x, 0.0, value.y).normalized()

func _raw(action: StringName) -> bool:
	match action:
		&"shove":
			# SDL trigger axes rest at -1.0 and reach +1.0 when fully pressed.
			var trigger_value := (Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT) + 1.0) * 0.5
			return trigger_value >= trigger_threshold
		&"parry":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER)
		&"dodge":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_B)
		&"interact":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_X)
		&"pact":
			return Input.is_joy_button_pressed(device_id, JOY_BUTTON_Y)
	return false

func action_pressed(action: StringName) -> bool:
	return _raw(action)

func action_just_pressed(action: StringName) -> bool:
	var current := _raw(action)
	var previous := bool(_previous.get(action, false))
	_previous[action] = current
	return current and not previous
