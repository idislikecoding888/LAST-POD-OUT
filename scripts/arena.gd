extends Node3D
class_name GameArena

## Five-room enclosed USCSS Tartarus-9 deck.
## Gameplay-facing methods/properties preserve the V1 GameManager contract.

const FUEL_CELL_SCENE: PackedScene = preload("res://scenes/fuel_cell.tscn")
const TERMINAL_SCENE: PackedScene = preload("res://scenes/terminal.tscn")
const POD_SCENE: PackedScene = preload("res://scenes/pod.tscn")

const CRUSHER_SCRIPT = preload("res://scripts/piston_crusher.gd")
const SPARK_SCRIPT = preload("res://scripts/hull_breach_spark.gd")
const DRONE_SCRIPT = preload("res://scripts/security_drone.gd")
const MATERIALS = preload("res://scripts/industrial_materials.gd")
const ASSET_LOADER = preload("res://scripts/asset_loader.gd")

@export_category("Room Layout")
@export var room_size: float = 18.0
@export var wall_height: float = 3.5
@export var wall_thickness: float = 0.55
@export var doorway_width: float = 4.8

@export_category("Fuel Cells")
@export var fuel_spawn_positions: Array[Vector3] = [
	Vector3(-18.0, 0.58, -3.5),
	Vector3(18.0, 0.58, -3.5),
	Vector3(0.0, 0.58, 18.0)
]

@export_category("Airlock")
@export var airlock_suction_position: Vector3 = Vector3(29.0, 0.8, 0.0)
@export var airlock_door_position: Vector3 = Vector3(24.8, 0.0, 0.0)

@export_category("Hull Breach Events")
@export var breach_respawn_seconds: float = 22.0
@export var breach_spawn_positions: Array[Vector3] = [
	Vector3(-23.0, 0.0, 5.8),
	Vector3(22.0, 0.0, 5.8)
]

@export_category("Med-Bay Oxygen")
@export var oxygen_recharge_per_second: float = 12.0

var pod: EscapePod
var terminals: Array = []
var fuel_cells: Array = []
var breach_sparks: Array = []
var crushers: Array = []
var drone: Node3D

var emergency_lights: Array[OmniLight3D] = []
var beacon_rotors: Array[MeshInstance3D] = []
var oxygen_station_areas: Array[Area3D] = []

var emergency_active: bool = false
var door_body: StaticBody3D
var door_mesh: MeshInstance3D
var door_shape: CollisionShape3D
var door_material: StandardMaterial3D
var _breach_respawn_clock: float = 0.0
var _world_environment: WorldEnvironment


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


# ============================================================
# ENVIRONMENT / MATERIALS
# ============================================================

func _build_environment() -> void:
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "TartarusWorldEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.028, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.79, 0.9)
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.08
	environment.ssao_enabled = true
	environment.ssao_radius = 1.25
	environment.ssao_intensity = 1.1
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0025
	environment.volumetric_fog_albedo = Color(0.34, 0.4, 0.5)
	environment.volumetric_fog_emission = Color(0.015, 0.022, 0.035)
	environment.volumetric_fog_length = 55.0

	_world_environment.environment = environment
	add_child(_world_environment)


func _build_geometry() -> void:
	var floor_center := MATERIALS.make_surface(Color(0.22, 0.27, 0.32), 0.78, 0.42, 101, 0.10)
	var floor_reactor := MATERIALS.make_surface(Color(0.12, 0.19, 0.27), 0.82, 0.35, 102, 0.12)
	var floor_cargo := MATERIALS.make_surface(Color(0.24, 0.18, 0.13), 0.72, 0.5, 103, 0.12)
	var floor_gravity := MATERIALS.make_surface(Color(0.12, 0.22, 0.27), 0.75, 0.36, 104, 0.09)
	var floor_medbay := MATERIALS.make_surface(Color(0.16, 0.25, 0.22), 0.62, 0.52, 105, 0.08)
	var wall_material := MATERIALS.make_surface(Color(0.24, 0.29, 0.34), 0.86, 0.34, 120, 0.10)
	var bulkhead_material := MATERIALS.make_surface(Color(0.12, 0.16, 0.2), 0.91, 0.4, 121, 0.15)
	var hazard_yellow := MATERIALS.make_emissive(Color(0.95, 0.62, 0.08), Color(0.85, 0.34, 0.025), 0.85)
	var reactor_blue := MATERIALS.make_emissive(Color(0.08, 0.38, 0.78), Color(0.025, 0.24, 0.9), 1.35)
	var cargo_orange := MATERIALS.make_emissive(Color(0.85, 0.33, 0.08), Color(0.8, 0.15, 0.025), 0.85)
	var gravity_cyan := MATERIALS.make_emissive(Color(0.08, 0.65, 0.78), Color(0.025, 0.55, 0.9), 0.9)
	var medbay_green := MATERIALS.make_emissive(Color(0.08, 0.72, 0.4), Color(0.025, 0.65, 0.28), 0.9)

	# --------------------------------------------------------
	# FIVE CONTIGUOUS ROOM FLOORS
	# All room decks are at Y=0 and touch at their doorways.
	# --------------------------------------------------------

	_add_static_box("PodBay_Floor", Vector3(0.0, -0.5, 0.0), Vector3(18.0, 1.0, 18.0), floor_center)
	_add_static_box("Reactor_Floor", Vector3(-18.0, -0.5, 0.0), Vector3(18.0, 1.0, 18.0), floor_reactor)
	_add_static_box("Cargo_Floor", Vector3(18.0, -0.5, 0.0), Vector3(18.0, 1.0, 18.0), floor_cargo)
	_add_static_box("MedBay_Floor", Vector3(0.0, -0.5, 18.0), Vector3(18.0, 1.0, 18.0), floor_medbay)

	# --------------------------------------------------------
	# CENTRAL POD BAY WALLS — FOUR DOORWAYS
	# --------------------------------------------------------

	var half: float = room_size * 0.5
	var door_half: float = doorway_width * 0.5
	var wall_y: float = wall_height * 0.5
	var side_segment: float = half - door_half

	# West and east pod-bay walls, leaving centered openings.
	for x_side in [-half, half]:
		_add_static_box("PodBay_SideWall_A", Vector3(x_side, wall_y, -half + side_segment * 0.5), Vector3(wall_thickness, wall_height, side_segment), wall_material)
		_add_static_box("PodBay_SideWall_B", Vector3(x_side, wall_y, half - side_segment * 0.5), Vector3(wall_thickness, wall_height, side_segment), wall_material)
		_add_static_box("PodBay_DoorHeader", Vector3(x_side, wall_height - 0.18, 0.0), Vector3(wall_thickness, 0.36, doorway_width), bulkhead_material)

	# North and south pod-bay walls, leaving centered openings.
	for z_side in [-half, half]:
		_add_static_box("PodBay_EndWall_A", Vector3(-half + side_segment * 0.5, wall_y, z_side), Vector3(side_segment, wall_height, wall_thickness), wall_material)
		_add_static_box("PodBay_EndWall_B", Vector3(half - side_segment * 0.5, wall_y, z_side), Vector3(side_segment, wall_height, wall_thickness), wall_material)
		_add_static_box("PodBay_DoorHeader", Vector3(0.0, wall_height - 0.18, z_side), Vector3(doorway_width, 0.36, wall_thickness), bulkhead_material)

	# Doorway hazard-light jambs.
	for point in [
		Vector3(-half, 0.0, -door_half), Vector3(-half, 0.0, door_half),
		Vector3(half, 0.0, -door_half), Vector3(half, 0.0, door_half),
		Vector3(-door_half, 0.0, -half), Vector3(door_half, 0.0, -half),
		Vector3(-door_half, 0.0, half), Vector3(door_half, 0.0, half)
	]:
		_add_floor_stripe("DoorwayHazardJamb", point + Vector3.UP * 0.08, Vector3(0.24, 0.12, 1.0), hazard_yellow)

	# --------------------------------------------------------
	# WEST REACTOR WING — ENCLOSED PERIMETER
	# --------------------------------------------------------

	_add_static_box("Reactor_NorthWall", Vector3(-18.0, wall_y, -9.0), Vector3(18.0, wall_height, wall_thickness), wall_material)
	_add_static_box("Reactor_SouthWall", Vector3(-18.0, wall_y, 9.0), Vector3(18.0, wall_height, wall_thickness), wall_material)
	_add_static_box("Reactor_WestWall", Vector3(-27.0, wall_y, 0.0), Vector3(wall_thickness, wall_height, 18.0), wall_material)

	# --------------------------------------------------------
	# EAST CARGO / AIRLOCK WING — WINDOW OPENING ON EAST WALL
	# --------------------------------------------------------

	_add_static_box("Cargo_NorthWall", Vector3(18.0, wall_y, -9.0), Vector3(18.0, wall_height, wall_thickness), wall_material)
	_add_static_box("Cargo_SouthWall", Vector3(18.0, wall_y, 9.0), Vector3(18.0, wall_height, wall_thickness), wall_material)
	_add_static_box("Cargo_EastWall_North", Vector3(27.0, wall_y, -7.0), Vector3(wall_thickness, wall_height, 4.0), wall_material)
	_add_static_box("Cargo_EastWall_South", Vector3(27.0, wall_y, 7.0), Vector3(wall_thickness, wall_height, 4.0), wall_material)
	_add_static_box("Cargo_WindowSill", Vector3(27.0, 0.2, 0.0), Vector3(wall_thickness, 0.4, 6.0), bulkhead_material)
	_add_static_box("Cargo_WindowHeader", Vector3(27.0, wall_height - 0.2, 0.0), Vector3(wall_thickness, 0.4, 6.0), bulkhead_material)
	_build_black_hole_window()

	# --------------------------------------------------------
	# NORTH GRAVITY CONTROL LAB — ENCLOSED PERIMETER
	# --------------------------------------------------------

	_add_static_box("Gravity_WestWall", Vector3(-9.0, wall_y, -18.0), Vector3(wall_thickness, wall_height, 18.0), wall_material)
	_add_static_box("Gravity_EastWall", Vector3(9.0, wall_y, -18.0), Vector3(wall_thickness, wall_height, 18.0), wall_material)
	_add_static_box("Gravity_NorthWall", Vector3(0.0, wall_y, -27.0), Vector3(18.0, wall_height, wall_thickness), wall_material)

	# Narrow luminous catwalk rails and floor grid: readable, not a black pit.
	_add_static_box("GravityCatwalkLeft", Vector3(-5.9, -0.22, -18.0), Vector3(6.2, 0.55, 18.0), floor_gravity)
	_add_static_box("GravityCatwalkRight", Vector3(5.9, -0.22, -18.0), Vector3(6.2, 0.55, 18.0), floor_gravity)
	_add_static_box("GravityCrossBridge", Vector3(0.0, -0.22, -10.2), Vector3(5.6, 0.55, 2.5), floor_gravity)
	_add_static_box("GravityCrossBridgeNorth", Vector3(0.0, -0.22, -25.4), Vector3(5.6, 0.55, 2.5), floor_gravity)
	_add_static_box("GravityCatwalkRailLeft", Vector3(-2.65, 0.9, -18.0), Vector3(0.16, 1.8, 18.0), hazard_yellow)
	_add_static_box("GravityCatwalkRailRight", Vector3(2.65, 0.9, -18.0), Vector3(0.16, 1.8, 18.0), hazard_yellow)

	# The recessed shaft is beneath the central walkway and has a visible warning rim.
	_add_static_box("GravityShaftVisual", Vector3(0.0, -2.6, -18.0), Vector3(4.6, 0.18, 12.0), MATERIALS.make_emissive(Color(0.012, 0.035, 0.07), Color(0.01, 0.08, 0.18), 0.6))
	_add_shaft_hazard(Vector3(0.0, -2.3, -18.0), Vector3(3.8, 2.0, 11.5))

	# --------------------------------------------------------
	# SOUTH MED-BAY / OXYGEN HUB — ENCLOSED PERIMETER
	# --------------------------------------------------------

	_add_static_box("MedBay_WestWall", Vector3(-9.0, wall_y, 18.0), Vector3(wall_thickness, wall_height, 18.0), wall_material)
	_add_static_box("MedBay_EastWall", Vector3(9.0, wall_y, 18.0), Vector3(wall_thickness, wall_height, 18.0), wall_material)
	_add_static_box("MedBay_SouthWall", Vector3(0.0, wall_y, 27.0), Vector3(18.0, wall_height, wall_thickness), wall_material)

	# Side-flank corridors return to the Pod Bay along both sides of Med-Bay.
	_add_static_box("MedBayFlankLeft", Vector3(-7.0, -0.22, 18.0), Vector3(3.4, 0.55, 18.0), floor_medbay)
	_add_static_box("MedBayFlankRight", Vector3(7.0, -0.22, 18.0), Vector3(3.4, 0.55, 18.0), floor_medbay)
	_add_static_box("MedBayCrossPassage", Vector3(0.0, -0.22, 10.1), Vector3(7.8, 0.55, 2.8), floor_medbay)

	# --------------------------------------------------------
	# ROOM STRIPES / LABELS / PROPS
	# --------------------------------------------------------

	_add_room_stripes(Vector3.ZERO, Vector2(17.0, 17.0), Color(1.0, 0.66, 0.08), "POD BAY")
	_add_room_stripes(Vector3(-18.0, 0.0, 0.0), Vector2(17.0, 17.0), Color(0.18, 0.55, 1.0), "REACTOR CORE")
	_add_room_stripes(Vector3(18.0, 0.0, 0.0), Vector2(17.0, 17.0), Color(1.0, 0.42, 0.12), "CARGO HOLD")
	_add_room_stripes(Vector3(0.0, 0.0, -18.0), Vector2(17.0, 17.0), Color(0.12, 0.78, 0.95), "GRAVITY LAB")
	_add_room_stripes(Vector3(0.0, 0.0, 18.0), Vector2(17.0, 17.0), Color(0.12, 0.85, 0.42), "MED-BAY")

	_add_room_label("CENTRAL ESCAPE POD BAY", Vector3(0.0, 3.0, -7.2), Color(1.0, 0.78, 0.28))
	_add_room_label("01 // REACTOR CORE", Vector3(-18.0, 3.1, -7.0), Color(0.36, 0.72, 1.0))
	_add_room_label("02 // AIRLOCK & CARGO", Vector3(18.0, 3.1, -7.0), Color(1.0, 0.62, 0.3))
	_add_room_label("03 // GRAVITY CONTROL LAB", Vector3(0.0, 3.1, -25.0), Color(0.3, 0.9, 1.0))
	_add_room_label("04 // MED-BAY & OXYGEN HUB", Vector3(0.0, 3.1, 25.0), Color(0.35, 1.0, 0.62))

	# Reactor generators, cargo containers and med-bay oxygen stations.
	_build_reactor_generators(reactor_blue)
	_build_cargo_crates()
	_build_oxygen_stations(medbay_green)

	# Distinct colored guide strips identify every room at doorway crossings.
	_add_floor_stripe("ReactorDoorGuide", Vector3(-9.0, 0.04, 0.0), Vector3(0.32, 0.08, 4.5), reactor_blue)
	_add_floor_stripe("CargoDoorGuide", Vector3(9.0, 0.04, 0.0), Vector3(0.32, 0.08, 4.5), cargo_orange)
	_add_floor_stripe("GravityDoorGuide", Vector3(0.0, 0.04, -9.0), Vector3(4.5, 0.08, 0.32), gravity_cyan)
	_add_floor_stripe("MedBayDoorGuide", Vector3(0.0, 0.04, 9.0), Vector3(4.5, 0.08, 0.32), medbay_green)


# ============================================================
# GEOMETRY HELPERS / OPTIONAL GLB MODELS
# ============================================================

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
	var box_shape := BoxShape3D.new()
	box_shape.size = size_value
	collision.shape = box_shape
	body.add_child(collision)

	var asset_key: String = _asset_key_for_node(node_name)
	var used_external_model: bool = false

	if asset_key == "floor":
		used_external_model = _add_tiled_environment_model(body, "floor", size_value, true)
	elif asset_key == "wall":
		used_external_model = _add_tiled_environment_model(body, "wall", size_value, false)
	elif not asset_key.is_empty():
		var external_model: Node3D = ASSET_LOADER.instantiate_environment_model(asset_key)
		if external_model != null:
			ASSET_LOADER.fit_model_to_size(external_model, size_value, asset_key == "crate")
			body.add_child(external_model)
			used_external_model = true

	if not used_external_model:
		var mesh_instance := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = size_value
		mesh_instance.mesh = box_mesh
		mesh_instance.material_override = material
		body.add_child(mesh_instance)

	add_child(body)
	return body


func _asset_key_for_node(node_name: String) -> String:
	var lower_name: String = node_name.to_lower()
	# Rails and trim should retain their hazard-strip materials.
	if lower_name.contains("rail") or lower_name.contains("stripe"):
		return ""
	if lower_name.contains("crate") or lower_name.contains("container"):
		return "crate"
	if lower_name.contains("floor") or lower_name.contains("deck") or lower_name.contains("catwalk"):
		return "floor"
	if lower_name.contains("wall") or lower_name.contains("bulkhead") or lower_name.contains("header") or lower_name.contains("sill"):
		return "wall"
	return ""


func _add_tiled_environment_model(
	parent: Node3D,
	asset_key: String,
	target_size: Vector3,
	is_floor: bool
) -> bool:
	# Check once before creating the repeated module grid.
	var probe: Node3D = ASSET_LOADER.instantiate_environment_model(asset_key)
	if probe == null:
		return false
	probe.free()

	var tile_limit: float = 4.5
	var count_x: int = maxi(1, ceili(target_size.x / tile_limit))
	var count_z: int = maxi(1, ceili(target_size.z / tile_limit))
	var tile_width: float = target_size.x / float(count_x)
	var tile_depth: float = target_size.z / float(count_z)

	for ix in range(count_x):
		for iz in range(count_z):
			var tile: Node3D = ASSET_LOADER.instantiate_environment_model(asset_key)
			if tile == null:
				return false
			var tile_height: float = 0.08 if is_floor else target_size.y
			var tile_size := Vector3(tile_width, tile_height, tile_depth)
			var fit_size: Vector3 = tile_size
			var rotate_wall_panel: bool = (not is_floor and target_size.z > target_size.x)
			if rotate_wall_panel:
				# Wall modules are authored with their long axis along local X.
				# Swap their fit dimensions before rotating into a Z-running wall.
				fit_size = Vector3(tile_depth, tile_height, tile_width)
			ASSET_LOADER.fit_model_to_size(tile, fit_size, false)
			if rotate_wall_panel:
				tile.rotation.y = PI * 0.5
			tile.position = Vector3(
				-target_size.x * 0.5 + tile_width * (float(ix) + 0.5),
				target_size.y * 0.5 - tile_height * 0.5 if is_floor else 0.0,
				-target_size.z * 0.5 + tile_depth * (float(iz) + 0.5)
			)
			parent.add_child(tile)
	return true


func _add_floor_stripe(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> void:
	var stripe := MeshInstance3D.new()
	stripe.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size_value
	stripe.mesh = mesh
	stripe.position = position_value
	stripe.material_override = material
	stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stripe)


func _add_room_stripes(
	center: Vector3,
	dimensions: Vector2,
	color: Color,
	room_name: String
) -> void:
	var stripe_material := MATERIALS.make_emissive(color, color, 0.38)
	var half_x: float = dimensions.x * 0.5
	var half_z: float = dimensions.y * 0.5
	var y: float = 0.035
	_add_floor_stripe(room_name + "_NorthStripe", center + Vector3(0.0, y, -half_z), Vector3(dimensions.x, 0.07, 0.12), stripe_material)
	_add_floor_stripe(room_name + "_SouthStripe", center + Vector3(0.0, y, half_z), Vector3(dimensions.x, 0.07, 0.12), stripe_material)
	_add_floor_stripe(room_name + "_WestStripe", center + Vector3(-half_x, y, 0.0), Vector3(0.12, 0.07, dimensions.y), stripe_material)
	_add_floor_stripe(room_name + "_EastStripe", center + Vector3(half_x, y, 0.0), Vector3(0.12, 0.07, dimensions.y), stripe_material)


func _add_room_label(text_value: String, position_value: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "RoomLabel_" + text_value.replace(" ", "_")
	label.text = text_value
	label.font_size = 48
	label.pixel_size = 0.008
	label.outline_size = 7
	label.outline_modulate = Color(0.015, 0.025, 0.04, 0.95)
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	add_child(label)


func _build_reactor_generators(glow_material: Material) -> void:
	for side in [-1.0, 1.0]:
		var generator_position := Vector3(-21.5, 0.0, side * 5.4)
		var generator := MeshInstance3D.new()
		generator.name = "ReactorFuelGenerator"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.72
		cylinder.bottom_radius = 0.82
		cylinder.height = 2.4
		cylinder.radial_segments = 32
		generator.mesh = cylinder
		generator.position = generator_position + Vector3.UP * 1.2
		generator.material_override = MATERIALS.make_surface(Color(0.075, 0.11, 0.17), 0.88, 0.29, 415, 0.08)
		add_child(generator)

		var core := MeshInstance3D.new()
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = 0.42
		core_mesh.bottom_radius = 0.42
		core_mesh.height = 1.75
		core.mesh = core_mesh
		core.position = generator.position
		core.material_override = glow_material
		add_child(core)

		var light := OmniLight3D.new()
		light.position = generator.position
		light.light_color = Color(0.12, 0.46, 1.0)
		light.light_energy = 2.2
		light.omni_range = 8.5
		light.shadow_enabled = false
		add_child(light)


func _build_cargo_crates() -> void:
	var crate_material := MATERIALS.make_surface(Color(0.19, 0.12, 0.075), 0.62, 0.65, 512, 0.13)
	_add_static_box("CargoCrate_Alpha", Vector3(13.2, 0.95, -3.1), Vector3(2.6, 1.9, 2.4), crate_material)
	_add_static_box("CargoCrate_Beta", Vector3(19.0, 0.95, -5.0), Vector3(2.4, 1.9, 2.8), crate_material)
	_add_static_box("CargoCrate_Gamma", Vector3(15.4, 0.75, 5.0), Vector3(2.1, 1.5, 2.0), crate_material)


func _build_oxygen_stations(glow_material: Material) -> void:
	for point in [Vector3(-5.0, 0.0, 18.0), Vector3(5.0, 0.0, 18.0)]:
		var station := Area3D.new()
		station.name = "MedBayOxygenStation"
		station.collision_layer = 0
		station.collision_mask = 2
		station.monitoring = true
		station.position = point

		var shape_node := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.8
		shape_node.shape = sphere
		station.add_child(shape_node)
		add_child(station)
		oxygen_station_areas.append(station)

		var tank := MeshInstance3D.new()
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 0.34
		tank_mesh.bottom_radius = 0.34
		tank_mesh.height = 1.45
		tank.mesh = tank_mesh
		tank.position = point + Vector3.UP * 0.73
		tank.material_override = MATERIALS.make_surface(Color(0.11, 0.2, 0.18), 0.76, 0.32, 617, 0.06)
		add_child(tank)

		var gauge := MeshInstance3D.new()
		var gauge_mesh := CylinderMesh.new()
		gauge_mesh.top_radius = 0.19
		gauge_mesh.bottom_radius = 0.19
		gauge_mesh.height = 0.95
		gauge.mesh = gauge_mesh
		gauge.position = tank.position
		gauge.material_override = glow_material
		add_child(gauge)

		var light := OmniLight3D.new()
		light.position = point + Vector3.UP * 1.25
		light.light_color = Color(0.1, 1.0, 0.48)
		light.light_energy = 1.3
		light.omni_range = 5.5
		light.shadow_enabled = false
		add_child(light)

		_add_room_label("OXYGEN REFILL", point + Vector3(0.0, 2.0, -1.5), Color(0.38, 1.0, 0.65))


func _build_black_hole_window() -> void:
	var glass := MeshInstance3D.new()
	glass.name = "CargoBlackHoleWindowGlass"
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(0.12, 3.0, 5.6)
	glass.mesh = glass_mesh
	glass.position = Vector3(27.0, 2.0, 0.0)
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.035, 0.11, 0.18, 0.34)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.metallic = 0.35
	glass_material.roughness = 0.15
	glass_material.emission_enabled = true
	glass_material.emission = Color(0.015, 0.08, 0.18)
	glass_material.emission_energy_multiplier = 0.65
	glass.material_override = glass_material
	add_child(glass)

	var disk := MeshInstance3D.new()
	disk.name = "ExteriorBlackHoleAccretionDisk"
	var disk_mesh := CylinderMesh.new()
	disk_mesh.top_radius = 3.5
	disk_mesh.bottom_radius = 3.5
	disk_mesh.height = 0.14
	disk_mesh.radial_segments = 72
	disk.mesh = disk_mesh
	disk.position = Vector3(29.5, 2.0, 0.0)
	disk.rotation.z = PI * 0.5
	disk.material_override = MATERIALS.make_black_hole_material()
	add_child(disk)

	var black_hole_light := OmniLight3D.new()
	black_hole_light.position = Vector3(28.2, 2.0, 0.0)
	black_hole_light.light_color = Color(1.0, 0.25, 0.08)
	black_hole_light.light_energy = 1.1
	black_hole_light.omni_range = 12.0
	black_hole_light.shadow_enabled = false
	add_child(black_hole_light)


func _add_shaft_hazard(position_value: Vector3, size_value: Vector3) -> void:
	var hazard := Area3D.new()
	hazard.name = "GravityShaftFallZone"
	hazard.collision_layer = 16
	hazard.collision_mask = 2
	hazard.monitoring = true
	hazard.position = position_value
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	shape_node.shape = shape
	hazard.add_child(shape_node)
	hazard.body_entered.connect(_on_shaft_body_entered)
	add_child(hazard)


# ============================================================
# LIGHTING — BRIGHT PHASE 1, RED ONLY IN EMERGENCY
# ============================================================

func _build_lighting() -> void:
	var fill := DirectionalLight3D.new()
	fill.name = "SoftIndustrialDirectionalFill"
	fill.rotation_degrees = Vector3(-58.0, -28.0, 0.0)
	fill.light_color = Color(0.78, 0.86, 1.0)
	fill.light_energy = 0.45
	fill.shadow_enabled = true
	add_child(fill)

	var room_lights: Array[Vector3] = [
		Vector3(0.0, 4.0, 0.0),
		Vector3(-18.0, 4.0, 0.0),
		Vector3(18.0, 4.0, 0.0),
		Vector3(0.0, 4.0, -18.0),
		Vector3(0.0, 4.0, 18.0)
	]

	for index in range(room_lights.size()):
		var ceiling_light := OmniLight3D.new()
		ceiling_light.name = "CoolWhiteCeilingLight_%d" % index
		ceiling_light.position = room_lights[index]
		ceiling_light.light_color = Color(0.72, 0.84, 1.0)
		ceiling_light.light_energy = 4.2
		ceiling_light.omni_range = 22.0
		ceiling_light.shadow_enabled = index == 0
		add_child(ceiling_light)

		var fixture := MeshInstance3D.new()
		var fixture_mesh := BoxMesh.new()
		fixture_mesh.size = Vector3(2.5, 0.12, 0.85)
		fixture.mesh = fixture_mesh
		fixture.position = room_lights[index] + Vector3(0.0, 0.25, 0.0)
		fixture.material_override = MATERIALS.make_emissive(Color(0.65, 0.82, 1.0), Color(0.45, 0.72, 1.0), 1.5)
		fixture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fixture)

	# Red emergency beacons exist but remain off in Phase 1.
	for point in [
		Vector3(-25.0, 3.0, -7.0),
		Vector3(25.0, 3.0, -7.0),
		Vector3(-7.0, 3.0, -25.0),
		Vector3(7.0, 3.0, 25.0)
	]:
		var beacon := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.23
		sphere.height = 0.46
		beacon.mesh = sphere
		beacon.position = point
		beacon.material_override = MATERIALS.make_emissive(Color(1.0, 0.025, 0.015), Color(1.0, 0.01, 0.005), 2.8)
		beacon.visible = false
		add_child(beacon)
		beacon_rotors.append(beacon)

		var red_light := OmniLight3D.new()
		red_light.position = point
		red_light.light_color = Color(1.0, 0.025, 0.012)
		red_light.light_energy = 0.0
		red_light.omni_range = 11.0
		red_light.shadow_enabled = false
		add_child(red_light)
		emergency_lights.append(red_light)


# ============================================================
# POD / TERMINALS / AIRLOCK / HAZARDS
# ============================================================

func _build_pod() -> void:
	pod = POD_SCENE.instantiate() as EscapePod
	pod.name = "CentralEscapePod"
	pod.position = Vector3(0.0, 0.0, 0.0)
	add_child(pod)

	var external_pod: Node3D = ASSET_LOADER.instantiate_environment_model("pod")
	if external_pod != null:
		ASSET_LOADER.fit_model_to_size(external_pod, Vector3(4.0, 3.5, 4.0), true)
		external_pod.position = Vector3(0.0, 0.25, 0.0)
		pod.add_child(external_pod)
		for existing_visual in pod.get_children():
			if existing_visual != external_pod and existing_visual is MeshInstance3D:
				existing_visual.visible = false

	# The pod still has an unmistakable hazard ring and boarding ramp.
	var ramp := MeshInstance3D.new()
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = Vector3(3.8, 0.14, 2.2)
	ramp.mesh = ramp_mesh
	ramp.position = Vector3(0.0, 0.10, 3.2)
	ramp.material_override = MATERIALS.make_emissive(Color(0.9, 0.65, 0.08), Color(0.75, 0.35, 0.025), 1.0)
	pod.add_child(ramp)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 3.05
	ring_mesh.outer_radius = 3.22
	ring_mesh.rings = 64
	ring_mesh.ring_segments = 14
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.position.y = 0.07
	ring.material_override = MATERIALS.make_emissive(Color(1.0, 0.62, 0.06), Color(0.95, 0.3, 0.015), 1.4)
	pod.add_child(ring)


func _build_terminals() -> void:
	var airlock_terminal := TERMINAL_SCENE.instantiate() as SabotageTerminal
	airlock_terminal.name = "AirlockVentingTerminal"
	airlock_terminal.configure("airlock", "AIRLOCK VENTING")
	airlock_terminal.position = Vector3(20.0, 0.0, 4.6)
	airlock_terminal.cooldown_seconds = 25.0
	add_child(airlock_terminal)
	terminals.append(airlock_terminal)
	_add_optional_console_model(airlock_terminal)

	var gravity_terminal := TERMINAL_SCENE.instantiate() as SabotageTerminal
	gravity_terminal.name = "GravityInverterTerminal"
	gravity_terminal.configure("gravity", "GRAVITY INVERTER")
	gravity_terminal.position = Vector3(-5.7, 0.0, -20.0)
	gravity_terminal.cooldown_seconds = 25.0
	add_child(gravity_terminal)
	terminals.append(gravity_terminal)
	_add_optional_console_model(gravity_terminal)


func _add_optional_console_model(parent: Node3D) -> void:
	var model: Node3D = ASSET_LOADER.instantiate_environment_model("console")
	if model == null:
		return
	ASSET_LOADER.fit_model_to_size(model, Vector3(1.2, 1.8, 1.0), true)
	model.position = Vector3(0.0, 0.35, 0.0)
	parent.add_child(model)


func _build_airlock_zone() -> void:
	# Door is rendered at all times; collision seals when venting is activated.
	door_body = StaticBody3D.new()
	door_body.name = "CargoAirlockBlastDoor"
	door_body.collision_layer = 1
	door_body.collision_mask = 2
	door_body.position = airlock_door_position
	add_child(door_body)

	door_shape = CollisionShape3D.new()
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(0.45, 3.3, 5.0)
	door_shape.shape = door_box
	door_shape.position = Vector3(0.0, 1.65, 0.0)
	door_shape.disabled = true
	door_body.add_child(door_shape)

	door_mesh = MeshInstance3D.new()
	var door_visual := BoxMesh.new()
	door_visual.size = door_box.size
	door_mesh.mesh = door_visual
	door_mesh.position = door_shape.position
	door_material = MATERIALS.make_surface(Color(0.22, 0.1, 0.075), 0.82, 0.4, 733, 0.08)
	door_mesh.material_override = door_material
	door_body.add_child(door_mesh)

	# Frost strips and bright service lamps make the outer door readable.
	for side in [-1.0, 1.0]:
		var frost := MeshInstance3D.new()
		var frost_mesh := BoxMesh.new()
		frost_mesh.size = Vector3(0.08, 3.1, 0.16)
		frost.mesh = frost_mesh
		frost.position = Vector3(side * 0.25, 1.65, side * 2.45)
		frost.material_override = MATERIALS.make_emissive(Color(0.35, 0.72, 0.88), Color(0.08, 0.35, 0.65), 0.8)
		door_body.add_child(frost)

	# Optional Quaternius door model replaces the plain visual if available.
	var external_door: Node3D = ASSET_LOADER.instantiate_environment_model("door")
	if external_door != null:
		ASSET_LOADER.fit_model_to_size(
			external_door,
			Vector3(5.0, 3.3, 0.5),
			false
		)

		external_door.rotation.y = PI * 0.5
		external_door.position = Vector3.ZERO
		external_door.position = Vector3.ZERO
		door_body.add_child(external_door)

	# Exterior vacuum zone sits beyond the visible viewport/window.
	var exterior_zone := Area3D.new()
	exterior_zone.name = "ExteriorAirlockVacuumZone"
	exterior_zone.collision_layer = 16
	exterior_zone.collision_mask = 2
	exterior_zone.monitoring = true
	exterior_zone.position = Vector3(30.0, 1.1, 0.0)
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(2.0, 3.0, 5.5)
	zone_shape.shape = zone_box
	exterior_zone.add_child(zone_shape)
	exterior_zone.body_entered.connect(_on_airlock_body_entered)
	add_child(exterior_zone)


func _build_hazards() -> void:
	# Two reactor crushers on the blue-lit engine service aisle.
	for point in [Vector3(-20.0, 0.0, -3.8), Vector3(-20.0, 0.0, 4.0)]:
		var crusher := Node3D.new()
		crusher.set_script(CRUSHER_SCRIPT)
		crusher.position = point
		add_child(crusher)
		crushers.append(crusher)

	# Exactly two active hull breaches.
	for point in breach_spawn_positions:
		_spawn_breach_spark_at(point)

	# Drone remains dormant until Phase 2 calls set_emergency_state(true).
	drone = Node3D.new()
	drone.name = "AutomatedSecurityDrone"
	drone.set_script(DRONE_SCRIPT)
	drone.position = Vector3(18.0, 4.2, -5.0)
	add_child(drone)


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


func _spawn_breach_spark_at(point: Vector3) -> void:
	var spark := Area3D.new()
	spark.set_script(SPARK_SCRIPT)
	spark.position = point
	add_child(spark)
	breach_sparks.append(spark)


# ============================================================
# GAMEPLAY API — PRESERVED FOR MAIN.GD
# ============================================================

func spawn_fuel_cells() -> void:
	fuel_cells.clear()
	for position_value in fuel_spawn_positions:
		var cell := FUEL_CELL_SCENE.instantiate() as FuelCell
		cell.position = position_value
		add_child(cell)
		fuel_cells.append(cell)


func find_nearest_breach_spark(player: Node3D, max_distance: float) -> Node3D:
	var nearest: Node3D = null
	var best_distance: float = max_distance
	for node in get_tree().get_nodes_in_group("hull_breaches"):
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var spark: Node3D = node as Node3D
		var distance: float = player.global_position.distance_to(spark.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = spark
	return nearest


func get_active_breach_count() -> int:
	return get_tree().get_nodes_in_group("hull_breaches").size()


func reset_arena() -> void:
	for cell in fuel_cells:
		if is_instance_valid(cell):
			cell.queue_free()
	fuel_cells.clear()

	for spark in breach_sparks:
		if is_instance_valid(spark):
			if spark.is_in_group("hull_breaches"):
				spark.remove_from_group("hull_breaches")
			spark.queue_free()
	breach_sparks.clear()
	_breach_respawn_clock = 0.0

	for point in breach_spawn_positions:
		_spawn_breach_spark_at(point)

	spawn_fuel_cells()
	if pod != null:
		pod.reset_pod()
	set_doors_sealed(false)
	set_emergency_state(false)
	set_terminals_unlocked(false)

	for terminal in terminals:
		if is_instance_valid(terminal):
			terminal.cooldown_remaining = 0.0


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
	if door_material != null:
		if active:
			door_material.albedo_color = Color(0.38, 0.055, 0.035)
			door_material.emission_enabled = true
			door_material.emission = Color(0.95, 0.025, 0.008)
			door_material.emission_energy_multiplier = 1.15
		else:
			door_material.albedo_color = Color(0.22, 0.1, 0.075)
			door_material.emission_enabled = false


func set_terminals_unlocked(active: bool) -> void:
	for terminal in terminals:
		if is_instance_valid(terminal):
			terminal.set_unlocked(active)


func _on_shaft_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		if player.is_alive:
			player.eliminate("gravity shaft fall — personnel were not tethered to the catwalk")


func _on_airlock_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		if player.is_alive:
			player.eliminate("unplanned exterior exposure — blast door safety training not completed")


func _on_void_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var player := body as PlayerController
		if player.is_alive:
			player.eliminate("event horizon exposure — personnel fell below the mining deck")


# ============================================================
# FRAME UPDATES
# ============================================================

func _physics_process(delta: float) -> void:
	# Oxygen station recharge is intentionally modest; it offsets drain but
	# does not instantly refill a player under combat pressure.
	for station in oxygen_station_areas:
		if not is_instance_valid(station):
			continue
		for body in station.get_overlapping_bodies():
			if body is PlayerController:
				var player := body as PlayerController
				if player.is_alive:
					player.oxygen = minf(player.oxygen_max, player.oxygen + oxygen_recharge_per_second * delta)


func _process(delta: float) -> void:
	if emergency_active:
		var pulse: float = 1.0 + 1.2 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.007))
		for light in emergency_lights:
			light.light_energy = pulse
		for rotor in beacon_rotors:
			rotor.rotate_y(delta * 1.8)

	# Repaired breaches return one at a time after the cooldown.
	var active_count: int = get_active_breach_count()
	if active_count < 2:
		_breach_respawn_clock += delta
		if _breach_respawn_clock >= breach_respawn_seconds:
			_breach_respawn_clock = 0.0
			for point in breach_spawn_positions:
				var occupied: bool = false
				for node in get_tree().get_nodes_in_group("hull_breaches"):
					if not is_instance_valid(node) or not (node is Node3D):
						continue
					var active_breach: Node3D = node as Node3D
					var distance_to_spawn: float = active_breach.global_position.distance_to(point)
					if distance_to_spawn < 1.0:
						occupied = true
						break
				if not occupied:
					_spawn_breach_spark_at(point)
					break
	else:
		_breach_respawn_clock = 0.0
