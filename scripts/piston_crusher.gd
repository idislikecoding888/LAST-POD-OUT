
extends Node3D
class_name PistonCrusher

@export var cycle_seconds: float = 5.5
@export var slam_duration: float = 0.65
@export var raised_height: float = 3.6
@export var lowered_height: float = 0.75
@export var travel_speed: float = 10.0
@export var stun_seconds: float = 0.65
@export var oxygen_damage: float = 18.0
@export var knockback_force: float = 7.0

var clock: float = 0.0
var head_body: StaticBody3D
var head_mesh: MeshInstance3D
var danger_area: Area3D
var warning_light: OmniLight3D
var _last_cycle: int = -1


func _ready() -> void:
	_build_crusher()


func _build_crusher() -> void:
	var steel := IndustrialMaterials.make_surface(
		Color(0.17, 0.20, 0.23), 0.85, 0.35, 61
	)

	# Overhead hydraulic support.
	var support := MeshInstance3D.new()
	var support_mesh := BoxMesh.new()
	support_mesh.size = Vector3(2.6, 0.55, 3.4)
	support.mesh = support_mesh
	support.position.y = 4.1
	support.material_override = steel
	add_child(support)

	# Moving physical piston head.
	head_body = StaticBody3D.new()
	head_body.collision_layer = 1
	head_body.collision_mask = 2

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.85, 2.6)
	collision.shape = shape
	head_body.add_child(collision)
	add_child(head_body)

	head_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	head_mesh.mesh = mesh
	head_mesh.material_override = IndustrialMaterials.make_emissive(
		Color(0.19, 0.22, 0.24),
		Color(0.85, 0.12, 0.025),
		0.5
	)
	head_body.add_child(head_mesh)

	# Warning strips on the face.
	for x_offset in [-0.65, 0.0, 0.65]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.24, 0.025, 2.62)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(x_offset, 0.43, 0.0)
		stripe.material_override = IndustrialMaterials.make_emissive(
			Color(1.0, 0.65, 0.05),
			Color(1.0, 0.35, 0.01),
			1.2
		)
		head_body.add_child(stripe)

	# Only becomes dangerous during the slam window.
	danger_area = Area3D.new()
	danger_area.collision_layer = 16
	danger_area.collision_mask = 2
	danger_area.monitoring = false

	var danger_shape := CollisionShape3D.new()
	var danger_box := BoxShape3D.new()
	danger_box.size = Vector3(2.3, 1.8, 2.9)
	danger_shape.shape = danger_box
	danger_area.add_child(danger_shape)
	danger_area.body_entered.connect(_on_danger_body_entered)
	add_child(danger_area)

	warning_light = OmniLight3D.new()
	warning_light.position = Vector3(0.0, 3.8, 0.0)
	warning_light.light_color = Color(1.0, 0.08, 0.015)
	warning_light.light_energy = 0.0
	warning_light.omni_range = 6.0
	warning_light.shadow_enabled = false
	add_child(warning_light)


func _physics_process(delta: float) -> void:
	clock += delta

	var cycle_index: int = floori(clock / cycle_seconds)
	var cycle_position: float = fposmod(clock, cycle_seconds)

	var slam_start: float = cycle_seconds - slam_duration
	var is_slamming: bool = cycle_position >= slam_start

	var target_y: float = raised_height

	if is_slamming:
		target_y = lowered_height

	# Smoothly raise, then rapidly lower.
	var speed: float = travel_speed

	if is_slamming:
		speed *= 2.0

	head_body.position.y = move_toward(
		head_body.position.y,
		target_y,
		speed * delta
	)

	danger_area.position.y = lowered_height
	danger_area.monitoring = is_slamming

	warning_light.light_energy = 2.4 if is_slamming else 0.25

	if is_slamming and cycle_index != _last_cycle:
		_last_cycle = cycle_index

		# Handle players already inside the area when it activates.
		for body in danger_area.get_overlapping_bodies():
			_apply_crush(body)


func _on_danger_body_entered(body: Node3D) -> void:
	_apply_crush(body)


func _apply_crush(body: Node3D) -> void:
	if not body is PlayerController:
		return

	var player := body as PlayerController

	if not player.is_alive:
		return

	player.apply_stun(stun_seconds)
	player.oxygen = maxf(0.0, player.oxygen - oxygen_damage)

	if player.carried_cell != null:
		player.drop_carried_cell(Vector3(0.0, 0.0, 0.0))

	var push := player.global_position - global_position
	push.y = 0.1

	if push.length_squared() > 0.001:
		player.receive_knockback(push.normalized() * knockback_force)

	if has_node("/root/SoundManager"):
		SoundManager.play_impact()
