extends Control

## Small diegetic 2D radar of the five-room cross-shaped mining deck.

var manager: Variant
var refresh_clock: float = 0.0

const MAP_MARGIN: float = 12.0
const WORLD_HALF_EXTENT: float = 28.0


func _ready() -> void:
	custom_minimum_size = Vector2(208.0, 208.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(game_manager: Variant) -> void:
	manager = game_manager
	queue_redraw()


func _process(delta: float) -> void:
	refresh_clock += delta
	if refresh_clock >= 0.12:
		refresh_clock = 0.0
		queue_redraw()


func _draw() -> void:
	var size: Vector2 = get_rect().size
	if size.x < 100.0 or size.y < 100.0:
		return

	# Rounded-looking dark panel with a crisp border.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.025, 0.04, 0.86), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.62, 0.72, 0.95), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(10.0, 14.0), "TARTARUS-9 // DECK RADAR", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.75, 0.9, 1.0))

	var map_rect := Rect2(
		Vector2(MAP_MARGIN, 22.0),
		Vector2(size.x - MAP_MARGIN * 2.0, size.y - 32.0)
	)

	# Draw the five connected room footprints.
	_draw_room(map_rect, Rect2(-9.0, -9.0, 18.0, 18.0), Color(0.52, 0.4, 0.15, 0.65), Color(1.0, 0.72, 0.25))
	_draw_room(map_rect, Rect2(-27.0, -9.0, 18.0, 18.0), Color(0.09, 0.25, 0.48, 0.7), Color(0.22, 0.62, 1.0))
	_draw_room(map_rect, Rect2(9.0, -9.0, 18.0, 18.0), Color(0.38, 0.2, 0.09, 0.7), Color(1.0, 0.55, 0.18))
	_draw_room(map_rect, Rect2(-9.0, -27.0, 18.0, 18.0), Color(0.07, 0.3, 0.34, 0.7), Color(0.22, 0.88, 0.95))
	_draw_room(map_rect, Rect2(-9.0, 9.0, 18.0, 18.0), Color(0.08, 0.32, 0.2, 0.7), Color(0.25, 0.95, 0.55))

	# Mark the five room names.
	_draw_world_text(map_rect, Vector3(-18.0, 0.0, 0.0), "R")
	_draw_world_text(map_rect, Vector3(18.0, 0.0, 0.0), "C")
	_draw_world_text(map_rect, Vector3(0.0, 0.0, -18.0), "G")
	_draw_world_text(map_rect, Vector3(0.0, 0.0, 18.0), "M")
	_draw_world_text(map_rect, Vector3(0.0, 0.0, 0.0), "POD")

	if manager == null:
		return

	# Fuel cells are amber diamonds.
	var arena: Variant = manager.get("arena")
	if arena != null:
		var cells: Variant = arena.get("fuel_cells")
		if cells is Array:
			for cell in cells:
				if not is_instance_valid(cell):
					continue
				if cell.get("carrier") != null:
					continue
				var cell_position: Vector3 = cell.global_position
				var point: Vector2 = _world_to_map(map_rect, cell_position)
				draw_colored_polygon(
					PackedVector2Array([
						point + Vector2(0, -4),
						point + Vector2(4, 0),
						point + Vector2(0, 4),
						point + Vector2(-4, 0)
					]),
					Color(1.0, 0.68, 0.16)
				)

	# Players are role-colored circles; eliminated players are small dim rings.
	var players: Variant = manager.get("players")
	if players is Array:
		for player in players:
			if not is_instance_valid(player):
				continue
			var player_position: Vector3 = player.global_position
			var player_point: Vector2 = _world_to_map(map_rect, player_position)
			var player_color: Color = Color(0.8, 0.85, 0.9)
			var color_value: Variant = player.get("role_color")
			if color_value is Color:
				player_color = color_value
			if bool(player.get("is_alive")):
				draw_circle(player_point, 4.2, player_color)
				draw_arc(player_point, 5.2, 0.0, TAU, 20, Color.WHITE, 1.0)
			else:
				draw_arc(player_point, 3.4, 0.0, TAU, 16, player_color.darkened(0.5), 1.0)

	# Legend.
	draw_circle(Vector2(16.0, size.y - 10.0), 3.0, Color(1.0, 0.68, 0.16))
	draw_string(ThemeDB.fallback_font, Vector2(23.0, size.y - 6.0), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.9, 0.88, 0.8))


func _draw_room(
	map_rect: Rect2,
	world_rect: Rect2,
	fill_color: Color,
	border_color: Color
) -> void:
	var top_left := _world_to_map(map_rect, Vector3(world_rect.position.x, 0.0, world_rect.position.y))
	var bottom_right := _world_to_map(map_rect, Vector3(world_rect.end.x, 0.0, world_rect.end.y))
	var room_rect := Rect2(top_left, bottom_right - top_left)
	draw_rect(room_rect, fill_color, true)
	draw_rect(room_rect, border_color, false, 1.4)


func _draw_world_text(map_rect: Rect2, world_position: Vector3, text: String) -> void:
	var point := _world_to_map(map_rect, world_position)
	draw_string(ThemeDB.fallback_font, point + Vector2(-8.0, 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color(0.93, 0.96, 1.0, 0.8))


func _world_to_map(map_rect: Rect2, world_position: Vector3) -> Vector2:
	var normalized_x: float = (world_position.x + WORLD_HALF_EXTENT) / (WORLD_HALF_EXTENT * 2.0)
	var normalized_z: float = (world_position.z + WORLD_HALF_EXTENT) / (WORLD_HALF_EXTENT * 2.0)
	return map_rect.position + Vector2(
		clampf(normalized_x, 0.0, 1.0) * map_rect.size.x,
		clampf(normalized_z, 0.0, 1.0) * map_rect.size.y
	)
