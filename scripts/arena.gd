
extends Node3D
class_name GameArena

const FUEL_CELL_SCENE: PackedScene = preload("res://scenes/fuel_cell.tscn")
const TERMINAL_SCENE: PackedScene = preload("res://scenes/terminal.tscn")
const POD_SCENE: PackedScene = preload("res://scenes/pod.tscn")

const CRUSHER_SCRIPT = preload("res://scripts/piston_crusher.gd")
const SPARK_SCRIPT = preload("res://scripts/hull_breach_spark.gd")
const DRONE_SCRIPT = preload("res://scripts/security_drone.gd")
const MATERIALS = preload("res://scripts/industrial_materials.gd")

@export_category("Level Dimensions")
@export var arena_width: float = 48.0
@export var arena_depth: float = 44.0
@export var wall_height: float = 5.5

@export_category("Fuel Cells")
@export var fuel_spawn_positions: Array[Vector3] = [
	Vector3(-16.0, 0.55, -7.0),
	Vector3(16.0, 0.55, -7.0),
	Vector3(-5.0, 0.55, 16.0)
]

@export_category("Airlock")
@export var airlock_suction_position: Vector3 = Vector3(22.0, 0.5, 0.0)

var pod: EscapePod
var terminals: Array = []
var fuel_cells: Array = []
var breach_sparks: Array = []
var crushers: Array = []
var drone: Node3D

@export_category("Hull Breach Events")
@export var breach_respawn_seconds: float = 22.0

@export var breach_spawn_positions: Array[Vector3] = [
	Vector3(-19.0, 0.0, 7.0),
	Vector3(19.0, 0.0, 7.0)
]

var _breach_respawn_clock: float = 0.0

var emergency_lights: Array[OmniLight3D] = []
var beacon_rotors: Array[MeshInstance3D] = []

var emergency_active: bool = false
var door_body: StaticBody3D
var door_mesh: MeshInstance3D
var door_shape: CollisionShape3D

var shaft_hazard: Area3D


func _ready() -> void:
	_build_environment()
	_build_geometry()
	_build_lighting()
	_build_pod()
	_build_terminals()
	_build_airlock_zone()
	_build_hazards()
	_build_void_kill_plane()
	spawn_fuel_cells()

func _spawn_breach_spark_at(point: Vector3) -> void:
	var spark := Area3D.new()
	spark.set_script(SPARK_SCRIPT)
	spark.position = point
	add_child(spark)
	breach_sparks.append(spark)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "TartarusEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.003, 0.005, 0.012)

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.56, 0.68)
	environment.ambient_light_energy = 1.15

	# Temporarily disable volumetric fog while fixing visibility.
	environment.volumetric_fog_enabled = false

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES

	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_bloom = 0.12

	environment.ssao_enabled = true
	environment.ssao_radius = 1.6
	environment.ssao_intensity = 1.4

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.012
	environment.volumetric_fog_albedo = Color(0.16, 0.19, 0.24)
	environment.volumetric_fog_emission = Color(0.015, 0.009, 0.025)

	world.environment = environment
	add_child(world)


func _build_geometry() -> void:
	var deck := MATERIALS.make_surface(
		Color(0.105, 0.13, 0.16), 0.84, 0.52, 11, 0.16
	)

	var rust := MATERIALS.make_surface(
		Color(0.16, 0.075, 0.048), 0.74, 0.72, 37, 0.23
	)

	var wall := MATERIALS.make_surface(
		Color(0.065, 0.085, 0.105), 0.91, 0.46, 81, 0.12
	)

	var yellow := MATERIALS.make_emissive(
		Color(0.8, 0.48, 0.035),
		Color(0.7, 0.22, 0.015),
		0.65
	)

	# =====================================================
	# CENTRAL POD BAY
	# =====================================================

	_add_static_box(
		"CentralPodDeck",
		Vector3(0, -0.5, 0),
		Vector3(18, 1, 18),
		deck
	)

	# Raised extraction platform.
	_add_static_box(
		"RaisedEscapePlatform",
		Vector3(0, 0.4, 0),
		Vector3(12, 0.8, 12),
		wall
	)

	_add_ramp(Vector3(-8.0, 0.34, 0), -1)
	_add_ramp(Vector3(8.0, 0.34, 0), 1)

	# Hazard-yellow platform perimeter.
	for point in [
		Vector3(0, 0.85, -6.0),
		Vector3(0, 0.85, 6.0),
		Vector3(-6.0, 0.85, 0),
		Vector3(6.0, 0.85, 0)
	]:
		var marking := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.3, 0.05, 0.3)
		marking.mesh = mesh
		marking.position = point
		marking.material_override = yellow
		add_child(marking)

	_add_room_label(
		"ESCAPE POD BAY // CLAUSE 99",
		Vector3(0, 3.0, -7.0),
		Color(1.0, 0.72, 0.25)
	)

	_build_black_hole(Vector3(0, -2.1, 0), 5.5)

	# =====================================================
	# REACTOR CORE — WEST WING
	# =====================================================

	_add_static_box(
		"ReactorDeck",
		Vector3(-16, -0.5, 0),
		Vector3(14, 1, 22),
		rust
	)

	_add_static_box(
		"ReactorNorthWall",
		Vector3(-16, 2.5, -10.8),
		Vector3(14, 5, 0.4),
		wall
	)

	_add_static_box(
		"ReactorWestWall",
		Vector3(-23, 2.5, 0),
		Vector3(0.5, 5, 22),
		wall
	)

	_add_static_box(
		"ReactorEastBulkheadNorth",
		Vector3(-9, 2.5, -7),
		Vector3(0.4, 5, 7),
		wall
	)

	_add_static_box(
		"ReactorEastBulkheadSouth",
		Vector3(-9, 2.5, 7),
		Vector3(0.4, 5, 7),
		wall
	)

	_add_room_label(
		"01 // REACTOR CORE — RADIATION HAZARD",
		Vector3(-16, 3.5, -9.5),
		Color(1.0, 0.48, 0.08)
	)

	# =====================================================
	# CARGO HOLD — EAST WING
	# =====================================================

	_add_static_box(
		"CargoDeck",
		Vector3(16, -0.5, 0),
		Vector3(14, 1, 22),
		deck
	)

	_add_static_box(
		"CargoEastWall",
		Vector3(23, 2.5, 0),
		Vector3(0.5, 5, 22),
		wall
	)

	_add_static_box(
		"CargoNorthWall",
		Vector3(16, 2.5, -10.8),
		Vector3(14, 5, 0.4),
		wall
	)

	_add_static_box(
		"CargoWestBulkheadNorth",
		Vector3(9, 2.5, -7),
		Vector3(0.4, 5, 7),
		wall
	)

	_add_static_box(
		"CargoWestBulkheadSouth",
		Vector3(9, 2.5, 7),
		Vector3(0.4, 5, 7),
		wall
	)

	_add_room_label(
		"02 // CARGO HOLD — KEEP CLEAR",
		Vector3(16, 3.5, -9.5),
		Color(0.35, 0.86, 1.0)
	)

	# Stacked containers provide actual layer-1 cover.
	_add_static_box(
		"CargoCrateA",
		Vector3(13, 1.1, -2.5),
		Vector3(3.0, 2.2, 2.6),
		rust
	)

	_add_static_box(
		"CargoCrateB",
		Vector3(19, 1.1, -5.0),
		Vector3(2.6, 2.2, 3.0),
		wall
	)

	_add_static_box(
		"CargoCrateC",
		Vector3(14.5, 0.8, 5.0),
		Vector3(2.0, 1.6, 2.0),
		rust
	)

	# =====================================================
	# GRAVITY CONTROL LAB — SOUTH WING
	# =====================================================

	# Left and right catwalks. The central shaft has no floor.
	_add_static_box(
		"GravityLeftCatwalk",
		Vector3(-5, -0.5, 16),
		Vector3(8, 1, 12),
		deck
	)

	_add_static_box(
		"GravityRightCatwalk",
		Vector3(5, -0.5, 16),
		Vector3(8, 1, 12),
		deck
	)

	_add_static_box(
		"GravityEntryBridge",
		Vector3(0, -0.5, 9.5),
		Vector3(8, 1, 3),
		deck
	)

	_add_static_box(
		"GravitySouthWall",
		Vector3(0, 2.5, 22),
		Vector3(18, 5, 0.5),
		wall
	)

	# Catwalk guard rails.
	for side in [-1.0, 1.0]:
		_add_static_box(
			"CatwalkRail_%d" % int(side),
			Vector3(side * 1.2, 1.0, 16),
			Vector3(0.18, 2.0, 12),
			yellow
		)

	_add_room_label(
		"03 // GRAVITY CONTROL LAB",
		Vector3(0, 4.0, 21),
		Color(0.15, 0.8, 1.0)
	)

	# Shaft death zone. Its central opening is genuinely walkable
	# only on the surrounding catwalks.
	shaft_hazard = Area3D.new()
	shaft_hazard.name = "OpenReactorShaft"
	shaft_hazard.collision_layer = 16
	shaft_hazard.collision_mask = 2
	shaft_hazard.monitoring = true
	shaft_hazard.position = Vector3(0, -3.0, 16)

	var shaft_shape := CollisionShape3D.new()
	var shaft_box := BoxShape3D.new()
	shaft_box.size = Vector3(2.5, 2.0, 9.0)
	shaft_shape.shape = shaft_box
	shaft_hazard.add_child(shaft_shape)
	shaft_hazard.body_entered.connect(_on_shaft_body_entered)
	add_child(shaft_hazard)

	_build_black_hole(Vector3(0, -5.0, 16), 4.5)

	# =====================================================
	# OUTER BULKHEADS AND CONNECTIONS
	# =====================================================

	_add_static_box(
		"NorthOuterHull",
		Vector3(0, 2.5, -22),
		Vector3(48, 5, 0.5),
		wall
	)

	_add_static_box(
		"SouthOuterHull",
		Vector3(0, 2.5, 22),
		Vector3(48, 5, 0.5),
		wall
	)

	# Navigation lights along the wing access points.
	for point in [
		Vector3(-9, 0.2, 0),
		Vector3(9, 0.2, 0),
		Vector3(0, 0.2, 9)
	]:
		var marker := MeshInstance3D.new()
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(0.18, 0.05, 1.5)
		marker.mesh = marker_mesh
		marker.position = point
		marker.material_override = yellow
		add_child(marker)


func _add_ramp(position_value: Vector3, direction: int) -> void:
	var body := StaticBody3D.new()
	body.name = "PodAccessRamp"
	body.position = position_value
	body.rotation.z = deg_to_rad(float(-direction) * 9.0)
	body.collision_layer = 1
	body.collision_mask = 2 | 8

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.0, 0.3, 3.5)
	shape_node.shape = shape
	body.add_child(shape_node)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.material_override = MATERIALS.make_surface(
		Color(0.14, 0.17, 0.20), 0.8, 0.55, 93
	)
	body.add_child(mesh)

	add_child(body)


func _build_black_hole(position_value: Vector3, radius: float) -> void:
	var disk := MeshInstance3D.new()
	disk.name = "SwirlingAccretionDisk"

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.12
	mesh.radial_segments = 64
	disk.mesh = mesh
	disk.position = position_value
	disk.material_override = MATERIALS.make_black_hole_material()
	add_child(disk)


func _add_room_label(
	text_value: String,
	position_value: Vector3,
	color: Color
) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = 30
	label.pixel_size = 0.005
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	add_child(label)



func _build_lighting() -> void:

	# --------------------------------------------------------
	# MAIN DIRECTIONAL LIGHT
	# --------------------------------------------------------

	var key := DirectionalLight3D.new()

	key.name = "IndustrialMainLight"
	key.rotation_degrees = Vector3(-55, -35, 0)

	key.light_color = Color(0.75, 0.82, 1.0)
	key.light_energy = 2.0
	key.shadow_enabled = true

	add_child(key)

	# --------------------------------------------------------
	# GLOBAL DECK FILL LIGHT
	# --------------------------------------------------------

	var deck_fill := OmniLight3D.new()

	deck_fill.name = "DeckReadabilityLight"
	deck_fill.position = Vector3(0.0, 9.0, 0.0)

	deck_fill.light_color = Color(0.58, 0.72, 1.0)
	deck_fill.light_energy = 5.0
	deck_fill.omni_range = 55.0

	deck_fill.shadow_enabled = false

	add_child(deck_fill)

	# --------------------------------------------------------
	# FOUR ROOM LIGHTS
	# --------------------------------------------------------

	var room_positions: Array[Vector3] = [
		Vector3(-16.0, 4.0, -3.0),
		Vector3(16.0, 4.0, -3.0),
		Vector3(-5.0, 4.0, 16.0),
		Vector3(5.0, 4.0, 16.0)
	]

	for index in range(room_positions.size()):

		var room_light := OmniLight3D.new()

		room_light.name = "RoomFillLight_%d" % index
		room_light.position = room_positions[index]

		room_light.light_energy = 3.0
		room_light.light_color = Color(0.65, 0.76, 0.95)
		room_light.omni_range = 18.0

		room_light.shadow_enabled = false

		add_child(room_light)

	# --------------------------------------------------------
	# EMERGENCY BEACONS
	# --------------------------------------------------------

	for point in [
		Vector3(-17.0, 3.2, -7.0),
		Vector3(16.0, 3.2, -7.0),
		Vector3(-5.0, 3.2, 16.0),
		Vector3(5.0, 3.2, 16.0)
	]:

		var beacon_mesh := MeshInstance3D.new()

		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.25
		cylinder.bottom_radius = 0.25
		cylinder.height = 0.35

		beacon_mesh.mesh = cylinder
		beacon_mesh.position = point

		beacon_mesh.material_override = MATERIALS.make_emissive(
			Color(1.0, 0.025, 0.01),
			Color(1.0, 0.015, 0.005),
			3.0
		)

		beacon_mesh.visible = false

		add_child(beacon_mesh)
		beacon_rotors.append(beacon_mesh)

		var light := OmniLight3D.new()

		light.position = point
		light.light_color = Color(1.0, 0.025, 0.01)
		light.light_energy = 0.0
		light.omni_range = 10.0
		light.shadow_enabled = false

		add_child(light)
		emergency_lights.append(light)



func _build_pod() -> void:
	pod = POD_SCENE.instantiate() as EscapePod
	pod.name = "CentralEscapePod"
	pod.position = Vector3(0, 0.8, 0)
	add_child(pod)


func _build_terminals() -> void:
	var airlock := TERMINAL_SCENE.instantiate() as SabotageTerminal
	airlock.name = "AirlockVentingTerminal"
	airlock.configure("airlock", "AIRLOCK VENTING")
	airlock.position = Vector3(18.0, 0.0, 4.8)
	airlock.cooldown_seconds = 25.0
	add_child(airlock)
	terminals.append(airlock)

	var gravity := TERMINAL_SCENE.instantiate() as SabotageTerminal
	gravity.name = "GravityInverterTerminal"
	gravity.configure("gravity", "GRAVITY INVERTER")
	gravity.position = Vector3(-5.0, 0.0, 19.0)
	gravity.cooldown_seconds = 25.0
	add_child(gravity)
	terminals.append(gravity)



func _build_airlock_zone() -> void:

	var zone := Area3D.new()
	zone.name = "ExteriorAirlockHazard"

	zone.collision_layer = 16
	zone.collision_mask = 2
	zone.monitoring = true

	zone.position = Vector3(22.0, 1.0, 0.0)

	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()

	box.size = Vector3(2.0, 3.0, 4.0)
	shape_node.shape = box

	zone.add_child(shape_node)

	zone.body_entered.connect(_on_airlock_body_entered)

	add_child(zone)

	_add_room_label(
		"EXTERIOR AIRLOCK // VACUUM",
		Vector3(21.5, 3.0, -3.0),
		Color.RED
	)

	# --------------------------------------------------------
	# BLAST DOOR
	# --------------------------------------------------------

	door_body = StaticBody3D.new()
	door_body.name = "AirlockBlastDoor"

	door_body.collision_layer = 1
	door_body.collision_mask = 2

	add_child(door_body)

	door_shape = CollisionShape3D.new()

	var door_box := BoxShape3D.new()
	door_box.size = Vector3(0.3, 3.5, 4.0)

	door_shape.shape = door_box
	door_shape.position = Vector3(20.0, 1.75, 0.0)
	door_shape.disabled = true

	door_body.add_child(door_shape)

	door_mesh = MeshInstance3D.new()

	var door_mesh_shape := BoxMesh.new()
	door_mesh_shape.size = door_box.size

	door_mesh.mesh = door_mesh_shape
	door_mesh.position = door_shape.position

	door_mesh.material_override = MATERIALS.make_emissive(
		Color(0.35, 0.09, 0.06),
		Color(1.0, 0.04, 0.015),
		0.9
	)

	door_mesh.visible = false

	door_body.add_child(door_mesh)

	# --------------------------------------------------------
	# FROSTED DOOR FRAME
	# --------------------------------------------------------

	for side in [-1.0, 1.0]:

		var frost := MeshInstance3D.new()
		var frost_mesh := BoxMesh.new()

		frost_mesh.size = Vector3(0.09, 3.2, 0.18)

		frost.mesh = frost_mesh

		frost.position = Vector3(
			20.17,
			1.75,
			side * 1.85
		)

		frost.material_override = MATERIALS.make_emissive(
			Color(0.15, 0.42, 0.57),
			Color(0.025, 0.28, 0.55),
			1.2
		)

		door_body.add_child(frost)

	# --------------------------------------------------------
	# ELECTRICAL SPARK PARTICLES
	# --------------------------------------------------------

	var sparks := GPUParticles3D.new()

	sparks.name = "AirlockElectricalSparks"
	sparks.amount = 32
	sparks.lifetime = 0.45
	sparks.explosiveness = 0.0

	sparks.position = Vector3(20.0, 1.5, 1.5)

	var particle_process := ParticleProcessMaterial.new()

	particle_process.direction = Vector3(0.0, 1.0, 0.0)
	particle_process.spread = 65.0

	particle_process.initial_velocity_min = 0.5
	particle_process.initial_velocity_max = 3.2

	particle_process.gravity = Vector3(0.0, -4.0, 0.0)

	particle_process.scale_min = 0.025
	particle_process.scale_max = 0.065

	sparks.process_material = particle_process

	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.035
	particle_mesh.height = 0.07

	sparks.draw_pass_1 = particle_mesh
	sparks.emitting = true

	add_child(sparks)




func _build_hazards() -> void:

	# --------------------------------------------------------
	# HYDRAULIC CRUSHERS
	# --------------------------------------------------------

	for point in [
		Vector3(-15.0, 0.0, -3.5),
		Vector3(-15.0, 0.0, 4.0)
	]:

		var crusher := Node3D.new()

		crusher.set_script(CRUSHER_SCRIPT)
		crusher.position = point

		add_child(crusher)
		crushers.append(crusher)

	# --------------------------------------------------------
	# EXACTLY TWO INITIAL HULL BREACHES
	# --------------------------------------------------------

	for point in breach_spawn_positions:
		_spawn_breach_spark_at(point)

	_breach_respawn_clock = 0.0

	# --------------------------------------------------------
	# SECURITY DRONE — ACTIVATES IN PHASE 2
	# --------------------------------------------------------

	drone = Node3D.new()

	drone.name = "AutomatedSecurityDrone"
	drone.set_script(DRONE_SCRIPT)

	drone.position = Vector3(12.0, 3.8, -8.0)

	add_child(drone)



func _add_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:

	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 2 | 8

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	add_child(body)
	return body


func _on_shaft_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		body.eliminate(
			"gravity shaft fall — personnel were not tethered to a safety rail"
		)


func _on_airlock_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		body.eliminate(
			"unplanned exterior exposure — safety training not completed"
		)


func spawn_fuel_cells() -> void:
	fuel_cells.clear()

	for position_value in fuel_spawn_positions:
		var cell := FUEL_CELL_SCENE.instantiate() as FuelCell
		cell.position = position_value
		add_child(cell)
		fuel_cells.append(cell)



func find_nearest_breach_spark(
	player: Node3D,
	max_distance: float
) -> Node3D:

	var nearest: Node3D = null
	var best_distance: float = max_distance

	for node in get_tree().get_nodes_in_group("hull_breaches"):

		if not is_instance_valid(node):
			continue

		if not node is Node3D:
			continue

		var spark: Node3D = node as Node3D

		var distance: float = (
			player.global_position.distance_to(
				spark.global_position
			)
		)

		if distance < best_distance:

			best_distance = distance
			nearest = spark

	return nearest



func get_active_breach_count() -> int:
	return get_tree().get_nodes_in_group("hull_breaches").size()



func reset_arena() -> void:

	# --------------------------------------------------------
	# REMOVE OLD FUEL CELLS
	# --------------------------------------------------------

	for cell in fuel_cells:

		if is_instance_valid(cell):
			cell.queue_free()

	fuel_cells.clear()

	# --------------------------------------------------------
	# REMOVE OLD HULL BREACHES
	# --------------------------------------------------------

	for spark in breach_sparks:

		if is_instance_valid(spark):

			if spark.is_in_group("hull_breaches"):
				spark.remove_from_group("hull_breaches")

			spark.queue_free()

	breach_sparks.clear()

	_breach_respawn_clock = 0.0

	# --------------------------------------------------------
	# SPAWN TWO NEW BREACHES
	# --------------------------------------------------------

	for point in breach_spawn_positions:
		_spawn_breach_spark_at(point)

	# --------------------------------------------------------
	# RESET FUEL CELLS
	# --------------------------------------------------------

	spawn_fuel_cells()

	# --------------------------------------------------------
	# RESET POD
	# --------------------------------------------------------

	if pod != null:
		pod.reset_pod()

	# --------------------------------------------------------
	# RESET HAZARDS
	# --------------------------------------------------------

	set_doors_sealed(false)
	set_emergency_state(false)

	# --------------------------------------------------------
	# RESET SABOTAGE TERMINALS
	# --------------------------------------------------------

	for terminal in terminals:

		if is_instance_valid(terminal):

			terminal.set_unlocked(false)
			terminal.cooldown_remaining = 0.0

	# Reset crushers to their initial phase.
	for crusher in crushers:

		if is_instance_valid(crusher):
			crusher.set_physics_process(false)
			crusher.set_physics_process(true)



func set_emergency_state(active: bool) -> void:

	emergency_active = active

	for rotor in beacon_rotors:
		rotor.visible = active

	if drone != null and is_instance_valid(drone):
		drone.call("set_active", active)

	if not active:

		for light in emergency_lights:
			light.light_energy = 0.0


func set_doors_sealed(active: bool) -> void:
	if door_shape != null:
		door_shape.disabled = not active

	if door_mesh != null:
		door_mesh.visible = active


func set_terminals_unlocked(active: bool) -> void:
	for terminal in terminals:
		terminal.set_unlocked(active)



func _build_void_kill_plane() -> void:

	var kill_zone := Area3D.new()
	kill_zone.name = "UniversalVoidKillPlane"

	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 2
	kill_zone.monitoring = true

	kill_zone.position = Vector3(0.0, -8.0, 0.0)

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()

	shape.size = Vector3(120.0, 2.0, 120.0)
	shape_node.shape = shape

	kill_zone.add_child(shape_node)

	kill_zone.body_entered.connect(_on_void_body_entered)

	add_child(kill_zone)


func _on_void_body_entered(body: Node3D) -> void:

	if body is PlayerController:

		var player := body as PlayerController

		if player.is_alive:
			player.eliminate(
				"event horizon exposure — personnel fell below the mining deck"
			)


func _process(delta: float) -> void:

	# --------------------------------------------------------
	# PHASE 2 / PHASE 3 EMERGENCY LIGHTING
	# --------------------------------------------------------

	if emergency_active:

		var pulse: float = 1.1 + 1.3 * (
			0.5
			+ 0.5 * sin(
				float(Time.get_ticks_msec()) * 0.007
			)
		)

		for light in emergency_lights:
			light.light_energy = pulse

		for rotor in beacon_rotors:
			rotor.rotate_y(delta * 1.8)

	# --------------------------------------------------------
	# HULL BREACH RESPAWNING
	# --------------------------------------------------------

	var active_breaches: Array[Node] = []

	for node in get_tree().get_nodes_in_group("hull_breaches"):

		if is_instance_valid(node):
			active_breaches.append(node)

	if active_breaches.size() < 2:

		_breach_respawn_clock += delta

		if _breach_respawn_clock >= breach_respawn_seconds:

			_breach_respawn_clock = 0.0

			for point in breach_spawn_positions:

				var occupied: bool = false

				for active_spark in active_breaches:

					if not active_spark is Node3D:
						continue

					var active_breach: Node3D = (
						active_spark as Node3D
					)

					var breach_distance: float = (
						active_breach.global_position.distance_to(point)
					)

					if breach_distance < 1.0:
						occupied = true
						break

				if not occupied:

					_spawn_breach_spark_at(point)
					break

	else:

		_breach_respawn_clock = 0.0
