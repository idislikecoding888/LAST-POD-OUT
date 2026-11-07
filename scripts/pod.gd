
extends Node3D
class_name EscapePod

## Central one-seat escape pod and player occupancy volume.

@export_category("Pod Settings")
@export var occupancy_radius: float = 2.35
@export var occupancy_height: float = 3.0

@export_category("Visual Settings")
@export var pod_light_energy: float = 1.5

var sealed: bool = false
var sealed_by: Node3D = null

var door_mesh: MeshInstance3D
var door_collision: CollisionShape3D

var pod_light: OmniLight3D


func _ready() -> void:
	_build_visuals()
	_build_occupancy_area()


# ============================================================
# VISUAL CONSTRUCTION
# ============================================================

func _build_visuals() -> void:

	# --------------------------------------------------------
	# LOWER POD PLATFORM
	# --------------------------------------------------------

	var base := MeshInstance3D.new()
	base.name = "PodBase"

	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 2.1
	base_mesh.bottom_radius = 2.25
	base_mesh.height = 0.42
	base_mesh.radial_segments = 48

	base.mesh = base_mesh
	base.position.y = 0.22

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.12, 0.16, 0.2)
	base_mat.metallic = 0.8
	base_mat.roughness = 0.35

	base.material_override = base_mat

	add_child(base)

	# --------------------------------------------------------
	# POD CABIN
	# --------------------------------------------------------

	var cabin := MeshInstance3D.new()
	cabin.name = "PodCabin"

	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(2.4, 1.75, 2.35)

	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 1.25, 0.0)

	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = Color(0.19, 0.24, 0.29)
	cabin_mat.metallic = 0.68
	cabin_mat.roughness = 0.3

	cabin.material_override = cabin_mat

	add_child(cabin)

	# --------------------------------------------------------
	# FRONT CANOPY
	# --------------------------------------------------------

	var canopy := MeshInstance3D.new()
	canopy.name = "PodCanopy"

	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(1.55, 1.05, 0.08)

	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 1.38, -1.22)

	var glass := StandardMaterial3D.new()

	glass.albedo_color = Color(0.06, 0.19, 0.25, 0.72)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.3

	glass.emission_enabled = true
	glass.emission = Color(0.03, 0.22, 0.31)
	glass.emission_energy_multiplier = 0.8

	canopy.material_override = glass

	add_child(canopy)

	# --------------------------------------------------------
	# ORANGE EXTRACTION RING
	# --------------------------------------------------------

	var ring := MeshInstance3D.new()
	ring.name = "ExtractionRing"

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 2.24
	ring_mesh.bottom_radius = 2.24
	ring_mesh.height = 0.12
	ring_mesh.radial_segments = 64

	ring.mesh = ring_mesh
	ring.position.y = 0.5

	var ring_mat := StandardMaterial3D.new()

	ring_mat.albedo_color = Color(0.92, 0.47, 0.08)

	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.6, 0.16, 0.015)
	ring_mat.emission_energy_multiplier = 0.6

	ring_mat.metallic = 0.55
	ring_mat.roughness = 0.3

	ring.material_override = ring_mat

	add_child(ring)

	# --------------------------------------------------------
	# POD DOOR
	# --------------------------------------------------------

	door_mesh = MeshInstance3D.new()
	door_mesh.name = "PodDoor"

	var door_box := BoxMesh.new()
	door_box.size = Vector3(1.8, 1.65, 0.18)

	door_mesh.mesh = door_box
	door_mesh.position = Vector3(0.0, 1.22, 1.22)

	var door_mat := StandardMaterial3D.new()

	door_mat.albedo_color = Color(0.75, 0.24, 0.055)
	door_mat.metallic = 0.55
	door_mat.roughness = 0.4

	door_mat.emission_enabled = true
	door_mat.emission = Color(0.45, 0.08, 0.01)
	door_mat.emission_energy_multiplier = 0.4

	door_mesh.material_override = door_mat
	door_mesh.visible = false

	add_child(door_mesh)

	# Physical door collision.
	var door_body := StaticBody3D.new()
	door_body.name = "PodDoorCollision"

	door_body.collision_layer = 1
	door_body.collision_mask = 2

	add_child(door_body)

	door_collision = CollisionShape3D.new()

	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(1.8, 1.65, 0.25)

	door_collision.shape = door_shape
	door_collision.position = Vector3(0.0, 1.22, 1.22)
	door_collision.disabled = true

	door_body.add_child(door_collision)

	# --------------------------------------------------------
	# POD SIGN
	# --------------------------------------------------------

	var pod_sign := Label3D.new()

	pod_sign.name = "PodInstructionSign"
	pod_sign.text = "ESCAPE POD // ONE SEAT\n[X] DEPOSIT FUEL CELL"

	pod_sign.font_size = 34
	pod_sign.pixel_size = 0.004

	pod_sign.position = Vector3(0.0, 2.35, -1.4)

	pod_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pod_sign.modulate = Color(1.0, 0.75, 0.38)

	add_child(pod_sign)

	# --------------------------------------------------------
	# EXTRACTION LIGHT
	# --------------------------------------------------------

	pod_light = OmniLight3D.new()

	pod_light.name = "PodExtractionLight"
	pod_light.position = Vector3(0.0, 2.0, 0.0)

	pod_light.light_color = Color(1.0, 0.38, 0.08)
	pod_light.light_energy = pod_light_energy
	pod_light.omni_range = 7.0

	pod_light.shadow_enabled = false

	add_child(pod_light)


# ============================================================
# PLAYER OCCUPANCY AREA
# ============================================================

func _build_occupancy_area() -> void:

	var area := Area3D.new()

	area.name = "OccupancyArea"

	area.collision_layer = 4
	area.collision_mask = 2
	area.monitoring = true

	area.position.y = occupancy_height * 0.5

	var shape_node := CollisionShape3D.new()

	var shape := CylinderShape3D.new()

	shape.radius = occupancy_radius
	shape.height = occupancy_height

	shape_node.shape = shape

	area.add_child(shape_node)

	add_child(area)


# ============================================================
# CHECK POD OCCUPANCY
# ============================================================

func contains_player(player: Node3D) -> bool:

	if player == null or not is_instance_valid(player):
		return false

	var offset: Vector3 = (
		player.global_position - global_position
	)

	var horizontal_distance: float = Vector2(
		offset.x,
		offset.z
	).length()

	return (
		horizontal_distance <= occupancy_radius
		and offset.y > -0.2
		and offset.y < occupancy_height + 0.5
	)


# ============================================================
# SEAL POD
# ============================================================

func seal(by_player: Node3D) -> void:

	sealed = true
	sealed_by = by_player

	if door_mesh != null:
		door_mesh.visible = true

	if door_collision != null:
		door_collision.disabled = false

	if pod_light != null:
		pod_light.light_color = Color(0.1, 1.0, 0.35)
		pod_light.light_energy = 2.5


# ============================================================
# RESET POD FOR REMATCH
# ============================================================

func reset_pod() -> void:

	sealed = false
	sealed_by = null

	if door_mesh != null:
		door_mesh.visible = false

	if door_collision != null:
		door_collision.disabled = true

	if pod_light != null:
		pod_light.light_color = Color(1.0, 0.38, 0.08)
		pod_light.light_energy = pod_light_energy
