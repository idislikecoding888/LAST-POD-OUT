
extends Area3D
class_name SabotageTerminal

## Phase 2 sabotage terminal.
## Supports airlock venting and gravity inversion.

const MATERIALS = preload("res://scripts/industrial_materials.gd")


@export_enum("airlock", "gravity")
var terminal_type: String = "airlock"

@export var cooldown_seconds: float = 25.0
@export var unlocked_emission_energy: float = 1.8


var cooldown_remaining: float = 0.0
var unlocked: bool = false

var screen_material: StandardMaterial3D
var interaction_prompt: Label3D

var title_text: String = "AIRLOCK VENTING"


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:

	add_to_group("terminals")

	monitoring = true
	collision_layer = 4
	collision_mask = 2

	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()

	sphere.radius = 1.65
	shape_node.shape = sphere

	add_child(shape_node)

	_build_visuals()
	set_unlocked(false)


func configure(kind: String, title: String) -> void:

	terminal_type = kind
	title_text = title


# ============================================================
# VISUAL CONSTRUCTION
# ============================================================

func _build_visuals() -> void:

	# --------------------------------------------------------
	# METAL PEDESTAL
	# --------------------------------------------------------

	var pedestal := MeshInstance3D.new()

	var pedestal_mesh := BoxMesh.new()
	pedestal_mesh.size = Vector3(0.85, 1.15, 0.72)

	pedestal.mesh = pedestal_mesh

	var pedestal_mat := StandardMaterial3D.new()

	pedestal_mat.albedo_color = Color(
		0.055,
		0.075,
		0.105
	)

	pedestal_mat.metallic = 0.72
	pedestal_mat.roughness = 0.38

	pedestal.material_override = pedestal_mat
	pedestal.position = Vector3(0.0, 0.55, 0.0)

	add_child(pedestal)

	# --------------------------------------------------------
	# CRT SCREEN
	# --------------------------------------------------------

	var screen := MeshInstance3D.new()

	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.68, 0.46, 0.08)

	screen.mesh = screen_mesh
	screen.position = Vector3(0.0, 0.83, -0.39)

	screen_material = MATERIALS.make_surface(
		Color(0.025, 0.075, 0.065),
		0.18,
		0.28,
		221,
		0.045
	)

	screen_material.emission_enabled = true
	screen_material.emission = Color(0.8, 0.02, 0.025)
	screen_material.emission_energy_multiplier = 0.45

	screen.material_override = screen_material

	add_child(screen)

	# --------------------------------------------------------
	# TOP CAP
	# --------------------------------------------------------

	var cap := MeshInstance3D.new()

	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.46
	cap_mesh.bottom_radius = 0.46
	cap_mesh.height = 0.12

	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 1.16, 0.0)

	var cap_mat := StandardMaterial3D.new()

	cap_mat.albedo_color = Color(0.11, 0.16, 0.2)
	cap_mat.metallic = 0.85
	cap_mat.roughness = 0.35

	cap.material_override = cap_mat

	add_child(cap)

	# --------------------------------------------------------
	# FLOATING TERMINAL TITLE
	# --------------------------------------------------------

	var label := Label3D.new()

	label.text = title_text
	label.font_size = 30
	label.pixel_size = 0.0045

	label.position = Vector3(0.0, 1.65, 0.0)

	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.9, 0.86, 0.72)

	add_child(label)

	# --------------------------------------------------------
	# INTERACTION PROMPT
	# --------------------------------------------------------

	interaction_prompt = Label3D.new()

	interaction_prompt.text = "[X] " + title_text
	interaction_prompt.font_size = 26
	interaction_prompt.pixel_size = 0.004

	interaction_prompt.position = Vector3(0.0, 2.0, 0.0)

	interaction_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_prompt.modulate = Color(0.4, 1.0, 0.8)

	add_child(interaction_prompt)


# ============================================================
# TERMINAL STATE
# ============================================================

func set_unlocked(value: bool) -> void:

	unlocked = value

	if screen_material == null:
		return

	if unlocked:

		screen_material.albedo_color = Color(
			0.035,
			0.22,
			0.19
		)

		screen_material.emission = Color(
			0.08,
			0.95,
			0.58
		)

		screen_material.emission_energy_multiplier = (
			unlocked_emission_energy
		)

	else:

		screen_material.albedo_color = Color(
			0.34,
			0.035,
			0.04
		)

		screen_material.emission = Color(
			0.8,
			0.02,
			0.025
		)

		screen_material.emission_energy_multiplier = 0.35


# ============================================================
# ACTIVATION
# ============================================================

func activate(game_manager: Variant) -> void:

	if game_manager == null:
		return

	if game_manager.phase < 2:

		game_manager.notify_corporate(
			"ACCESS DENIED — SABOTAGE PRIVILEGES REQUIRE PHASE 2.",
			2.6
		)

		return

	if not unlocked:

		game_manager.notify_corporate(
			"TERMINAL OFFLINE.",
			1.8
		)

		return

	if cooldown_remaining > 0.0:

		game_manager.notify_corporate(
			"TERMINAL COOLDOWN: %.0f SEC."
			% ceil(cooldown_remaining),
			1.5
		)

		return

	cooldown_remaining = cooldown_seconds

	if terminal_type == "airlock":

		game_manager.activate_airlock_venting()

	else:

		game_manager.activate_gravity_inverter()


# ============================================================
# UPDATE
# ============================================================

func _process(delta: float) -> void:

	cooldown_remaining = maxf(
		0.0,
		cooldown_remaining - delta
	)

	# CRT screen pulse.
	if (
		screen_material != null
		and unlocked
		and cooldown_remaining <= 0.0
	):

		var pulse: float = (
			0.72
			+ 0.28 * sin(float(Time.get_ticks_msec()) * 0.004)
		)

		screen_material.emission_energy_multiplier = (
			unlocked_emission_energy * pulse
		)

	# Update floating instructions.
	if interaction_prompt == null:
		return

	if not unlocked:

		interaction_prompt.text = "LOCKED // PHASE 2"

	elif cooldown_remaining > 0.0:

		interaction_prompt.text = (
			"COOLDOWN // %.0f SEC"
			% ceil(cooldown_remaining)
		)

	else:

		interaction_prompt.text = "[X] " + title_text
