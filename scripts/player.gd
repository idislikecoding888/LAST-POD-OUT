extends CharacterBody3D
class_name PlayerController
## Composition-based character: all device reads are delegated to an InputSource child.

@export_category("Movement")
@export var move_speed: float = 5.2
@export var acceleration: float = 23.0
@export var friction: float = 18.0
@export var carrying_speed_multiplier: float = 0.70
@export var pact_speed_multiplier: float = 1.2
@export var gravity_strength: float = 9.8
@export_category("Combat")
@export var shove_range: float = 2.55
@export var shove_force: float = 9.5
@export var pact_breach_knockback_multiplier: float = 2.0
@export var parry_window_seconds: float = 0.34
@export var parry_reflect_force: float = 12.5
@export var dodge_impulse: float = 8.5
@export var dodge_cooldown_seconds: float = 1.1
@export var shove_oxygen_damage: float = 14.0
@export_category("Oxygen / Pact")
@export var oxygen_max: float = 100.0
@export var oxygen_drain_per_second: float = 0.48
@export var pact_oxygen_efficiency: float = 0.8
@export var pact_hold_seconds: float = 1.5
@export var pact_range: float = 2.25
@export_category("Feedback")
@export var low_oxygen_threshold: float = 25.0
@export var low_oxygen_rumble_interval: float = 1.2
@export_category("V2 Industrial Worker")
@export var security_stun_default: float = 1.25
@export var crusher_stun_default: float = 0.65

var rig_visual: IndustrialRigVisual
var stun_remaining: float = 0.0
var manager
var input_source
var slot_index: int = 0
var input_kind: String = "keyboard"
var controller_device_id: int = -1
var display_name: String = "P1"
var role_name: String = "Hull Welder"
var role_color: Color = Color(0.12, 0.83, 0.92)
var is_alive: bool = true
var oxygen: float = 100.0
var carried_cell: FuelCell = null
var parry_timer: float = 0.0
var dodge_cooldown: float = 0.0
var pact_partner: PlayerController = null
var pact_hold_progress: float = 0.0
var current_aim: Vector3 = Vector3(0.0, 0.0, -1.0)
var _low_oxygen_clock: float = 0.0
var nameplate: Label3D

@onready var body_mesh: MeshInstance3D = $VisualRoot/Body
@onready var flashlight: SpotLight3D = $VisualRoot/Flashlight
@onready var oxygen_fill: MeshInstance3D = $VisualRoot/OxygenFill

const ROLE_NAMES := ["Hull Welder", "Gravity Tech", "Med-Bay Chemist", "Security Enforcer"]
const ROLE_COLORS := [Color(0.08, 0.78, 0.91), Color(1.0, 0.61, 0.12), Color(0.87, 0.12, 0.18), Color(0.13, 0.78, 0.39)]

func _ready() -> void:
	# Replace the primitive capsule presentation with a procedural worker rig.
	body_mesh.visible = false
	flashlight.visible = false

	$VisualRoot/OxygenBack.visible = false
	$VisualRoot/OxygenFill.visible = false

	rig_visual = IndustrialRigVisual.new()
	rig_visual.name = "IndustrialWorkerRig"
	$VisualRoot.add_child(rig_visual)

	rig_visual.configure(role_color)
	add_to_group("players")
	oxygen = oxygen_max
	nameplate = Label3D.new()
	nameplate.name = "CrewNameplate"
	nameplate.font_size = 38
	nameplate.pixel_size = 0.0038
	nameplate.position = Vector3(0.0, 1.4, 0.0)
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	$VisualRoot.add_child(nameplate)
	if body_mesh != null:
		_apply_role_look()
	var oxygen_back_material := StandardMaterial3D.new()
	oxygen_back_material.albedo_color = Color(0.018, 0.03, 0.05)
	oxygen_back_material.metallic = 0.2
	$VisualRoot/OxygenBack.material_override = oxygen_back_material
	if oxygen_fill != null:
		var fill_mat := StandardMaterial3D.new()
		fill_mat.albedo_color = Color(0.12, 0.88, 0.66)
		fill_mat.emission_enabled = true
		fill_mat.emission = Color(0.04, 0.42, 0.26)
		fill_mat.emission_energy_multiplier = 0.8
		oxygen_fill.material_override = fill_mat

func setup(game_manager, slot: int, kind: String, device_id: int = -1) -> void:
	manager = game_manager
	slot_index = clampi(slot, 0, 3)
	input_kind = kind
	controller_device_id = device_id
	display_name = "P%d" % (slot_index + 1)
	role_name = ROLE_NAMES[slot_index]
	role_color = ROLE_COLORS[slot_index]
	if nameplate != null:
		nameplate.text = "%s // %s" % [display_name, role_name.to_upper()]
		nameplate.modulate = role_color.lightened(0.25)
	_apply_role_look()
	if kind == "keyboard":
		input_source = KeyboardInputSource.new()
	elif kind == "gamepad":
		var gamepad := GamepadInputSource.new()
		gamepad.device_id = device_id
		input_source = gamepad
	else:
		input_source = BotInputSource.new()
		input_source.name = "BotInputSource"
	add_child(input_source)

func _apply_role_look() -> void:
	if body_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = role_color
	material.metallic = 0.32
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = role_color * 0.12
	material.emission_energy_multiplier = 0.45
	body_mesh.material_override = material
	if flashlight != null:
		flashlight.light_color = role_color.lightened(0.42)
	if rig_visual != null:
		rig_visual.configure(role_color)

func reset_for_round(spawn_position: Vector3) -> void:
	is_alive = true
	visible = true
	collision_layer = 2
	collision_mask = 11
	set_physics_process(true)
	set_process(true)
	global_position = spawn_position
	velocity = Vector3.ZERO
	oxygen = oxygen_max
	parry_timer = 0.0
	dodge_cooldown = 0.0
	pact_partner = null
	pact_hold_progress = 0.0
	_low_oxygen_clock = 0.0
	stun_remaining = 0.0
	if carried_cell != null and is_instance_valid(carried_cell):
		carried_cell.drop(global_position + Vector3.UP * 0.6)
	carried_cell = null

func get_aim_direction() -> Vector3:
	return current_aim


func _build_void_kill_plane() -> void:

	var kill_zone := Area3D.new()

	kill_zone.name = "UniversalVoidKillPlane"

	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 2
	kill_zone.monitoring = true

	kill_zone.position = Vector3(0.0, -8.0, 0.0)

	var shape_node := CollisionShape3D.new()

	var shape := BoxShape3D.new()
	shape.size = Vector3(100.0, 2.0, 100.0)

	shape_node.shape = shape

	kill_zone.add_child(shape_node)

	kill_zone.body_entered.connect(
		_on_void_body_entered
	)

	add_child(kill_zone)


func _on_void_body_entered(body: Node3D) -> void:

	if body is PlayerController:

		var player := body as PlayerController

		if player.is_alive:

			player.eliminate(
				"event horizon exposure — personnel fell below the mining deck"
			)



func _physics_process(delta: float) -> void:

	if not is_alive:
		return

	# --------------------------------------------------------
	# VOID / FALL DEATH DETECTION
	# --------------------------------------------------------

	if global_position.y < -6.0:
		eliminate(
			"reactor shaft fall — employee safety tether not engaged"
		)
		return

	# --------------------------------------------------------
	# STUN HANDLING
	# --------------------------------------------------------

	if stun_remaining > 0.0:

		stun_remaining = maxf(
			0.0,
			stun_remaining - delta
		)

		velocity.x = move_toward(
			velocity.x,
			0.0,
			friction * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			friction * delta
		)

		velocity.y -= gravity_strength * delta

		move_and_slide()

		_update_oxygen(delta)
		_update_oxygen_bar()

		return

	# --------------------------------------------------------
	# COMBAT TIMERS
	# --------------------------------------------------------

	if parry_timer > 0.0:
		parry_timer = maxf(0.0, parry_timer - delta)

	if dodge_cooldown > 0.0:
		dodge_cooldown = maxf(0.0, dodge_cooldown - delta)

	# --------------------------------------------------------
	# AIM
	# --------------------------------------------------------

	var camera: Camera3D = get_viewport().get_camera_3d()

	var aim_value: Vector3 = Vector3.ZERO

	if input_source != null:
		aim_value = input_source.aim_vector(self, camera)

	if aim_value.length_squared() > 0.02:

		current_aim = Vector3(
			aim_value.x,
			0.0,
			aim_value.z
		).normalized()

		var yaw: float = atan2(
			-current_aim.x,
			-current_aim.z
		)

		$VisualRoot.rotation.y = yaw

	# --------------------------------------------------------
	# PARRY
	# --------------------------------------------------------

	if (
		input_source != null
		and input_source.action_just_pressed(&"parry")
	):

		parry_timer = parry_window_seconds
		_rumble(0.12, 0.24, 0.08)

	# --------------------------------------------------------
	# DODGE
	# --------------------------------------------------------

	if (
		input_source != null
		and input_source.action_just_pressed(&"dodge")
		and dodge_cooldown <= 0.0
	):

		var dodge_direction: Vector3 = current_aim

		var movement_for_dash: Vector2 = input_source.move_vector()

		if movement_for_dash.length_squared() > 0.05:

			dodge_direction = Vector3(
				movement_for_dash.x,
				0.0,
				movement_for_dash.y
			).normalized()

		velocity += dodge_direction * dodge_impulse

		dodge_cooldown = dodge_cooldown_seconds

		_rumble(0.16, 0.32, 0.1)

	# --------------------------------------------------------
	# SHOVE
	# --------------------------------------------------------

	if (
		input_source != null
		and input_source.action_just_pressed(&"shove")
	):

		_perform_shove()

	# --------------------------------------------------------
	# INTERACTION / WELDING
	# --------------------------------------------------------

	var interact_just_pressed: bool = false

	if input_source != null:

		interact_just_pressed = input_source.action_just_pressed(
			&"interact"
		)

	var welding_active: bool = false

	if manager != null:

		welding_active = manager.update_player_welding(
			self,
			delta
		)

	if interact_just_pressed and not welding_active:

		if manager != null:
			manager.handle_player_interact(self)

	# --------------------------------------------------------
	# DEAD MAN'S PACT
	# --------------------------------------------------------

	_update_pact_hold(delta)

	# --------------------------------------------------------
	# MOVEMENT
	# --------------------------------------------------------

	var move_input: Vector2 = Vector2.ZERO

	if input_source != null:
		move_input = input_source.move_vector()

	var move_direction: Vector3 = Vector3(
		move_input.x,
		0.0,
		move_input.y
	)

	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()

	var speed: float = move_speed

	if carried_cell != null:
		speed *= carrying_speed_multiplier

	if pact_partner != null:
		speed *= pact_speed_multiplier

	var target_velocity: Vector3 = move_direction * speed

	var move_rate: float = (
		acceleration
		if move_direction.length_squared() > 0.001
		else friction
	)

	# Zero traction during gravity inversion.
	if manager != null and manager.gravity_flip_active:
		move_rate *= 0.18

	velocity.x = move_toward(
		velocity.x,
		target_velocity.x,
		move_rate * delta
	)

	velocity.z = move_toward(
		velocity.z,
		target_velocity.z,
		move_rate * delta
	)

	# --------------------------------------------------------
	# GRAVITY
	# --------------------------------------------------------

	var gravity_flipped: bool = (
		manager != null
		and bool(manager.get("gravity_flip_active"))
	)

	if gravity_flipped:

		var inversion_force: float = (
			manager.gravity_inverter_strength
			if manager != null
			else 5.5
		)

		velocity.y = minf(
			velocity.y + inversion_force * delta,
			4.0
		)

	elif is_on_floor():

		velocity.y = -0.12

	else:

		velocity.y -= gravity_strength * delta

	# --------------------------------------------------------
	# EXTERNAL ENVIRONMENT FORCES
	# --------------------------------------------------------

	if manager != null:

		var external_force: Vector3 = (
			manager.get_player_environment_force(self)
		)

		velocity += external_force * delta

	# --------------------------------------------------------
	# APPLY PHYSICS
	# --------------------------------------------------------

	move_and_slide()

	_update_oxygen(delta)
	_update_oxygen_bar()


func _process(delta: float) -> void:
	if carried_cell != null and is_instance_valid(carried_cell):
		carried_cell.global_position = (
			global_position
			+ current_aim * 0.92
			+ Vector3.UP * 0.72
		)

	if rig_visual != null:
		rig_visual.animate_rig(
			velocity,
			delta,
			oxygen / maxf(oxygen_max, 0.001),
			carried_cell != null
		)

func apply_stun(seconds: float = -1.0) -> void:
	if not is_alive:
		return

	var duration := seconds

	if duration < 0.0:
		duration = security_stun_default

	stun_remaining = maxf(stun_remaining, duration)
	velocity.x *= 0.15
	velocity.z *= 0.15

	_rumble(0.55, 0.75, 0.22)

	if has_node("/root/SoundManager"):
		SoundManager.play_tase()

func _update_oxygen(delta: float) -> void:
	var drain_multiplier := 1.0
	if manager != null and manager.phase >= 2:
		drain_multiplier *= 2.0
	if manager != null and manager.airlock_timer > 0.0:
		drain_multiplier *= 4.0
	if pact_partner != null:
		drain_multiplier *= pact_oxygen_efficiency

	# Every unrepaired hull breach accelerates life-support depletion.
	if manager != null:
		drain_multiplier += float(manager.get_active_breach_count()) * 0.20

	oxygen = maxf(0.0, oxygen - oxygen_drain_per_second * drain_multiplier * delta)
	if oxygen <= 0.0:
		eliminate("life-support insolvency — oxygen allowance exhausted")
		return
	if oxygen < low_oxygen_threshold:
		_low_oxygen_clock += delta
		if _low_oxygen_clock >= low_oxygen_rumble_interval:
			_low_oxygen_clock = 0.0
			_rumble(0.2, 0.38, 0.16)
	else:
		_low_oxygen_clock = 0.0
	# Heartbeat and low-pass muffling.
	if has_node("/root/SoundManager"):
		SoundManager.set_critical_player(
			get_instance_id(),
			oxygen < low_oxygen_threshold
		)

func _update_oxygen_bar() -> void:
	if oxygen_fill == null:
		return
	var fraction := clampf(oxygen / maxf(oxygen_max, 0.001), 0.0, 1.0)
	oxygen_fill.scale.x = maxf(0.02, fraction)
	oxygen_fill.position.x = -0.32 * (1.0 - fraction)
	var material := oxygen_fill.material_override as StandardMaterial3D
	if material != null:
		if fraction < 0.25:
			material.albedo_color = Color(1.0, 0.12, 0.1)
			material.emission = Color(0.7, 0.03, 0.02)
		else:
			material.albedo_color = Color(0.12, 0.88, 0.66)
			material.emission = Color(0.04, 0.42, 0.26)

func _perform_shove() -> void:
	# The attacker keeps their own cargo; a successful target hit drops the target's cell.
	if manager != null:
		manager.try_shove(self, current_aim, shove_range, shove_force)

func receive_shove(attacker: PlayerController, direction: Vector3, force: float) -> void:
	if not is_alive:
		return
	if parry_timer > 0.0:
		if attacker != null and is_instance_valid(attacker):
			attacker.receive_knockback(-direction * parry_reflect_force)
			attacker.oxygen = maxf(0.0, attacker.oxygen - shove_oxygen_damage * 0.5)
		_rumble(0.35, 0.65, 0.18)
		if manager != null:
			manager.notify_corporate("COUNTER-PARRY REGISTERED. LIABILITY REDIRECTED.", 1.8)
			SoundManager.play_parry()
			manager.trigger_impact_feedback(0.55)
			if manager.phase >= 3 and attacker != null and is_instance_valid(attacker):
				attacker.eliminate("fatal counter-parry — reflected force under Clause 99")
		return
	if carried_cell != null:
		drop_carried_cell(direction * 0.25)
	receive_knockback(direction * force)
	oxygen = maxf(0.0, oxygen - shove_oxygen_damage)
	_rumble(0.28, 0.72, 0.22)
	if manager != null:
		manager.trigger_impact_feedback(0.8)
		if manager.phase >= 3:
			eliminate("fatal crew-on-crew impact — Clause 99 arbitration")
		elif oxygen <= 0.0:
			eliminate("blunt-force life-support failure")
		else:
			manager.notify_corporate("WORKPLACE INCIDENT LOGGED. HR WILL NOT FOLLOW UP.", 1.4)

func receive_knockback(impulse: Vector3) -> void:
	velocity += impulse

func drop_carried_cell(extra_impulse: Vector3 = Vector3.ZERO) -> void:
	if carried_cell == null or not is_instance_valid(carried_cell):
		carried_cell = null
		return
	var cell := carried_cell
	carried_cell = null
	cell.drop(global_position + current_aim * 1.05 + Vector3.UP * 0.35, extra_impulse)

func pick_up_cell(cell: FuelCell) -> void:
	if cell == null or carried_cell != null:
		return
	carried_cell = cell
	cell.set_carried(self)
	_rumble(0.08, 0.14, 0.08)

func eliminate(cause: String) -> void:
	if not is_alive:
		return
	is_alive = false
	if carried_cell != null:
		drop_carried_cell()
	if manager != null:
		manager.break_pact(self, false)
		manager.player_eliminated(self, cause)
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	set_process(false)

	if has_node("/root/SoundManager"):
		SoundManager.set_critical_player(get_instance_id(), false)

func _update_pact_hold(delta: float) -> void:
	if input_source == null or manager == null or pact_partner != null:
		pact_hold_progress = 0.0
		return
	if input_source.action_pressed(&"pact"):
		var ally = manager.find_nearest_ally(self, pact_range)
		if ally != null:
			pact_hold_progress += delta
			if pact_hold_progress >= pact_hold_seconds:
				manager.form_pact(self, ally)
				pact_hold_progress = 0.0
		else:
			pact_hold_progress = 0.0
	else:
		pact_hold_progress = 0.0

func _rumble(weak: float, strong: float, duration: float) -> void:
	if controller_device_id >= 0 and Input.get_connected_joypads().has(controller_device_id):
		Input.start_joy_vibration(controller_device_id, weak, strong, duration)
