
extends Area3D
class_name HullBreachSpark

@export var oxygen_drain_bonus: float = 0.20
@export var repair_seconds: float = 2.0
@export var spark_frequency: float = 9.0

var repaired: bool = false
var current_welder: int = -1
var weld_progress: float = 0.0

var beacon: OmniLight3D
var prompt: Label3D
var core: MeshInstance3D
var clock: float = 0.0


func _ready() -> void:
	add_to_group("hull_breaches")

	collision_layer = 16
	collision_mask = 2
	monitoring = true

	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	shape_node.shape = shape
	add_child(shape_node)

	core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.25
	core_mesh.height = 0.5
	core.mesh = core_mesh
	core.material_override = IndustrialMaterials.make_emissive(
		Color(1.0, 0.14, 0.035),
		Color(1.0, 0.035, 0.005),
		3.5
	)
	core.position.y = 0.35
	add_child(core)

	beacon = OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.08, 0.015)
	beacon.light_energy = 2.0
	beacon.omni_range = 5.0
	beacon.position.y = 0.6
	beacon.shadow_enabled = false
	add_child(beacon)

	prompt = Label3D.new()
	prompt.text = "[HOLD X] WELD HULL BREACH"
	prompt.font_size = 27
	prompt.pixel_size = 0.004
	prompt.position.y = 1.25
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.modulate = Color(1.0, 0.62, 0.35)
	add_child(prompt)


func _process(delta: float) -> void:
	if repaired:
		return

	clock += delta

	var pulse := 1.0 + 0.65 * sin(clock * spark_frequency)
	beacon.light_energy = pulse * 2.0
	core.rotation.y += delta * 2.0
	prompt.text = "[HOLD X] WELD HULL BREACH  %d%%" % int(
		weld_progress * 100.0
	)


func set_weld_progress(value: float) -> void:
	weld_progress = clampf(value, 0.0, 1.0)


func repair() -> void:
	if repaired:
		return

	repaired = true
	remove_from_group("hull_breaches")

	if beacon != null:
		beacon.light_energy = 0.0

	prompt.text = "HULL SEALED // PRESSURE NOMINAL"

	if has_node("/root/SoundManager"):
		SoundManager.play_parry()

	# Delay removal briefly so the player can read the completion label.
	await get_tree().create_timer(0.8).timeout

	if is_instance_valid(self):
		queue_free()
