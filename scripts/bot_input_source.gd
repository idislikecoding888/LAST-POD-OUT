
extends "res://scripts/input_source.gd"
class_name BotInputSource

## Simple test dummy that slowly wanders toward the nearest Fuel Cell.

@export_range(0.1, 1.0, 0.05) var wander_speed_scale: float = 0.30
@export var orbit_strength: float = 0.22


func move_vector() -> Vector2:
	# Get the player that owns this input component.
	var bot_player: Node3D = get_parent() as Node3D

	if bot_player == null:
		return Vector2.ZERO

	var best_cell: Node3D = null
	var best_distance: float = INF

	# Find the nearest valid Fuel Cell.
	for node in bot_player.get_tree().get_nodes_in_group("fuel_cells"):
		if not is_instance_valid(node):
			continue

		if not node is Node3D:
			continue

		var fuel_cell: Node3D = node as Node3D

		var distance: float = bot_player.global_position.distance_to(
			fuel_cell.global_position
		)

		if distance < best_distance:
			best_distance = distance
			best_cell = fuel_cell

	# No available Fuel Cells: wander around.
	if best_cell == null:
		var phase: float = float(Time.get_ticks_msec()) * 0.00035

		return Vector2(
			cos(phase),
			sin(phase)
		) * wander_speed_scale

	# Move toward the nearest Fuel Cell with a slight orbital wobble.
	var direction: Vector3 = (
		best_cell.global_position - bot_player.global_position
	)

	var wobble: float = sin(
		float(Time.get_ticks_msec()) * 0.0012
		+ float(bot_player.get_instance_id() % 17)
	) * orbit_strength

	var flat_direction: Vector3 = Vector3(
		direction.x + wobble,
		0.0,
		direction.z - wobble
	)

	return Vector2(
		flat_direction.x,
		flat_direction.z
	).normalized() * wander_speed_scale


func aim_vector(_player: Node3D, _camera: Camera3D) -> Vector3:
	var movement: Vector2 = move_vector()

	return Vector3(
		movement.x,
		0.0,
		movement.y
	).normalized()
