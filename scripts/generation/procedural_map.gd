extends Node
class_name ProceduralMap

enum TileType {
	FLOOR,
	WALL,
	GRASS,
	STONE,
	DIRT,
	WATER
}

# Основная функция генерации карты по параметрам
static func generate(params: Dictionary) -> Dictionary:
	var size = params.get("size", 16)
	var biome = params.get("biome", "dungeon")
	var seed = params.get("seed", randi())
	
	
	# Инициализируем генератор случайных чисел
	seed(seed)
	
	# Создаём пустую карту
	var tiles = []
	var heights = []
	
	for x in range(size):
		tiles.append([])
		heights.append([])
		for y in range(size):
			tiles[x].append(TileType.FLOOR)
			heights[x].append(0)
	
	# Применяем базовый биом
	match biome:
		"dungeon":
			_apply_dungeon_biome(tiles, size)
		"forest":
			_apply_forest_biome(tiles, size)
		"mountain":
			_apply_mountain_biome(tiles, heights, size)
		"cave":
			_apply_cave_biome(tiles, size)
		_:
			_apply_dungeon_biome(tiles, size)
	
	# Применяем дополнительные стены (периметр), если не в пещере
	if biome != "cave" and not params.get("no_perimeter", false):
		_apply_perimeter_walls(tiles, size, params.get("wall_thickness", 1))
	
	# Применяем особенности из параметров
	if params.has("features"):
		for feature in params["features"]:
			_apply_feature(tiles, heights, feature, size)
	
	# Создаём комнаты (если указаны)
	if params.has("rooms"):
		for room in params["rooms"]:
			_create_room(tiles, room, size)
	
	# Создаём коридоры (если указаны)
	if params.has("corridors"):
		for corridor in params["corridors"]:
			_create_corridor(tiles, corridor, size)
	
	# Размещаем врагов
	var enemies = []
	if params.has("enemies"):
		enemies = _place_enemies(params["enemies"], tiles, size)
	
	# Размещаем объекты
	var objects = []
	if params.has("objects"):
		objects = _place_objects(params["objects"], tiles, size)
	
	# Размещаем NPC
	var npcs = []
	if params.has("npcs"):
		npcs = _place_npcs(params["npcs"], tiles, size)
	
	# Создаём выходы (двери)
	var exits = []
	if params.has("exits"):
		exits = _create_exits(params["exits"], tiles, size)
	
	return {
		"size": size,
		"biome": biome,
		"tiles": _tiles_to_array(tiles),
		"heights": heights,
		"enemies": enemies,
		"objects": objects,
		"npcs": npcs,
		"exits": exits,
		"player_start": params.get("player_start", [size/2, size/2]),
		"location_name": params.get("location_name", "Неизвестная локация")
	}

# Конвертация TileType в строки для Godot
static func _tiles_to_array(tiles: Array) -> Array:
	var result = []
	for x in range(tiles.size()):
		result.append([])
		for y in range(tiles[x].size()):
			match tiles[x][y]:
				TileType.FLOOR: result[x].append("floor")
				TileType.WALL: result[x].append("wall")
				TileType.GRASS: result[x].append("grass")
				TileType.STONE: result[x].append("stone")
				TileType.DIRT: result[x].append("dirt")
				TileType.WATER: result[x].append("water")
	return result

# Применение периметральных стен
static func _apply_perimeter_walls(tiles: Array, size: int, thickness: int = 1):
	for t in range(thickness):
		for x in range(t, size - t):
			tiles[x][t] = TileType.WALL
			tiles[x][size - 1 - t] = TileType.WALL
		for y in range(t, size - t):
			tiles[t][y] = TileType.WALL
			tiles[size - 1 - t][y] = TileType.WALL

# Подземелье (простое)
static func _apply_dungeon_biome(tiles: Array, size: int):
	for x in range(size):
		for y in range(size):
			tiles[x][y] = TileType.STONE

# Лес
static func _apply_forest_biome(tiles: Array, size: int):
	for x in range(size):
		for y in range(size):
			tiles[x][y] = TileType.GRASS
			if randf() < 0.05:
				tiles[x][y] = TileType.STONE

# Горы (с высотами)
static func _apply_mountain_biome(tiles: Array, heights: Array, size: int):
	for x in range(size):
		for y in range(size):
			var h = sin(x * 0.3) * cos(y * 0.3) + randf() * 0.5
			heights[x][y] = int(h * 4)
			if heights[x][y] < 1:
				tiles[x][y] = TileType.GRASS
			elif heights[x][y] < 3:
				tiles[x][y] = TileType.DIRT
			else:
				tiles[x][y] = TileType.STONE

# Пещера (создаём полости)
static func _apply_cave_biome(tiles: Array, size: int):
	for x in range(size):
		for y in range(size):
			tiles[x][y] = TileType.WALL
	
	for i in range(5):
		var cx = randi() % size
		var cy = randi() % size
		var radius = randi() % 3 + 2
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var nx = cx + dx
				var ny = cy + dy
				if nx >= 0 and nx < size and ny >= 0 and ny < size:
					if dx*dx + dy*dy <= radius*radius:
						tiles[nx][ny] = TileType.STONE

# Создание комнаты
static func _create_room(tiles: Array, room: Dictionary, size: int):
	var x = room.get("x", 0)
	var y = room.get("y", 0)
	var w = room.get("width", 4)
	var h = room.get("height", 4)
	
	for ix in range(max(0, x), min(x + w, size)):
		for iy in range(max(0, y), min(y + h, size)):
			tiles[ix][iy] = TileType.FLOOR

# Создание коридора
static func _create_corridor(tiles: Array, corridor: Dictionary, size: int):
	var from_x = corridor.get("from")[0]
	var from_y = corridor.get("from")[1]
	var to_x = corridor.get("to")[0]
	var to_y = corridor.get("to")[1]
	var width = corridor.get("width", 2)
	
	if from_x == to_x:
		for y in range(min(from_y, to_y), max(from_y, to_y) + 1):
			for w in range(-width/2, width/2 + 1):
				var nx = from_x + w
				if nx >= 0 and nx < size:
					tiles[nx][y] = TileType.FLOOR
	elif from_y == to_y:
		for x in range(min(from_x, to_x), max(from_x, to_x) + 1):
			for w in range(-width/2, width/2 + 1):
				var ny = from_y + w
				if ny >= 0 and ny < size:
					tiles[x][ny] = TileType.FLOOR

# Применение особенности
static func _apply_feature(tiles: Array, heights: Array, feature: Dictionary, size: int):
	match feature.get("type"):
		"water":
			var x = feature.get("x", 0)
			var y = feature.get("y", 0)
			var radius = feature.get("radius", 2)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < size and ny >= 0 and ny < size:
						if dx*dx + dy*dy <= radius*radius:
							tiles[nx][ny] = TileType.WATER
		
		"stone_patch":
			var x = feature.get("x", 0)
			var y = feature.get("y", 0)
			var radius = feature.get("radius", 1)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < size and ny >= 0 and ny < size:
						tiles[nx][ny] = TileType.STONE
		
		"table":
			var x = feature.get("x", 0)
			var y = feature.get("y", 0)
			for dx in range(2):
				for dy in range(2):
					var nx = x + dx
					var ny = y + dy
					if nx < size and ny < size:
						tiles[nx][ny] = TileType.FLOOR

# Размещение врагов
static func _place_enemies(enemy_configs: Array, tiles: Array, size: int) -> Array:
	var enemies = []
	var available_cells = []
	
	for x in range(size):
		for y in range(size):
			if tiles[x][y] != TileType.WALL and tiles[x][y] != TileType.WATER:
				available_cells.append([x, y])
	
	available_cells.shuffle()
	
	var index = 0
	for config in enemy_configs:
		var count = config.get("count", 1)
		var enemy_type = config.get("type", "goblin")
		
		for i in range(count):
			if index < available_cells.size():
				var pos = available_cells[index]
				enemies.append({
					"name": _get_enemy_name(enemy_type),
					"x": pos[0],
					"y": pos[1],
					"hp": _get_enemy_hp(enemy_type),
					"ac": _get_enemy_ac(enemy_type),
					"attack_bonus": _get_enemy_attack(enemy_type),
					"damage_dice": _get_enemy_damage(enemy_type)
				})
				index += 1
	
	return enemies

# Размещение объектов
static func _place_objects(object_configs: Array, tiles: Array, size: int) -> Array:
	var objects = []
	var available_cells = []
	
	for x in range(size):
		for y in range(size):
			if tiles[x][y] != TileType.WALL and tiles[x][y] != TileType.WATER:
				available_cells.append([x, y])
	
	available_cells.shuffle()
	
	var index = 0
	for config in object_configs:
		var count = config.get("count", 1)
		var obj_type = config.get("type", "chest")
		
		for i in range(count):
			if index < available_cells.size():
				var pos = available_cells[index]
				objects.append({
					"type": obj_type,
					"x": pos[0],
					"y": pos[1]
				})
				index += 1
	
	return objects

# Размещение NPC
static func _place_npcs(npc_configs: Array, tiles: Array, size: int) -> Array:
	var npcs = []
	var available_cells = []
	
	for x in range(size):
		for y in range(size):
			if tiles[x][y] != TileType.WALL and tiles[x][y] != TileType.WATER:
				available_cells.append([x, y])
	
	available_cells.shuffle()
	
	var index = 0
	for config in npc_configs:
		var count = config.get("count", 1)
		var npc_type = config.get("type", "villager")
		
		for i in range(count):
			if index < available_cells.size():
				var pos = available_cells[index]
				npcs.append({
					"name": _get_npc_name(npc_type),
					"x": pos[0],
					"y": pos[1],
					"type": npc_type,
					"dialogue": config.get("dialogue", "Привет, путник!")
				})
				index += 1
	
	return npcs

# Создание выходов (дверей)
static func _create_exits(exit_configs: Array, tiles: Array, size: int) -> Array:
	var exits = []
	if not exit_configs is Array:
		return exits
	
	for config in exit_configs:
		if config is Dictionary:
			var x = config.get("x", -1)
			var y = config.get("y", -1)
			if x == -1 or y == -1:
				var positions = _find_edge_positions(tiles, size)
				if positions.size() > 0:
					var pos = positions[randi() % positions.size()]
					x = pos[0]
					y = pos[1]
			exits.append({"x": x, "y": y, "description": config.get("description", "Дверь")})
			if x >= 0 and x < size and y >= 0 and y < size:
				tiles[x][y] = TileType.FLOOR
		else:
			print("Предупреждение: неверный формат выхода:", config)
	return exits
	
static func _find_edge_positions(tiles: Array, size: int) -> Array:
	var positions = []
	for x in range(size):
		if tiles[x][0] != TileType.WALL:
			positions.append([x, 0])
		if tiles[x][size-1] != TileType.WALL:
			positions.append([x, size-1])
	for y in range(size):
		if tiles[0][y] != TileType.WALL:
			positions.append([0, y])
		if tiles[size-1][y] != TileType.WALL:
			positions.append([size-1, y])
	return positions

# Вспомогательные функции
static func _get_enemy_name(type: String) -> String:
	match type:
		"skeleton": return "Скелет"
		"goblin": return "Гоблин"
		"orc": return "Орк"
		"zombie": return "Зомби"
		"spider": return "Паук"
		"rat": return "Крыса"
		_: return "Враг"

static func _get_enemy_hp(type: String) -> int:
	match type:
		"skeleton": return 10
		"goblin": return 8
		"orc": return 15
		"zombie": return 12
		"spider": return 6
		"rat": return 4
		_: return 10

static func _get_enemy_ac(type: String) -> int:
	match type:
		"skeleton": return 12
		"goblin": return 10
		"orc": return 14
		"zombie": return 8
		"spider": return 12
		"rat": return 10
		_: return 12

static func _get_enemy_attack(type: String) -> int:
	match type:
		"skeleton": return 3
		"goblin": return 2
		"orc": return 5
		"zombie": return 2
		"spider": return 3
		"rat": return 1
		_: return 3

static func _get_enemy_damage(type: String) -> String:
	match type:
		"skeleton": return "1d6+2"
		"goblin": return "1d6+1"
		"orc": return "1d8+3"
		"zombie": return "1d6+1"
		"spider": return "1d4+1"
		"rat": return "1d4"
		_: return "1d6+2"

static func _get_npc_name(type: String) -> String:
	match type:
		"villager": return "Житель"
		"guard": return "Стражник"
		"merchant": return "Торговец"
		"innkeeper": return "Трактирщик"
		_: return "Житель"
