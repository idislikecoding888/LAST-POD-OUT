
extends Node3D
class_name GameManager

## Owns lobby, phases, multiplayer, combat, welding and incident reporting.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

const PHASE_LOBBY: int = 0
const PHASE_1: int = 1
const PHASE_2: int = 2
const PHASE_3: int = 3
const PHASE_REPORT: int = 4


# ============================================================
# EXPORTED SETTINGS
# ============================================================

@export_category("Round Timers")
@export var reactor_duration_seconds: float = 180.0
@export var launch_countdown_seconds: float = 30.0
@export var overtime_window_seconds: float = 5.0
@export var overtime_repeat_if_jammed: bool = true

@export_category("Sabotage Effects")
@export var airlock_vent_duration: float = 8.0
@export var airlock_suction_force: float = 10.5
@export var airlock_suction_range: float = 22.0
@export var gravity_inverter_duration: float = 6.0
@export var gravity_inverter_strength: float = 5.5

@export_category("Impact Feedback")
@export var hitstop_time_scale: float = 0.12
@export var impact_hitstop_seconds: float = 0.055
@export var camera_shake_strength: float = 0.38

@export_category("Hull Breach Repair")
@export var hull_weld_duration: float = 2.0
@export var hull_weld_range: float = 1.9


# ============================================================
# GAME STATE
# ============================================================

var phase: int = PHASE_LOBBY

var players: Array = []
var eliminated: Array[Dictionary] = []

var reactor_timer: float = 180.0
var launch_timer: float = 30.0
var overtime_timer: float = 0.0

var overtime_active: bool = false
var fuel_delivered: int = 0

var airlock_timer: float = 0.0
var gravity_timer: float = 0.0
var gravity_flip_active: bool = false

var _player_slots_used: Array[int] = []
var _joined_gamepad_ids: Array[int] = []

var _keyboard_joined: bool = false
var _test_bot_enabled: bool = false

var _saved_configs: Array[Dictionary] = []
var _restart_guard: bool = false

var _weld_progress: Dictionary = {}

var _tether_mesh: ImmediateMesh
var _tether_instance: MeshInstance3D
var _tether_material: StandardMaterial3D


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var arena: GameArena = $Arena
@onready var game_camera: IsometricCamera = $IsometricCamera
@onready var hud: GameHUD = $HUD


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0

	game_camera.configure(self)

	# Explicitly activate the 3D camera.
	game_camera.make_current()
	game_camera.current = true

	hud.configure(self)

	_build_pact_tether()
	_show_lobby()

	notify_corporate(
		"WELCOME TO TARTARUS-9. AETHER-VANGUARD VALUES YOUR CONTINUED PRODUCTIVITY.",
		4.0
	)


# ============================================================
# LOBBY INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:

	if phase == PHASE_LOBBY:

		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:

				KEY_SPACE:
					join_keyboard_player()

				KEY_TAB, KEY_Y:
					toggle_test_bot()

				KEY_ENTER, KEY_KP_ENTER:
					try_start_match()

		if event is InputEventJoypadButton and event.pressed:

			if event.button_index == JOY_BUTTON_A:
				join_gamepad_player(event.device)

			elif event.button_index == JOY_BUTTON_Y:
				toggle_test_bot()

			elif event.button_index == JOY_BUTTON_START:
				try_start_match()

	elif phase == PHASE_REPORT:

		if event is InputEventKey and event.pressed and not event.echo:

			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				restart_round()

		elif event is InputEventJoypadButton and event.pressed:

			if event.button_index == JOY_BUTTON_A:
				restart_round()


# ============================================================
# DEAD MAN'S PACT TETHER
# ============================================================

func _build_pact_tether() -> void:

	_tether_mesh = ImmediateMesh.new()

	_tether_instance = MeshInstance3D.new()
	_tether_instance.name = "DeadMansPactTethers"
	_tether_instance.mesh = _tether_mesh

	_tether_material = StandardMaterial3D.new()
	_tether_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tether_material.albedo_color = Color(0.15, 0.92, 1.0)

	_tether_material.emission_enabled = true
	_tether_material.emission = Color(0.05, 0.7, 1.0)
	_tether_material.emission_energy_multiplier = 2.4

	_tether_instance.material_override = _tether_material

	add_child(_tether_instance)


func _update_pact_tether() -> void:

	if _tether_mesh == null:
		return

	_tether_mesh.clear_surfaces()

	var has_tether: bool = false

	for player in players:

		if not is_instance_valid(player):
			continue

		if not player.is_alive or player.pact_partner == null:
			continue

		if not is_instance_valid(player.pact_partner):
			continue

		if player.slot_index > player.pact_partner.slot_index:
			continue

		if not has_tether:
			_tether_mesh.surface_begin(
				Mesh.PRIMITIVE_LINES,
				_tether_material
			)
			has_tether = true

		_tether_mesh.surface_add_vertex(
			to_local(player.global_position + Vector3.UP * 0.75)
		)

		_tether_mesh.surface_add_vertex(
			to_local(
				player.pact_partner.global_position + Vector3.UP * 0.75
			)
		)

	if has_tether:
		_tether_mesh.surface_end()


# ============================================================
# LOBBY MANAGEMENT
# ============================================================

func _show_lobby() -> void:
	phase = PHASE_LOBBY
	hud.show_lobby(_manifest_rows(), _test_bot_enabled)


func _manifest_rows() -> Array[String]:

	var rows: Array[String] = []

	for player in players:

		if is_instance_valid(player):

			rows.append(
				"%s  |  %s  |  %s" % [
					player.display_name,
					player.role_name,
					player.input_kind.to_upper()
				]
			)

	return rows


func _first_free_slot() -> int:

	for slot in range(4):

		if not _player_slots_used.has(slot):
			return slot

	return -1


func join_keyboard_player() -> void:

	if _keyboard_joined or _player_slots_used.has(0):
		return

	# Keyboard and mouse are reserved for Player 1.
	_keyboard_joined = true

	_spawn_player(0, "keyboard", -1)

	hud.show_lobby(_manifest_rows(), _test_bot_enabled)


func join_gamepad_player(device_id: int) -> void:

	if device_id < 0 or device_id > 3:
		return

	if _joined_gamepad_ids.has(device_id):
		return

	var slot: int = _first_free_slot()

	if slot < 0:
		return

	_joined_gamepad_ids.append(device_id)

	_spawn_player(slot, "gamepad", device_id)

	hud.show_lobby(_manifest_rows(), _test_bot_enabled)


func toggle_test_bot() -> void:

	if phase != PHASE_LOBBY:
		return

	if _test_bot_enabled:

		for player in players:

			if is_instance_valid(player) and player.input_kind == "bot":

				_player_slots_used.erase(player.slot_index)

				player.queue_free()
				players.erase(player)

				break

		_test_bot_enabled = false

	else:

		var slot: int = _first_free_slot()

		if slot >= 0:

			_spawn_player(slot, "bot", -1)
			_test_bot_enabled = true

	hud.show_lobby(_manifest_rows(), _test_bot_enabled)


func has_test_bot() -> bool:
	return _test_bot_enabled


func _spawn_player(slot: int, kind: String, device_id: int) -> void:

	var player := PLAYER_SCENE.instantiate() as PlayerController

	player.name = "Player_%d" % (slot + 1)

	add_child(player)

	var spawn: Vector3 = _spawn_position_for_slot(slot)

	player.global_position = spawn

	player.setup(self, slot, kind, device_id)

	players.append(player)
	_player_slots_used.append(slot)

	player.reset_for_round(spawn)


func _spawn_position_for_slot(slot: int) -> Vector3:

	var positions: Array[Vector3] = [
		Vector3(-3.7, 1.8, -3.6),
		Vector3(3.7, 1.8, -3.6),
		Vector3(-3.7, 1.8, 3.6),
		Vector3(3.7, 1.8, 3.6)
	]

	return positions[clampi(slot, 0, 3)]


# ============================================================
# HULL BREACH WELDING
# ============================================================

func update_player_welding(
	player: PlayerController,
	delta: float
) -> bool:

	if not is_instance_valid(player) or not player.is_alive:
		return false

	# Explicit type prevents Variant inference errors.
	var spark: Node3D = arena.find_nearest_breach_spark(
		player,
		hull_weld_range
	)

	var holding_interact: bool = (
		player.input_source != null
		and player.input_source.action_pressed(&"interact")
	)

	var player_id: int = player.get_instance_id()

	# Stop welding when the player leaves the breach or releases X.
	if spark == null or not holding_interact:

		_weld_progress.erase(player_id)

		if spark != null:
			spark.call("set_weld_progress", 0.0)

		return false

	var state: Dictionary = _weld_progress.get(
		player_id,
		{
			"spark": spark,
			"progress": 0.0
		}
	)

	# Changing the repair target resets progress.
	if state["spark"] != spark:
		state = {
			"spark": spark,
			"progress": 0.0
		}

	var progress: float = float(state["progress"])

	progress += delta / maxf(hull_weld_duration, 0.01)

	state["progress"] = progress

	_weld_progress[player_id] = state

	spark.call("set_weld_progress", progress)

	# Complete the repair after two seconds.
	if progress >= 1.0:

		spark.call("repair")

		_weld_progress.erase(player_id)

		notify_corporate(
			"HULL BREACH SEALED. PRESSURE RESTORATION AUTHORIZED. EMPLOYEE CONTRIBUTION LOGGED.",
			3.0
		)

	return true


func get_active_breach_count() -> int:
	return arena.get_active_breach_count()


# ============================================================
# MATCH START / RESTART
# ============================================================

func try_start_match() -> void:

	if phase != PHASE_LOBBY:
		return

	if get_living_players().size() < 2:

		notify_corporate(
			"MINIMUM HEADCOUNT IS TWO. ENABLE A TEST DUMMY OR INVITE A COWORKER.",
			3.0
		)

		return

	_saved_configs.clear()

	for player in players:

		if is_instance_valid(player):

			_saved_configs.append({
				"slot": player.slot_index,
				"kind": player.input_kind,
				"device": player.controller_device_id
			})

	start_round()


func start_round() -> void:

	Engine.time_scale = 1.0

	SoundManager.reset_round()

	_weld_progress.clear()

	phase = PHASE_1

	reactor_timer = reactor_duration_seconds
	launch_timer = launch_countdown_seconds
	overtime_timer = 0.0

	overtime_active = false
	fuel_delivered = 0

	airlock_timer = 0.0
	gravity_timer = 0.0
	gravity_flip_active = false

	eliminated.clear()

	arena.reset_arena()

	for player in players:

		if is_instance_valid(player):

			player.reset_for_round(
				_spawn_position_for_slot(player.slot_index)
			)

	hud.show_subtitle(
		"PHASE 1. RECOVER THREE FUEL CELLS. YOUR PENSION IS CONTINGENT ON PRODUCTIVE TEAMWORK.",
		4.0
	)


func restart_round() -> void:

	if _restart_guard:
		return

	_restart_guard = true

	if players.is_empty() and not _saved_configs.is_empty():

		for config in _saved_configs:

			_spawn_player(
				int(config.slot),
				String(config.kind),
				int(config.device)
			)

	start_round()

	_restart_guard = false


# ============================================================
# MAIN GAME LOOP
# ============================================================

func _process(delta: float) -> void:

	_update_pact_tether()

	# Prevent large frame-time spikes from instantly consuming timers.
	var safe_delta: float = minf(delta, 0.1)

	# --------------------------------------------------------
	# AIRLOCK TIMER
	# --------------------------------------------------------

	if airlock_timer > 0.0:

		airlock_timer = maxf(
			0.0,
			airlock_timer - safe_delta
		)

		if airlock_timer <= 0.0:

			arena.set_doors_sealed(false)

			SoundManager.set_vacuum_active(false)

			notify_corporate(
				"AIRLOCK PRESSURE RESTORED. EMPLOYEE LOSS ESTIMATE: ACCEPTABLE.",
				2.4
			)

	# --------------------------------------------------------
	# GRAVITY INVERTER TIMER
	# --------------------------------------------------------

	if gravity_timer > 0.0:

		gravity_timer = maxf(
			0.0,
			gravity_timer - safe_delta
		)

		gravity_flip_active = gravity_timer > 0.0

		if gravity_timer <= 0.0:

			notify_corporate(
				"SECTOR GRAVITY NOMINAL. PLEASE RETURN ALL UNSECURED PERSONNEL TO THE DECK.",
				2.5
			)

	# --------------------------------------------------------
	# PHASE 1 / PHASE 2 REACTOR TIMER
	# --------------------------------------------------------

	if phase == PHASE_1 or phase == PHASE_2:

		reactor_timer = maxf(
			0.0,
			reactor_timer - safe_delta
		)

		if reactor_timer <= 0.0:

			push_warning(
				"REACTOR TIMEOUT: phase=%d, fuel=%d/3, raw_delta=%.3f"
				% [phase, fuel_delivered, delta]
			)

			for player in get_living_players():

				player.eliminate(
					"reactor insolvency — the rig entered the event horizon"
				)

			_end_match(
				null,
				"REACTOR FAILURE BEFORE THREE CELLS WERE DELIVERED"
			)

	# --------------------------------------------------------
	# PHASE 3 LAUNCH / OVERTIME
	# --------------------------------------------------------

	elif phase == PHASE_3:

		var occupants: Array = get_pod_occupants()

		if overtime_active and occupants.size() == 1:

			_end_match(
				occupants[0],
				"SINGLE EMPLOYEE VERIFIED INSIDE THE ONE-SEAT ESCAPE POD"
			)

			return

		launch_timer = maxf(
			0.0,
			launch_timer - safe_delta
		)

		if launch_timer <= 0.0:

			if occupants.size() == 1:

				_end_match(
					occupants[0],
					"CLAUSE 99 EXTRACTION COMPLETED"
				)

			elif occupants.size() > 1:

				overtime_active = true
				overtime_timer -= safe_delta

				if overtime_timer <= 0.0:

					if overtime_repeat_if_jammed:

						overtime_timer = overtime_window_seconds

						notify_corporate(
							"DOOR JAMMED — OVERTIME. ONE OCCUPANT MUST VOLUNTARILY OR INVOLUNTARILY VACATE.",
							5.0
						)

					else:

						_end_match(
							null,
							"POD DOOR JAMMED — COMPRESSION PROTOCOL CANCELLED ALL CLAIMS"
						)

			else:

				_end_match(
					null,
					"NO LIVING EMPLOYEE OCCUPIED THE ESCAPE POD AT LAUNCH"
				)

	# --------------------------------------------------------
	# ALL PLAYERS ELIMINATED
	# --------------------------------------------------------

	if (
		phase in [PHASE_1, PHASE_2, PHASE_3]
		and get_living_players().is_empty()
	):

		_end_match(
			null,
			"ALL CREW MEMBERS ELIMINATED — PAYOUT FORFEITED"
		)


# ============================================================
# PHASE PROGRESSION
# ============================================================

func _check_phase_progression() -> void:

	if phase == PHASE_1 and fuel_delivered >= 2:

		phase = PHASE_2

		arena.set_emergency_state(true)
		arena.set_terminals_unlocked(true)

		hud.show_subtitle(
			"PHASE 2: ESCAPE POD LIFE-SUPPORT VERIFIED AT ONE OCCUPANT. PENSION AUTHORIZED FOR SOLE SURVIVOR.",
			5.0
		)

	elif phase == PHASE_2 and fuel_delivered >= 3:

		phase = PHASE_3

		launch_timer = launch_countdown_seconds

		overtime_active = false
		overtime_timer = 0.0

		hud.show_subtitle(
			"PHASE 3: FRIENDLY-FIRE LIABILITY WAIVER ACCEPTED. LAUNCH IN 30 SECONDS. ONE SEAT. ONE PAYOUT.",
			4.5
		)


# ============================================================
# PLAYER INTERACTION
# ============================================================

func handle_player_interact(player: PlayerController) -> void:

	if not player.is_alive:
		return

	# --------------------------------------------------------
	# PRIORITY 1: HULL BREACH
	# --------------------------------------------------------

	var nearby_breach: Node3D = arena.find_nearest_breach_spark(
		player,
		hull_weld_range
	)

	if nearby_breach != null:

		notify_corporate(
			"HULL BREACH DETECTED. HOLD X FOR TWO SECONDS TO WELD.",
			2.0
		)

		return

	# --------------------------------------------------------
	# PRIORITY 2: DEPOSIT OR DROP CARRIED FUEL CELL
	# --------------------------------------------------------

	if player.carried_cell != null:

		if arena.pod.contains_player(player) and fuel_delivered < 3:

			var cell: FuelCell = player.carried_cell

			player.carried_cell = null

			cell.queue_free()

			fuel_delivered += 1

			notify_corporate(
				"FUEL CELL ACCEPTED. EMPLOYEE CONTRIBUTION HAS BEEN NOTED.",
				2.0
			)

			_check_phase_progression()

		else:

			player.drop_carried_cell()

		return

	# --------------------------------------------------------
	# PRIORITY 3: PICK UP NEAREST FUEL CELL
	# --------------------------------------------------------

	var nearest_cell: FuelCell = null
	var nearest_distance: float = 1.75

	for node in get_tree().get_nodes_in_group("fuel_cells"):

		if node is FuelCell and node.carrier == null:

			var distance: float = player.global_position.distance_to(
				node.global_position
			)

			if distance < nearest_distance:

				nearest_distance = distance
				nearest_cell = node

	if nearest_cell != null:

		player.pick_up_cell(nearest_cell)

		return

	# --------------------------------------------------------
	# PRIORITY 4: SABOTAGE TERMINAL
	# --------------------------------------------------------

	var nearest_terminal: SabotageTerminal = null
	var terminal_distance: float = 2.1

	for terminal in arena.terminals:

		var distance: float = player.global_position.distance_to(
			terminal.global_position
		)

		if distance < terminal_distance:

			terminal_distance = distance
			nearest_terminal = terminal

	if nearest_terminal != null:

		nearest_terminal.activate(self)

		return

	# --------------------------------------------------------
	# PRIORITY 5: SEAL ESCAPE POD
	# --------------------------------------------------------

	if (
		phase == PHASE_3
		and arena.pod.contains_player(player)
		and not arena.pod.sealed
	):

		arena.pod.seal(player)

		notify_corporate(
			"ESCAPE POD SEALED BY %s. ADDITIONAL BOARDING IS NOW A SECURITY EVENT."
			% player.display_name,
			2.8
		)

	else:

		notify_corporate(
			"NO AUTHORIZED INTERACTION IN RANGE.",
			1.2
		)


# ============================================================
# SHOVE / COMBAT
# ============================================================

func try_shove(
	attacker: PlayerController,
	direction: Vector3,
	max_range: float,
	force: float
) -> void:

	if not attacker.is_alive:
		return

	var flat_direction: Vector3 = Vector3(
		direction.x,
		0.0,
		direction.z
	).normalized()

	if flat_direction.length_squared() < 0.001:
		return

	var origin: Vector3 = attacker.global_position + Vector3.UP * 0.48

	var target_position: Vector3 = (
		origin + flat_direction * max_range
	)

	var query := PhysicsRayQueryParameters3D.create(
		origin,
		target_position,
		1 | 2
	)

	query.exclude = [attacker.get_rid()]
	query.collide_with_areas = false

	var hit: Dictionary = (
		get_world_3d().direct_space_state.intersect_ray(query)
	)

	if hit.is_empty():
		return

	var hit_object: Object = hit.get("collider")

	if not (hit_object is PlayerController):
		return

	# Layer 1 walls intentionally occlude shoves.
	var target := hit_object as PlayerController

	if not target.is_alive:
		return

	var knockback: float = force

	if attacker.pact_partner == target:

		break_pact(attacker, true)

		knockback *= attacker.pact_breach_knockback_multiplier

		notify_corporate(
			"CONTRACT BREACHED. PARTNER LIABILITY MULTIPLIER APPLIED.",
			2.2
		)

	elif target.pact_partner == attacker:

		break_pact(target, true)

		knockback *= attacker.pact_breach_knockback_multiplier

		notify_corporate(
			"CONTRACT BREACHED. PARTNER LIABILITY MULTIPLIER APPLIED.",
			2.2
		)

	target.receive_shove(
		attacker,
		flat_direction,
		knockback
	)


# ============================================================
# DEAD MAN'S PACT
# ============================================================

func form_pact(
	first: PlayerController,
	second: PlayerController
) -> void:

	if first == null or second == null or first == second:
		return

	if not first.is_alive or not second.is_alive:
		return

	if first.pact_partner != null or second.pact_partner != null:
		return

	if first.global_position.distance_to(second.global_position) > first.pact_range:
		return

	first.pact_partner = second
	second.pact_partner = first

	notify_corporate(
		"DEAD MAN'S PACT REGISTERED. SPEED AND LIFE-SUPPORT EFFICIENCY CREDITED.",
		3.0
	)


func break_pact(
	player: PlayerController,
	announce: bool = true
) -> void:

	if player == null or player.pact_partner == null:
		return

	var partner: PlayerController = player.pact_partner

	player.pact_partner = null

	if (
		is_instance_valid(partner)
		and partner.pact_partner == player
	):

		partner.pact_partner = null

	if announce:

		notify_corporate(
			"CONTRACT BREACHED. BENEFITS REVOKED.",
			2.0
		)

	SoundManager.play_betrayal()


func find_nearest_ally(
	player: PlayerController,
	max_distance: float
) -> PlayerController:

	var nearest: PlayerController = null
	var best_distance: float = max_distance

	for candidate in players:

		if candidate == player:
			continue

		if not is_instance_valid(candidate):
			continue

		if not candidate.is_alive or candidate.pact_partner != null:
			continue

		var distance: float = player.global_position.distance_to(
			candidate.global_position
		)

		if distance <= best_distance:

			best_distance = distance
			nearest = candidate

	return nearest


# ============================================================
# ENVIRONMENT FORCES
# ============================================================

func get_player_environment_force(
	player: PlayerController
) -> Vector3:

	var force: Vector3 = Vector3.ZERO

	if airlock_timer > 0.0:

		# Explicit types prevent Variant inference failures.
		var toward: Vector3 = (
			arena.airlock_suction_position
			- player.global_position
		)

		var distance: float = toward.length()

		if (
			distance < airlock_suction_range
			and distance > 0.01
		):

			force += (
				toward.normalized()
				* airlock_suction_force
				* (1.0 - distance / airlock_suction_range * 0.35)
			)

	return force


# ============================================================
# SABOTAGE
# ============================================================

func activate_airlock_venting() -> void:

	airlock_timer = airlock_vent_duration

	arena.set_doors_sealed(true)

	SoundManager.play_airlock_start()

	notify_corporate(
		"AIRLOCK VENTING ENABLED. BLAST DOORS SEALED. OXYGEN DRAIN MULTIPLIED BY FOUR.",
		4.0
	)


func activate_gravity_inverter() -> void:

	gravity_timer = gravity_inverter_duration
	gravity_flip_active = true

	notify_corporate(
		"GRAVITY INVERSION ACTIVE. FLOOR TRACTION HAS BEEN SUSPENDED FOR SIX SECONDS.",
		3.8
	)


# ============================================================
# PLAYER QUERIES
# ============================================================

func get_living_players() -> Array:

	var living: Array = []

	for player in players:

		if is_instance_valid(player) and player.is_alive:
			living.append(player)

	return living


func get_pod_occupants() -> Array:

	var occupants: Array = []

	for player in get_living_players():

		if arena.pod.contains_player(player):
			occupants.append(player)

	return occupants


# ============================================================
# ELIMINATION
# ============================================================

func player_eliminated(
	player: PlayerController,
	cause: String
) -> void:

	eliminated.append({
		"name": player.display_name,
		"cause": cause
	})

	notify_corporate(
		"EMPLOYEE %s REMOVED FROM ACTIVE PAYROLL."
		% player.display_name,
		2.0
	)


# ============================================================
# CORPORATE MESSAGES
# ============================================================

func notify_corporate(
	message: String,
	duration: float = 2.8
) -> void:

	if hud != null:
		hud.show_subtitle(message, duration)

	# The HUD's typewriter subtitle handles the intercom beep.
	# Do not play it again here, otherwise every message double-beeps.


# ============================================================
# IMPACT FEEDBACK
# ============================================================

func trigger_impact_feedback(amount: float) -> void:

	if game_camera != null:

		game_camera.kick_shake(
			camera_shake_strength * amount
		)

	if Engine.time_scale > hitstop_time_scale:

		Engine.time_scale = hitstop_time_scale

		get_tree().create_timer(
			impact_hitstop_seconds,
			true,
			false,
			true
		).timeout.connect(_release_hitstop)

	SoundManager.play_impact()


func _release_hitstop() -> void:
	Engine.time_scale = 1.0


# ============================================================
# MATCH END / INCIDENT REPORT
# ============================================================

func _end_match(
	winner,
	reason: String
) -> void:

	if phase == PHASE_REPORT:
		return

	Engine.time_scale = 1.0

	# Record all employees who failed to escape.
	for player in get_living_players():

		if player != winner:

			var cause: String

			if winner != null:

				cause = (
					"left behind in the event horizon "
					+ "after the sole-seat extraction"
				)

			else:

				cause = (
					"unpaid event-horizon exposure — "
					+ "extraction window missed"
				)

			player.eliminate(cause)

		else:

			player.set_physics_process(false)
			player.set_process(false)

			break_pact(player, false)

	phase = PHASE_REPORT
	overtime_active = false

	_weld_progress.clear()

	hud.show_incident_report(
		winner,
		eliminated,
		reason,
		fuel_delivered
	)
