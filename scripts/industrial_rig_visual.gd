
extends Node3D
class_name IndustrialRigVisual

## External astronaut model with procedural fallback.
## Supports the Grab3D astronaut GLB with run/walk animations.

const PLAYER_MODEL_PATH: String = "res://assets/characters/player.glb"

@export var desired_height: float = 1.85
@export var run_speed_threshold: float = 2.3

var role_color: Color = Color(0.0, 0.85, 1.0)

var imported_model: Node3D
var animation_player: AnimationPlayer

var walk_clip: StringName = &""
var run_clip: StringName = &""
var idle_clip: StringName = &""
var push_clip: StringName = &""
var active_clip: StringName = &""

var imported_model_loaded: bool = false

var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D

var shoulder_light: SpotLight3D
var oxygen_segments: Array[MeshInstance3D] = []

var walk_phase: float = 0.0
var walk_intensity: float = 0.0


# ============================================================
# CONFIGURATION
# ============================================================

func configure(color: Color) -> void:

	# Remove previously generated character parts.
	for child in get_children():
		remove_child(child)
		child.free()

	role_color = color

	imported_model = null
	animation_player = null

	walk_clip = &""
	run_clip = &""
	idle_clip = &""
	push_clip = &""
	active_clip = &""

	imported_model_loaded = false

	left_arm = null
	right_arm = null
	left_leg = null
	right_leg = null

	shoulder_light = null
	oxygen_segments.clear()

	walk_phase = 0.0
	walk_intensity = 0.0

	_build_rig()


# ============================================================
# MATERIAL HELPERS
# ============================================================

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


# ============================================================
# BUILD CHARACTER
# ============================================================

func _build_rig() -> void:

	if _try_load_imported_model():

		imported_model_loaded = true
		_build_shared_accents()

		print(
			"LAST POD OUT: External astronaut loaded. Animations: ",
			animation_player.get_animation_list()
			if animation_player != null
			else "None"
		)

		return

	push_warning(
		"Astronaut GLB unavailable. Using procedural fallback."
	)

	_build_procedural_fallback()
	_build_shared_accents()


# ============================================================
# LOAD EXTERNAL GLB
# ============================================================

func _try_load_imported_model() -> bool:

	if not ResourceLoader.exists(PLAYER_MODEL_PATH):
		return false

	var resource: Resource = load(PLAYER_MODEL_PATH)

	if not resource is PackedScene:
		push_warning("player.glb did not import as a PackedScene.")
		return false

	var instance: Node = (
		(resource as PackedScene).instantiate()
	)

	if not instance is Node3D:
		instance.free()
		push_warning("Imported astronaut root is not Node3D.")
		return false

	imported_model = instance as Node3D
	imported_model.name = "ImportedAstronaut"

	add_child(imported_model)

	# Calculate the actual mesh bounds without relying on
	# the GLB root's original unit scale.
	var bounds_list: Array[AABB] = []

	_collect_model_bounds(
		imported_model,
		imported_model,
		bounds_list
	)

	if bounds_list.is_empty():

		imported_model.free()
		imported_model = null

		push_warning("Astronaut contains no MeshInstance3D.")
		return false

	var combined_bounds: AABB = bounds_list[0]

	for index in range(1, bounds_list.size()):
		combined_bounds = combined_bounds.merge(
			bounds_list[index]
		)

	if combined_bounds.size.y <= 0.001:

		imported_model.free()
		imported_model = null

		return false

	# Normalize the character to the desired gameplay height.
	var scale_factor: float = (
		desired_height / combined_bounds.size.y
	)

	imported_model.scale = Vector3.ONE * scale_factor

	var center: Vector3 = combined_bounds.get_center()

	# Put the boots at Y = 0 and center the astronaut horizontally.
	imported_model.position = Vector3(
		-center.x * scale_factor,
		-combined_bounds.position.y * scale_factor,
		-center.z * scale_factor
	)

	# Find the imported AnimationPlayer.
	animation_player = _find_animation_player(imported_model)

	if animation_player != null:

		walk_clip = _find_animation_clip("walk")
		run_clip = _find_animation_clip("run")
		idle_clip = _find_animation_clip("idle")
		push_clip = _find_animation_clip("push")

		# Ensure locomotion clips loop.
		_set_clip_looping(walk_clip)
		_set_clip_looping(run_clip)

		if walk_clip == &"" and run_clip == &"":
			push_warning(
				"Astronaut imported, but no Walk/Run animation was found."
			)

	else:

		push_warning(
			"Astronaut imported without an AnimationPlayer."
		)

	return true


func _collect_model_bounds(
	node: Node,
	model_root: Node3D,
	results: Array[AABB]
) -> void:

	if node is MeshInstance3D:

		var mesh_instance := node as MeshInstance3D

		if mesh_instance.mesh != null:

			var relative_transform: Transform3D = (
				model_root.global_transform.affine_inverse()
				* mesh_instance.global_transform
			)

			var bounds: AABB = (
				relative_transform * mesh_instance.get_aabb()
			)

			results.append(bounds)

	for child in node.get_children():

		_collect_model_bounds(
			child,
			model_root,
			results
		)


# ============================================================
# FIND ANIMATION PLAYER / CLIPS
# ============================================================

func _find_animation_player(node: Node) -> AnimationPlayer:

	for child in node.get_children():

		if child is AnimationPlayer:
			return child as AnimationPlayer

		var found := _find_animation_player(child)

		if found != null:
			return found

	return null


func _find_animation_clip(search_name: String) -> StringName:

	if animation_player == null:
		return &""

	for clip in animation_player.get_animation_list():

		var lower_name: String = clip.to_lower()

		if lower_name == search_name:
			return StringName(clip)

		if lower_name.ends_with("/" + search_name):
			return StringName(clip)

	return &""


func _set_clip_looping(clip: StringName) -> void:

	if animation_player == null or clip == &"":
		return

	var animation: Animation = animation_player.get_animation(clip)

	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR


func _play_clip(clip: StringName) -> void:

	if animation_player == null or clip == &"":
		return

	if (
		active_clip != clip
		or not animation_player.is_playing()
	):

		animation_player.play(clip)
		active_clip = clip


func play_push() -> void:

	# The current GLB doesn't contain a Push clip.
	# This method will work automatically if one is added later.
	if push_clip != &"":
		_play_clip(push_clip)


# ============================================================
# EXTERNAL CHARACTER ANIMATION
# ============================================================

func _animate_imported_model(horizontal_speed: float) -> void:

	if animation_player == null:
		return

	# Stationary character.
	if horizontal_speed < 0.15:

		if idle_clip != &"":

			_play_clip(idle_clip)

		elif walk_clip != &"":

			if active_clip != walk_clip:

				animation_player.play(walk_clip)
				animation_player.seek(0.0, true)
				animation_player.pause()

				active_clip = walk_clip

		elif run_clip != &"":

			if active_clip != run_clip:

				animation_player.play(run_clip)
				animation_player.seek(0.0, true)
				animation_player.pause()

				active_clip = run_clip

		return

	# Walking and running.
	if horizontal_speed >= run_speed_threshold:

		if run_clip != &"":
			_play_clip(run_clip)

		elif walk_clip != &"":
			_play_clip(walk_clip)

	else:

		if walk_clip != &"":
			_play_clip(walk_clip)

		elif run_clip != &"":
			_play_clip(run_clip)


# ============================================================
# ROLE ACCENTS / OXYGEN GAUGE / FLASHLIGHT
# ============================================================

func _build_shared_accents() -> void:

	# Among Us-style role ring.
	var ring := MeshInstance3D.new()

	ring.name = "PlayerRoleRing"

	var ring_mesh := TorusMesh.new()

	ring_mesh.inner_radius = 0.56
	ring_mesh.outer_radius = 0.68
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8

	ring.mesh = ring_mesh

	ring.position.y = 0.035

	ring.material_override = _make_emissive_material(
		role_color,
		role_color,
		1.7
	)

	add_child(ring)

	# Small role insignia on the upper chest.
	var insignia := MeshInstance3D.new()

	insignia.name = "RoleInsignia"

	var insignia_mesh := SphereMesh.new()

	insignia_mesh.radius = 0.065
	insignia_mesh.height = 0.13

	insignia.mesh = insignia_mesh
	insignia.position = Vector3(0.0, 1.34, -0.34)

	insignia.material_override = _make_emissive_material(
		role_color,
		role_color,
		2.4
	)

	add_child(insignia)

	# Four oxygen indicator segments on the backpack.
	var oxygen_material := _make_emissive_material(
		Color(0.06, 0.9, 0.35),
		Color(0.04, 1.0, 0.3),
		2.0
	)

	for index in range(4):

		var segment := MeshInstance3D.new()

		segment.name = "OxygenSegment_%d" % index

		var segment_mesh := BoxMesh.new()
		segment_mesh.size = Vector3(0.085, 0.065, 0.025)

		segment.mesh = segment_mesh

		segment.position = Vector3(
			-0.18 + float(index) * 0.12,
			1.30,
			0.36
		)

		segment.material_override = oxygen_material

		add_child(segment)
		oxygen_segments.append(segment)

	# Shoulder flashlight.
	shoulder_light = SpotLight3D.new()

	shoulder_light.name = "ShoulderFlashlight"
	shoulder_light.position = Vector3(0.40, 1.45, 0.0)

	shoulder_light.rotation_degrees = Vector3(-5.0, 0.0, 0.0)

	shoulder_light.light_color = role_color.lightened(0.25)
	shoulder_light.light_energy = 2.6

	shoulder_light.spot_range = 18.0
	shoulder_light.spot_angle = 34.0
	shoulder_light.spot_angle_attenuation = 0.8

	shoulder_light.shadow_enabled = true

	add_child(shoulder_light)


# ============================================================
# SMOOTH PROCEDURAL FALLBACK
# ============================================================

func _add_capsule(
	parent: Node3D,
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	material: Material
) -> MeshInstance3D:

	var instance := MeshInstance3D.new()

	instance.name = node_name

	var mesh := CapsuleMesh.new()

	mesh.radius = radius
	mesh.height = height

	mesh.radial_segments = 16
	mesh.rings = 8

	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = material

	parent.add_child(instance)

	return instance


func _add_pivot(
	node_name: String,
	position_value: Vector3
) -> Node3D:

	var pivot := Node3D.new()

	pivot.name = node_name
	pivot.position = position_value

	add_child(pivot)

	return pivot


func _build_procedural_fallback() -> void:

	var dark_steel := _make_material(
		Color(0.045, 0.060, 0.075),
		0.9,
		0.36
	)

	var armor_steel := _make_material(
		Color(0.19, 0.235, 0.26),
		0.82,
		0.43
	)

	var yellow := _make_material(
		Color(0.92, 0.59, 0.055),
		0.68,
		0.48
	)

	var visor := _make_emissive_material(
		role_color,
		role_color,
		3.2
	)

	# Main torso.
	_add_capsule(
		self,
		"IndustrialTorso",
		0.33,
		0.82,
		Vector3(0.0, 0.0, 0.0),
		dark_steel
	)

	# Chest plate.
	_add_capsule(
		self,
		"HazardChestPlate",
		0.29,
		0.48,
		Vector3(0.0, 0.11, -0.055),
		yellow
	)

	# Helmet.
	var helmet := MeshInstance3D.new()

	var helmet_mesh := SphereMesh.new()

	helmet_mesh.radius = 0.28
	helmet_mesh.height = 0.56

	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0.0, 0.57, 0.0)

	helmet.material_override = armor_steel

	add_child(helmet)

	# Visor.
	var visor_mesh := MeshInstance3D.new()

	var visor_shape := SphereMesh.new()

	visor_shape.radius = 0.205
	visor_shape.height = 0.24

	visor_mesh.mesh = visor_shape

	visor_mesh.scale = Vector3(1.0, 0.38, 0.35)
	visor_mesh.position = Vector3(0.0, 0.58, -0.21)

	visor_mesh.material_override = visor

	add_child(visor_mesh)

	# Articulated arms.
	left_arm = _add_pivot(
		"LeftArmPivot",
		Vector3(-0.43, 0.16, 0.0)
	)

	right_arm = _add_pivot(
		"RightArmPivot",
		Vector3(0.43, 0.16, 0.0)
	)

	_add_capsule(
		left_arm,
		"LeftArm",
		0.12,
		0.53,
		Vector3(0.0, -0.23, 0.0),
		armor_steel
	)

	_add_capsule(
		right_arm,
		"RightArm",
		0.12,
		0.53,
		Vector3(0.0, -0.23, 0.0),
		armor_steel
	)

	# Articulated legs.
	left_leg = _add_pivot(
		"LeftLegPivot",
		Vector3(-0.18, -0.43, 0.0)
	)

	right_leg = _add_pivot(
		"RightLegPivot",
		Vector3(0.18, -0.43, 0.0)
	)

	for leg in [left_leg, right_leg]:

		_add_capsule(
			leg,
			"LegArmor",
			0.135,
			0.66,
			Vector3(0.0, -0.24, 0.0),
			dark_steel
		)

		_add_capsule(
			leg,
			"MagBoot",
			0.14,
			0.24,
			Vector3(0.0, -0.54, -0.06),
			yellow
		)

	# Life-support backpack.
	var backpack := MeshInstance3D.new()

	var pack_mesh := CylinderMesh.new()

	pack_mesh.top_radius = 0.16
	pack_mesh.bottom_radius = 0.16
	pack_mesh.height = 0.68

	backpack.mesh = pack_mesh

	backpack.position = Vector3(0.0, 0.0, 0.34)
	backpack.material_override = dark_steel

	add_child(backpack)

	# Twin oxygen cylinders.
	for side in [-1.0, 1.0]:

		_add_capsule(
			self,
			"OxygenCylinder",
			0.09,
			0.58,
			Vector3(side * 0.19, 0.02, 0.37),
			armor_steel
		)


# ============================================================
# PROCEDURAL WALK ANIMATION / OXYGEN
# ============================================================

func animate_rig(
	velocity: Vector3,
	delta: float,
	oxygen_fraction: float,
	carrying: bool
) -> void:

	var horizontal_speed: float = Vector2(
		velocity.x,
		velocity.z
	).length()

	walk_intensity = move_toward(
		walk_intensity,
		clampf(horizontal_speed / 4.0, 0.0, 1.0),
		delta * 5.0
	)

	walk_phase += delta * (
		5.0 + horizontal_speed * 2.0
	)

	# Imported astronaut animations.
	if imported_model_loaded:

		_animate_imported_model(horizontal_speed)

	else:

		# Procedural fallback animation.
		var swing: float = (
			sin(walk_phase)
			* walk_intensity
			* 0.52
		)

		if left_leg != null:
			left_leg.rotation.x = swing

		if right_leg != null:
			right_leg.rotation.x = -swing

		if left_arm != null:
			left_arm.rotation.x = -swing * 0.7

		if right_arm != null:
			right_arm.rotation.x = swing * 0.7

		if carrying:

			if left_arm != null:
				left_arm.rotation.x = -0.62

			if right_arm != null:
				right_arm.rotation.x = -0.88

		if imported_model == null:
			position.y = (
				sin(walk_phase * 2.0)
				* walk_intensity
				* 0.025
			)

	# Oxygen indicators.
	var active_segments: int = int(
		ceil(
			clampf(oxygen_fraction, 0.0, 1.0) * 4.0
		)
	)

	for index in range(oxygen_segments.size()):
		oxygen_segments[index].visible = (
			index < active_segments
		)

	# Flashlight reacts to low oxygen.
	if shoulder_light != null:

		if oxygen_fraction < 0.25:

			shoulder_light.light_color = Color(
				1.0,
				0.10,
				0.06
			)

		else:

			shoulder_light.light_color = (
				role_color.lightened(0.25)
			)
