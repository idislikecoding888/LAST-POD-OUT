
extends Node3D
class_name SecurityDrone

@export var patrol_speed: float = 2.4
@export var scan_radius: float = 12.0
@export var cone_angle_degrees: float = 27.0
@export var lock_seconds: float = 0.85
@export var stun_seconds: float = 1.25
@export var patrol_points: Array[Vector3] = [
	Vector3(11.0, 3.8, -8.0),
	Vector3(20.0, 3.8, -8.0),
	Vector3(20.0, 3.8, 5.0),
	Vector3(11.0, 3.8, 5.0)
]

var active: bool = false
var waypoint_index: int = 0
var lock_target: PlayerController
var lock_progress: float = 0.0
var light_node: SpotLight3D
var rotor: MeshInstance3D


func _ready() -> void:
	_build_drone()
	visible = false
	set_process(false)


func _build_drone() -> void:
	var shell := MeshInstance3D.new()
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = Vector3(0.9, 0.35, 0.9)
	shell.mesh = shell_mesh
	shell.material_override = IndustrialMaterials.make_surface(
		Color(0.065, 0.08, 0.10), 0.9, 0.28, 112
	)
	add_child(shell)

	rotor = MeshInstance3D.new()
	var rotor_mesh := CylinderMesh.new()
	rotor_mesh.top_radius = 0.42
	rotor_mesh.bottom_radius = 0.42
	rotor_mesh.height = 0.08
	rotor.mesh = rotor_mesh
	rotor.position.y = 0.25
	rotor.material_override = IndustrialMaterials.make_emissive(
		Color.RED, Color.RED, 2.5
	)
	add_child(rotor)

	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.14
	eye_mesh.height = 0.28
	eye.mesh = eye_mesh
	eye.position = Vector3(0, -0.02, -0.48)
	eye.material_override = IndustrialMaterials.make_emissive(
		Color.RED, Color.RED, 4.0
	)
	add_child(eye)

	light_node = SpotLight3D.new()
	light_node.light_color = Color(1.0, 0.025, 0.015)
	light_node.light_energy = 5.0
	light_node.spot_range = scan_radius
	light_node.spot_angle = cone_angle_degrees
	light_node.spot_angle_attenuation = 0.65
	light_node.shadow_enabled = true
	add_child(light_node)


func set_active(value: bool) -> void:
	active = value
	visible = value
	set_process(value)

	if not value:
		lock_target = null
		lock_progress = 0.0


func _process(delta: float) -> void:
	if not active:
		return

	rotor.rotate_y(delta * 15.0)
	_patrol(delta)

	var target := _find_target()

	if target == null:
		lock_target = null
		lock_progress = 0.0
		return

	var target_point: Vector3 = target.global_position + Vector3.UP * 0.3
	look_at(target_point, Vector3.UP)

	if target == lock_target:
		lock_progress += delta
	else:
		lock_target = target
		lock_progress = 0.0

	if lock_progress >= lock_seconds:
		target.apply_stun(stun_seconds)
		target.oxygen = maxf(0.0, target.oxygen - 5.0)

		if has_node("/root/SoundManager"):
			SoundManager.play_parry()

		lock_progress = 0.0
		lock_target = null


func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return

	var destination: Vector3 = patrol_points[waypoint_index]

	var to_destination := destination - global_position

	if to_destination.length_squared() > 0.01:
		look_at(destination, Vector3.UP)

	global_position = global_position.move_toward(
		destination,
		patrol_speed * delta
	)

	if global_position.distance_to(destination) < 0.5:
		waypoint_index = (waypoint_index + 1) % patrol_points.size()


func _find_target() -> PlayerController:
	var nearest: PlayerController = null
	var best_distance: float = scan_radius

	for node in get_tree().get_nodes_in_group("players"):
		if not node is PlayerController:
			continue

		var candidate := node as PlayerController

		if not candidate.is_alive:
			continue

		var offset := candidate.global_position - global_position
		var distance := offset.length()

		if distance >= best_distance or distance < 0.1:
			continue

		var direction := offset.normalized()
		var forward := -global_basis.z.normalized()

		if forward.dot(direction) < cos(deg_to_rad(cone_angle_degrees * 0.5)):
			continue

		# Layer 1 only: walls and bulkheads block the security beam.
		var query := PhysicsRayQueryParameters3D.create(
			global_position,
			candidate.global_position + Vector3.UP * 0.3,
			1
		)
		query.collide_with_areas = false

		var hit := get_world_3d().direct_space_state.intersect_ray(query)

		if not hit.is_empty():
			continue

		best_distance = distance
		nearest = candidate

	return nearest
