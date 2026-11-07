extends Node3D
class_name IndustrialRigVisual

## Procedural industrial worker visual.
## Attach this node beneath the player's VisualRoot. The player collision
## capsule remains unchanged; this script only builds the visible rig.

var role_color: Color = Color(0.0, 0.85, 1.0)

var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var shoulder_light: SpotLight3D
var oxygen_segments: Array[MeshInstance3D] = []

var walk_phase: float = 0.0
var walk_intensity: float = 0.0


func configure(color: Color) -> void:
	# Rebuild cleanly if the player's corporate role/color changes.
	for child in get_children():
		child.free()

	oxygen_segments.clear()
	role_color = color
	_build_rig()


func _make_material(
	color: Color,
	metallic: float = 0.7,
	roughness: float = 0.42
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive_material(
	base_color: Color,
	emission_color: Color,
	energy: float = 2.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.metallic = 0.35
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	return material


func _add_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name

	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)

	return instance


func _add_pivot(node_name: String, position_value: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = position_value
	add_child(pivot)
	return pivot


func _build_rig() -> void:
	var dark_steel := _make_material(Color(0.045, 0.060, 0.075), 0.9, 0.36)
	var armor_steel := _make_material(Color(0.19, 0.235, 0.26), 0.82, 0.43)
	var hazard_yellow := _make_material(Color(0.92, 0.59, 0.055), 0.68, 0.48)
	var visor_material := _make_emissive_material(role_color, role_color, 3.2)
	var oxygen_material := _make_emissive_material(
		Color(0.08, 0.85, 0.42),
		Color(0.04, 1.0, 0.32),
		2.4
	)

	# Main torso and lower waist armor.
	_add_box(
		self,
		"IndustrialTorso",
		Vector3(0.72, 0.76, 0.43),
		Vector3(0.0, 0.0, 0.0),
		dark_steel
	)
	_add_box(
		self,
		"HazardChestPlate",
		Vector3(0.56, 0.30, 0.075),
		Vector3(0.0, 0.12, -0.245),
		hazard_yellow
	)
	_add_box(
		self,
		"LowerArmor",
		Vector3(0.58, 0.22, 0.40),
		Vector3(0.0, -0.39, 0.0),
		armor_steel
	)

	# Helmet and role-colored emissive visor slit.
	var helmet := MeshInstance3D.new()
	helmet.name = "Helmet"
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.28
	helmet_mesh.height = 0.56
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 0.57, 0.0)
	helmet.material_override = armor_steel
	add_child(helmet)

	_add_box(
		self,
		"VisorSlit",
		Vector3(0.38, 0.065, 0.04),
		Vector3(0.0, 0.58, -0.265),
		visor_material
	)

	# Shoulder armor plates.
	_add_box(
		self,
		"LeftShoulder",
		Vector3(0.34, 0.27, 0.34),
		Vector3(-0.47, 0.27, 0.0),
		hazard_yellow
	)
	_add_box(
		self,
		"RightShoulder",
		Vector3(0.34, 0.27, 0.34),
		Vector3(0.47, 0.27, 0.0),
		hazard_yellow
	)

	# Articulated arms. Rotation is applied to these pivots while walking.
	left_arm = _add_pivot("LeftArmPivot", Vector3(-0.48, 0.16, 0.0))
	right_arm = _add_pivot("RightArmPivot", Vector3(0.48, 0.16, 0.0))

	_add_box(
		left_arm,
		"LeftArmArmor",
		Vector3(0.23, 0.48, 0.25),
		Vector3(0.0, -0.21, 0.0),
		armor_steel
	)
	_add_box(
		right_arm,
		"RightArmArmor",
		Vector3(0.23, 0.48, 0.25),
		Vector3(0.0, -0.21, 0.0),
		armor_steel
	)

	# Articulated legs and magnetic boots.
	left_leg = _add_pivot("LeftLegPivot", Vector3(-0.19, -0.40, 0.0))
	right_leg = _add_pivot("RightLegPivot", Vector3(0.19, -0.40, 0.0))

	_add_leg_geometry(left_leg, dark_steel, hazard_yellow)
	_add_leg_geometry(right_leg, dark_steel, hazard_yellow)

	# Heavy life-support backpack.
	_add_box(
		self,
		"LifeSupportBackpack",
		Vector3(0.62, 0.72, 0.28),
		Vector3(0.0, 0.04, 0.34),
		dark_steel
	)
	_add_box(
		self,
		"BackpackWarningPlate",
		Vector3(0.47, 0.13, 0.055),
		Vector3(0.0, 0.20, 0.505),
		hazard_yellow
	)

	# Four visible oxygen segments on the backpack's rear face.
	for index in range(4):
		var segment := _add_box(
			self,
			"OxygenSegment_%d" % index,
			Vector3(0.105, 0.105, 0.035),
			Vector3(-0.225 + float(index) * 0.15, -0.11, 0.51),
			oxygen_material
		)
		oxygen_segments.append(segment)

	# Shoulder-mounted flashlight. SpotLight3D shines along local -Z.
	shoulder_light = SpotLight3D.new()
	shoulder_light.name = "ShoulderFlashlight"
	shoulder_light.position = Vector3(0.48, 0.34, -0.18)
	shoulder_light.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
	shoulder_light.light_color = role_color.lightened(0.25)
	shoulder_light.light_energy = 2.6
	shoulder_light.spot_range = 18.0
	shoulder_light.spot_angle = 34.0
	shoulder_light.spot_angle_attenuation = 0.8
	shoulder_light.shadow_enabled = true
	add_child(shoulder_light)


func _add_leg_geometry(
	leg_pivot: Node3D,
	armor_material: Material,
	boot_material: Material
) -> void:
	_add_box(
		leg_pivot,
		"LegArmor",
		Vector3(0.24, 0.50, 0.29),
		Vector3(0.0, -0.23, 0.0),
		armor_material
	)
	_add_box(
		leg_pivot,
		"MagBoot",
		Vector3(0.30, 0.14, 0.39),
		Vector3(0.0, -0.46, -0.045),
		boot_material
	)


func animate_rig(
	velocity: Vector3,
	delta: float,
	oxygen_fraction: float,
	carrying: bool
) -> void:
	if left_arm == null or right_arm == null:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	walk_intensity = move_toward(
		walk_intensity,
		clampf(horizontal_speed / 4.0, 0.0, 1.0),
		delta * 5.0
	)

	walk_phase += delta * (5.0 + horizontal_speed * 2.0)
	var swing := sin(walk_phase) * walk_intensity * 0.52

	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing * 0.7
	right_arm.rotation.x = swing * 0.7

	if carrying:
		left_arm.rotation.x = -0.62
		right_arm.rotation.x = -0.88

	position.y = sin(walk_phase * 2.0) * walk_intensity * 0.025

	var active_segments := int(ceil(clampf(oxygen_fraction, 0.0, 1.0) * 4.0))
	for index in range(oxygen_segments.size()):
		oxygen_segments[index].visible = index < active_segments

	if oxygen_fraction < 0.25:
		shoulder_light.light_color = Color(1.0, 0.10, 0.06)
	else:
		shoulder_light.light_color = role_color.lightened(0.25)
