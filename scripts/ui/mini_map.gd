# scripts/ui/mini_map.gd
extends Control

@export var tile_size: int = 4  # маленький размер тайла на мини-карте
@export var map_margin: int = 4

var game_controller: GameController

func _ready():
	# Ждём, пока GameController загрузится
	await get_tree().process_frame
	game_controller = get_node("/root/GameControllerAuto")
	if game_controller:
		print("MiniMap: GameController найден")
		queue_redraw()
	else:
		print("MiniMap: GameController не найден!")

func _draw():
	if not game_controller or not game_controller.grid_state:
		return
	
	var grid = game_controller.grid_state
	var width = grid.width
	var height = grid.height
	
	# Вычисляем размер панели мини-карты
	var panel_size = Vector2(
		width * tile_size + map_margin * 2,
		height * tile_size + map_margin * 2
	)
	custom_minimum_size = panel_size
	size = panel_size
	
	# Рисуем тайлы
	for x in range(width):
		for y in range(height):
			var tile_type = grid.tiles[x][y]["type"]
			var color = _get_tile_color(tile_type)
			var rect = Rect2(
				Vector2(x * tile_size + map_margin, y * tile_size + map_margin),
				Vector2(tile_size, tile_size)
			)
			draw_rect(rect, color)
	
	# Рисуем юнитов
	for pos_key in grid.units:
		var unit = grid.units[pos_key]
		var coords = pos_key.split("_")
		var x = int(coords[0])
		var y = int(coords[1])
		
		var marker_color = Color.YELLOW
		match unit["type"]:
			"player":
				marker_color = Color.YELLOW
			"enemy":
				marker_color = Color.RED
			"npc":
				marker_color = Color.GREEN
			_:
				marker_color = Color.WHITE
		
		var marker_rect = Rect2(
			Vector2(x * tile_size + map_margin, y * tile_size + map_margin),
			Vector2(tile_size, tile_size)
		)
		draw_rect(marker_rect, marker_color)
	
	# Рисуем двери
	if "doors" in grid and grid.doors is Dictionary:
		for door_key in grid.doors:
			var door = grid.doors[door_key]
			var coords = door_key.split("_")
			var x = int(coords[0])
			var y = int(coords[1])
			var door_rect = Rect2(
				Vector2(x * tile_size + map_margin, y * tile_size + map_margin),
				Vector2(tile_size, tile_size)
			)
			draw_rect(door_rect, Color(0.6, 0.3, 0.1))  # коричневый

func _process(_delta):
	# Обновляем мини-карту каждый кадр (можно реже для оптимизации)
	queue_redraw()

func _get_tile_color(tile_type) -> Color:
	match tile_type:
		GridState.TileType.FLOOR:
			return Color(0.6, 0.6, 0.6)
		GridState.TileType.WALL:
			return Color(0.7, 0.2, 0.2)
		GridState.TileType.GRASS:
			return Color(0.1, 0.8, 0.1)
		GridState.TileType.STONE:
			return Color(0.7, 0.7, 0.7)
		GridState.TileType.DIRT:
			return Color(0.8, 0.5, 0.2)
		GridState.TileType.WATER:
			return Color(0.2, 0.5, 0.9)
		GridState.TileType.TABLE:
			return Color(0.6, 0.3, 0.1)
		GridState.TileType.CHAIR:
			return Color(0.5, 0.2, 0.0)
		_:
			return Color(0.4, 0.4, 0.4)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			# Будет реализовано позже — открытие карты мира
			pass
