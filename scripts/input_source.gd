extends Node
class_name InputSource
## Interface component: player controllers depend on this contract, not on devices.

func move_vector() -> Vector2:
	return Vector2.ZERO

func aim_vector(_player: Node3D, _camera: Camera3D) -> Vector3:
	return Vector3.ZERO

func action_pressed(_action: StringName) -> bool:
	return false

func action_just_pressed(_action: StringName) -> bool:
	return false
