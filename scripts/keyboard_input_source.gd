extends "res://scripts/input_source.gd"
class_name KeyboardInputSource
## Keyboard + mouse implementation used by Player 1 as a local fallback.

var _previous: Dictionary = {}

func move_vector() -> Vector2:
	var value := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		value.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		value.x += 1.0
	if Input.is_key_pressed(KEY_W):
		value.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		value.y += 1.0
	return value.normalized() if value.length_squared() > 1.0 else value

func aim_vector(player: Node3D, camera: Camera3D) -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var viewport := player.get_viewport()
	var mouse_position := viewport.get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var plane := Plane(Vector3.UP, player.global_position.y)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_direction)
	if hit is Vector3:
		var direction := Vector3(hit.x - player.global_position.x, 0.0, hit.z - player.global_position.z)
		return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO
	return Vector3.ZERO

func _raw(action: StringName) -> bool:
	match action:
		&"shove":
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		&"parry":
			return Input.is_key_pressed(KEY_Q)
		&"dodge":
			return Input.is_key_pressed(KEY_SHIFT)
		&"interact":
			return Input.is_key_pressed(KEY_E)
		&"pact":
			return Input.is_key_pressed(KEY_F)
	return false

func action_pressed(action: StringName) -> bool:
	return _raw(action)

func action_just_pressed(action: StringName) -> bool:
	var current := _raw(action)
	var previous := bool(_previous.get(action, false))
	_previous[action] = current
	return current and not previous
