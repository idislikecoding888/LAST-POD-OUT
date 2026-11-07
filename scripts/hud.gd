
extends CanvasLayer
class_name GameHUD

## Runtime-built HUD for LAST POD OUT.
## Handles lobby, gameplay objectives, subtitles and incident reports.

var manager: Variant

var root_control: Control
var lobby_panel: PanelContainer
var report_panel: PanelContainer

var lobby_text: Label
var phase_label: Label
var timer_label: Label
var fuel_label: Label
var objective_label: Label
var subtitle_label: Label
var player_status_label: Label
var report_text: Label
var rematch_button: Button

var subtitle_remaining: float = 0.0

@export var ticker_characters_per_second: float = 48.0

var _ticker_full_text: String = ""
var _ticker_visible_chars: int = 0
var _ticker_clock: float = 0.0

func _ready() -> void:
	_build_ui()


func configure(game_manager: Node) -> void:
	manager = game_manager


func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# Top-left phase indicator.
	phase_label = _label(
		"PHASE 0 // CREW REGISTRATION",
		22,
		Color(0.45, 0.85, 1.0)
	)
	phase_label.position = Vector2(28, 20)
	phase_label.size = Vector2(580, 34)
	root_control.add_child(phase_label)

	# Top-right countdown.
	timer_label = _label(
		"REACTOR 03:00",
		25,
		Color(1.0, 0.72, 0.36)
	)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.position = Vector2(1020, 20)
	timer_label.size = Vector2(390, 36)
	root_control.add_child(timer_label)

	# Fuel counter.
	fuel_label = _label(
		"FUEL CELLS 0 / 3",
		19,
		Color(0.95, 0.95, 1.0)
	)
	fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fuel_label.position = Vector2(28, 62)
	fuel_label.size = Vector2(400, 28)
	root_control.add_child(fuel_label)

	# Clear gameplay objective.
	objective_label = _label(
		"OBJECTIVE: COLLECT 3 FUEL CELLS",
		16,
		Color(1.0, 0.76, 0.35)
	)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_label.position = Vector2(28, 98)
	objective_label.size = Vector2(1050, 32)
	root_control.add_child(objective_label)

	# Corporate AI subtitles.
	subtitle_label = _label(
		"",
		20,
		Color(1.0, 0.84, 0.62)
	)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.position = Vector2(210, 140)
	subtitle_label.size = Vector2(1020, 60)
	subtitle_label.visible = false
	root_control.add_child(subtitle_label)

	# Player oxygen / survival status.
	player_status_label = _label(
		"",
		16,
		Color(0.78, 0.88, 0.96)
	)
	player_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	player_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	player_status_label.position = Vector2(28, 720)
	player_status_label.size = Vector2(620, 150)
	root_control.add_child(player_status_label)

	# ---------------------------------
	# LOBBY PANEL
	# ---------------------------------
	lobby_panel = _panel(Vector2(720, 480))
	lobby_panel.set_anchors_preset(Control.PRESET_CENTER)
	lobby_panel.offset_left = -380
	lobby_panel.offset_top = -245
	lobby_panel.offset_right = 380
	lobby_panel.offset_bottom = 245
	root_control.add_child(lobby_panel)

	var lobby_box := VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 12)
	lobby_box.alignment = BoxContainer.ALIGNMENT_CENTER
	lobby_panel.add_child(lobby_box)

	lobby_box.add_child(
		_label("LAST POD OUT", 42, Color(0.9, 0.94, 0.98))
	)

	lobby_box.add_child(
		_label(
			"THE KESSLER CLAUSE  //  USCSS TARTARUS-9",
			16,
			Color(0.98, 0.49, 0.23)
		)
	)

	lobby_text = _label("", 20, Color(0.79, 0.87, 0.92))
	lobby_text.custom_minimum_size = Vector2(680, 125)
	lobby_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_box.add_child(lobby_text)

	lobby_box.add_child(
		_label(
			"WASD / LEFT STICK MOVE   •   MOUSE / RIGHT STICK AIM",
			14,
			Color(0.58, 0.72, 0.8)
		)
	)

	lobby_box.add_child(
		_label(
			"RMB / LT SHOVE   •   Q / RB PARRY   •   SHIFT / B DODGE",
			14,
			Color(0.58, 0.72, 0.8)
		)
	)

	lobby_box.add_child(
		_label(
			"E / X INTERACT   •   HOLD F / Y NEAR ALLY FOR DEAD MAN'S PACT",
			14,
			Color(0.58, 0.72, 0.8)
		)
	)

	lobby_box.add_child(
		_label(
			"SPACE / A JOIN     ENTER / START BEGIN     Y / TAB TEST DUMMY",
			16,
			Color(0.98, 0.78, 0.45)
		)
	)

	# ---------------------------------
	# CORPORATE INCIDENT REPORT
	# ---------------------------------
	report_panel = _panel(Vector2(880, 630))
	report_panel.set_anchors_preset(Control.PRESET_CENTER)
	report_panel.offset_left = -440
	report_panel.offset_top = -315
	report_panel.offset_right = 440
	report_panel.offset_bottom = 315
	report_panel.visible = false
	root_control.add_child(report_panel)

	var report_box := VBoxContainer.new()
	report_box.add_theme_constant_override("separation", 14)
	report_box.alignment = BoxContainer.ALIGNMENT_CENTER
	report_panel.add_child(report_box)

	report_box.add_child(
		_label(
			"AETHER-VANGUARD // CORPORATE INCIDENT REPORT",
			23,
			Color(1.0, 0.57, 0.31)
		)
	)

	report_text = _label("", 18, Color(0.86, 0.89, 0.92))
	report_text.custom_minimum_size = Vector2(800, 400)
	report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_box.add_child(report_text)

	rematch_button = Button.new()
	rematch_button.text = "PRESS A / ENTER TO REMATCH"
	rematch_button.custom_minimum_size = Vector2(520, 54)
	rematch_button.add_theme_font_size_override("font_size", 20)
	rematch_button.pressed.connect(_on_rematch_pressed)
	report_box.add_child(rematch_button)


func _label(
	text_value: String,
	font_size: int,
	color: Color
) -> Label:
	var new_label := Label.new()
	new_label.text = text_value
	new_label.add_theme_font_size_override("font_size", font_size)
	new_label.add_theme_color_override("font_color", color)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return new_label


func _panel(min_size: Vector2) -> PanelContainer:
	var new_panel := PanelContainer.new()
	new_panel.custom_minimum_size = min_size

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.03, 0.05, 0.96)
	style.border_color = Color(0.18, 0.42, 0.51, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0

	new_panel.add_theme_stylebox_override("panel", style)
	return new_panel



func show_lobby(
	player_rows: Array[String],
	bot_enabled: bool
) -> void:

	lobby_panel.visible = true
	report_panel.visible = false

	phase_label.text = "CREW REGISTRATION"
	timer_label.text = "CLAUSE 99 // ACTIVE"

	fuel_label.text = "FUEL CELLS 0 / 3"
	objective_label.text = "AWAITING CREW REGISTRATION"

	player_status_label.text = ""

	var text_value: String = (
		"USCSS TARTARUS-9 // AETHER-VANGUARD\n\n"
		+ "RECOVER THREE FUEL CELLS. REACH THE ESCAPE POD. "
		+ "ONLY ONE EMPLOYEE RECEIVES THE SURVIVOR PENSION.\n\n"
	)

	text_value += "CREW MANIFEST\n"

	if player_rows.is_empty():

		text_value += "NO CREW REGISTERED\n"

	else:

		for row in player_rows:
			text_value += row + "\n"

	text_value += "\nTEST DUMMY: %s\n" % (
		"ON" if bot_enabled else "OFF"
	)

	text_value += "\nCONTROLS\n"

	text_value += "MOVE: WASD / LEFT STICK    AIM: MOUSE / RIGHT STICK\n"
	text_value += "SHOVE: RMB / LT    PARRY: Q / RB    DASH: SHIFT / B\n"
	text_value += "INTERACT / WELD: E / X    PACT: HOLD F / Y NEAR ALLY\n"

	text_value += "\nSPACE / A JOIN    ENTER / START PLAY    Y / TAB BOT"

	lobby_text.text = text_value



func update_game(manager_value: Variant) -> void:
	# Critical lobby transition fix:
	# Any active match must hide the lobby overlay.
	lobby_panel.visible = false
	report_panel.visible = false

	if manager_value.phase == 4 or manager_value.phase == 0:
		return

	var phase_name: String = "PHASE 1 // REACTOR RECOVERY"
	var objective: String = (
		"OBJECTIVE: FIND AMBER FUEL CELLS "
		+ "AND DELIVER THEM TO THE CENTRAL ESCAPE POD."
	)

	if manager_value.phase == 2:
		phase_name = "PHASE 2 // SABOTAGE AUTHORIZED"
		objective = (
			"WARNING: OXYGEN DRAIN DOUBLED. "
			+ "DELIVER THE FINAL FUEL CELL."
		)

	elif manager_value.phase == 3:
		phase_name = "PHASE 3 // SINGLE-SEAT EXTRACTION"
		objective = (
			"FINAL EXTRACTION: ENTER THE POD. "
			+ "ONLY ONE EMPLOYEE RECEIVES THE PAYOUT."
		)

	phase_label.text = phase_name
	objective_label.text = objective

	var time_value: float = manager_value.reactor_timer

	if manager_value.phase >= 3:
		time_value = manager_value.launch_timer

	if manager_value.overtime_active:
		time_value = manager_value.overtime_timer

	var timer_prefix: String = "REACTOR"

	if manager_value.phase >= 3:
		timer_prefix = "LAUNCH"

	if manager_value.overtime_active:
		timer_prefix = "OVERTIME"

	var total_seconds: int = int(maxf(0.0, time_value))
	var minutes: int = floori(float(total_seconds) / 60.0)
	var seconds: int = total_seconds % 60

	timer_label.text = "%s %02d:%02d" % [
		timer_prefix,
		minutes,
		seconds
	]

	fuel_label.text = "FUEL CELLS %d / 3" % manager_value.fuel_delivered

	var status: String = ""

	for player in manager_value.players:
		if not is_instance_valid(player):
			continue

		var player_state: String = "OUT"

		if player.is_alive:
			player_state = "O2 %02d%%" % int(player.oxygen)

		status += "%s  %s  —  %s\n" % [
			player.display_name,
			player.role_name,
			player_state
		]

	player_status_label.text = status


func show_subtitle(
	message: String,
	duration: float = 3.0
) -> void:

	_ticker_full_text = "AETHER-VANGUARD AI: \"%s\"" % message
	_ticker_visible_chars = 0
	_ticker_clock = 0.0

	subtitle_label.text = ""
	subtitle_remaining = duration
	subtitle_label.visible = true

	SoundManager.play_intercom_beep()


func show_incident_report(
	winner,
	eliminated: Array,
	reason: String,
	delivered: int
) -> void:
	lobby_panel.visible = false
	report_panel.visible = true

	phase_label.text = "CORPORATE INCIDENT REPORT"
	timer_label.text = "CLAUSE 99 // CLOSED"
	fuel_label.text = "FUEL CELLS DELIVERED %d / 3" % delivered

	objective_label.text = "INCIDENT CLOSED // AETHER-VANGUARD INTERNAL USE"

	var text_value: String = (
		"USCSS TARTARUS-9  |  INCIDENT FILE: AV-99-%04d\n"
		% int(Time.get_ticks_msec() % 10000)
	)

	text_value += "CAUSE: %s\n\n" % reason

	if winner != null and is_instance_valid(winner):
		text_value += (
			"PAYROLL CHECK // AETHER-VANGUARD\n"
			+ "PAY TO THE ORDER OF: %s\n" % winner.display_name
			+ "AUTHORIZED PAYOUT: $9,999,999.99\n"
			+ "CHECK #0099-1 // NON-TRANSFERABLE\n"
			+ "ROLE: %s\n\n" % winner.role_name
		)
	else:
		text_value += (
			"PENSION PAYEE: NONE\n"
			+ "AUTHORIZED PAYOUT: $0.00\n"
			+ "CHECK STATUS: VOID — ALL CLAIMANTS FAILED TO EXTRACT\n\n"
		)

	text_value += "ELIMINATED EMPLOYEES\n"

	if eliminated.is_empty():
		text_value += (
			"  No fatalities recorded. "
			+ "Legal is reviewing the telemetry.\n"
		)
	else:
		for incident in eliminated:
			text_value += "  • %s — %s\n" % [
				incident.get("name", "UNKNOWN"),
				incident.get("cause", "cause pending")
			]

	text_value += (
		"\nAETHER-VANGUARD REMINDS STAFF: "
		+ "YOUR SACRIFICE HAS BEEN ADDED TO OUR "
		+ "QUARTERLY EFFICIENCY REPORT."
	)

	report_text.text = text_value
	rematch_button.text = "PRESS A / ENTER TO REMATCH"


func _on_rematch_pressed() -> void:
	if manager != null:
		manager.restart_round()



func _process(delta: float) -> void:

	# --------------------------------------------------------
	# CORPORATE SUBTITLE TIMER
	# --------------------------------------------------------

	if subtitle_remaining > 0.0:
		subtitle_remaining = maxf(
			0.0,
			subtitle_remaining - delta
		)

		if subtitle_remaining <= 0.0:
			subtitle_label.visible = false

	# --------------------------------------------------------
	# TYPEWRITER EFFECT
	# --------------------------------------------------------

	if (
		subtitle_label.visible
		and _ticker_visible_chars < _ticker_full_text.length()
	):

		_ticker_clock += delta

		var desired_chars: int = int(
			_ticker_clock * ticker_characters_per_second
		)

		if desired_chars > _ticker_visible_chars:

			var previous_chars: int = _ticker_visible_chars

			_ticker_visible_chars = mini(
				desired_chars,
				_ticker_full_text.length()
			)

			subtitle_label.text = _ticker_full_text.substr(
				0,
				_ticker_visible_chars
			)

			# Play occasional typewriter ticks.
			if _ticker_visible_chars / 4 > previous_chars / 4:
				if has_node("/root/SoundManager"):
					get_node("/root/SoundManager").call(
						"play_typewriter_tick"
					)

	# --------------------------------------------------------
	# MANAGER STATE
	# --------------------------------------------------------

	if manager == null:
		return

	var current_phase: int = int(manager.phase)

	# Lobby.
	if current_phase == 0:

		var rows: Array[String] = []

		for player in manager.players:

			if not is_instance_valid(player):
				continue

			rows.append(
				"%s  |  %s  |  %s" % [
					player.display_name,
					player.role_name,
					player.input_kind.to_upper()
				]
			)

		show_lobby(
			rows,
			manager.has_test_bot()
		)

	# Corporate incident report.
	elif current_phase == 4:

		lobby_panel.visible = false

	# Active gameplay.
	else:

		update_game(manager)

