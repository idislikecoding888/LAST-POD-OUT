
extends RigidBody3D
class_name FuelCell

## Heavy industrial fuel cell.
## Uses physics when dropped and follows its carrier when picked up.

@export_category("Fuel Cell Physics")
@export var pickup_height: float = 0.75
@export var carry_forward_distance: float = 1.0
@export var drop_impulse: float = 2.8

@export_category("Visual Effects")
@export var beacon_energy: float = 2.8
@export var beacon_range: float = 6.0

var carrier: Node3D = null
var home_position: Vector3 = Vector3.ZERO

var beacon: OmniLight3D
var pickup_prompt: Label3D

var animation_clock: float = 0.0


func _ready() -> void:
	add_to_group("fuel_cells")

	home_position = global_position

	contact_monitor = true
	max_contacts_reported = 4

	_build_beacon()
	_build_prompt()


func _build_beacon() -> void:
	beacon = OmniLight3D.new()
	beacon.name = "AmberFuelBeacon"

	beacon.position = Vector3(0.0, 0.55, 0.0)
	beacon.light_color = Color(1.0, 0.42, 0.035)
	beacon.light_energy = beacon_energy
	beacon.omni_range = beacon_range
	beacon.shadow_enabled = false

	add_child(beacon)


func _build_prompt() -> void:
	pickup_prompt = Label3D.new()

	pickup_prompt.name = "FuelCellPrompt"
	pickup_prompt.text = "[X] HAUL FUEL CELL"

	pickup_prompt.font_size = 30
	pickup_prompt.pixel_size = 0.004

	pickup_prompt.position = Vector3(0.0, 1.15, 0.0)

	pickup_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pickup_prompt.modulate = Color(1.0, 0.74, 0.35)

	add_child(pickup_prompt)


func _physics_process(delta: float) -> void:
	animation_clock += delta

	# Follow the player while carried.
	if carrier != null and is_instance_valid(carrier):

		var direction: Vector3 = Vector3.FORWARD

		if carrier.has_method("get_aim_direction"):
			var aim_result: Variant = carrier.call("get_aim_direction")

			if aim_result is Vector3:
				direction = aim_result

		global_position = (
			carrier.global_position
			+ Vector3(direction.x, 0.0, direction.z)
			* carry_forward_distance
			+ Vector3.UP * pickup_height
		)

		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

		if pickup_prompt != null:
			pickup_prompt.visible = false

		if beacon != null:
			beacon.light_energy = 0.5

		return

	# Carrier was deleted or eliminated.
	if carrier != null:
		carrier = null
		freeze = false
		collision_layer = 8
		collision_mask = 3

	# Idle fuel cell effects.
	if pickup_prompt != null:
		pickup_prompt.visible = true

	if beacon != null:
		beacon.light_energy = (
			beacon_energy
			+ sin(animation_clock * 3.5) * 0.65
		)


func set_carried(by_player: Node3D) -> void:
	if by_player == null:
		return

	carrier = by_player

	freeze = true
	sleeping = false

	collision_layer = 0
	collision_mask = 0

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	if pickup_prompt != null:
		pickup_prompt.visible = false


func drop(
	drop_position: Vector3,
	impulse_direction: Vector3 = Vector3.ZERO
) -> void:

	carrier = null

	global_position = drop_position

	freeze = false
	sleeping = false

	# Restore Fuel Cell collision layer.
	collision_layer = 8
	collision_mask = 3

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	if impulse_direction.length_squared() > 0.001:
		apply_central_impulse(
			impulse_direction.normalized() * drop_impulse
		)

	if pickup_prompt != null:
		pickup_prompt.visible = true
		pickup_prompt.text = "[X] HAUL FUEL CELL"

	if beacon != null:
		beacon.light_energy = beacon_energy


func reset_cell() -> void:
	carrier = null

	global_position = home_position

	freeze = false
	sleeping = false

	collision_layer = 8
	collision_mask = 3

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	if pickup_prompt != null:
		pickup_prompt.visible = true

	if beacon != null:
		beacon.light_energy = beacon_energy
