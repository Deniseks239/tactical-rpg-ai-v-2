extends Node
class_name CityGenerator

static func generate_city(params: Dictionary) -> Dictionary:
	var width = params.get("width", 48)
	var height = params.get("height", 48)
	var seed = params.get("seed", randi())
	seed(seed)
	
	var tiles = []
	var heights = []
	
	# Инициализация
	for x in range(width):
		tiles.append([])
		heights.append([])
		for y in range(height):
			tiles[x].append(GridState.TileType.ROAD)
			heights[x].append(0)
	
	# Генерация улиц
	_generate_streets(tiles, width, height, params.get("street_spacing", 8))
	
	# Генерация кварталов
	var districts = params.get("districts", ["residential", "residential", "market", "noble"])
	_generate_districts(tiles, width, height, districts)
	
	# Добавление особых зданий
	_add_landmarks(tiles, width, height)
	
	# Размещение врагов
	var enemies = _place_city_enemies(tiles, width, height, params.get("danger_level", 1))
	
	# Размещение NPC
	var npcs = _place_city_npcs(tiles, width, height, params.get("population", 50))
	
	# Выходы из города
	var exits = _create_city_exits(tiles, width, height)
	
	return {
		"size": width,
		"width": width,
		"height": height,
		"tiles": _tiles_to_string_array(tiles),
		"heights": heights,
		"enemies": enemies,
		"npcs": npcs,
		"exits": exits,
		"player_start": params.get("player_start", [width/2, height/2]),
		"location_name": params.get("location_name", "Город")
	}

static func _generate_streets(tiles: Array, width: int, height: int, spacing: int):
	for y in range(spacing, height, spacing):
		for x in range(width):
			tiles[x][y] = GridState.TileType.ROAD
	for x in range(spacing, width, spacing):
		for y in range(height):
			tiles[x][y] = GridState.TileType.ROAD
	
	var center_x = width / 2
	var center_y = height / 2
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var nx = center_x + dx
			var ny = center_y + dy
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				tiles[nx][ny] = GridState.TileType.ROAD
	if center_x >= 0 and center_x < width and center_y >= 0 and center_y < height:
		tiles[center_x][center_y] = GridState.TileType.FOUNTAIN

static func _generate_districts(tiles: Array, width: int, height: int, districts: Array):
	var district_width = width / 3
	var district_height = height / 3
	
	for i in range(min(districts.size(), 9)):
		var district_x = (i % 3) * district_width
		var district_y = (i / 3) * district_height
		var district_type = districts[i % districts.size()]
		
		for x in range(district_x, min(district_x + district_width, width)):
			for y in range(district_y, min(district_y + district_height, height)):
				if tiles[x][y] == GridState.TileType.ROAD:
					continue
				match district_type:
					"residential":
						tiles[x][y] = GridState.TileType.HOUSE_WALL
					"market":
						if randf() < 0.2:
							tiles[x][y] = GridState.TileType.SHOP_COUNTER
						else:
							tiles[x][y] = GridState.TileType.HOUSE_WALL
					"noble":
						tiles[x][y] = GridState.TileType.CASTLE_WALL
					"industrial":
						tiles[x][y] = GridState.TileType.FORGE
					"park":
						tiles[x][y] = GridState.TileType.PARK

static func _add_landmarks(tiles: Array, width: int, height: int):
	for attempt in range(100):
		var x = randi() % width
		var y = randi() % height
		if tiles[x][y] == GridState.TileType.HOUSE_WALL:
			tiles[x][y] = GridState.TileType.TAVERN_BAR
			break

static func _place_city_enemies(tiles: Array, width: int, height: int, danger_level: int) -> Array:
	var enemies = []
	if danger_level <= 0:
		return enemies
	var enemy_count = danger_level * 2
	for i in range(enemy_count):
		for attempt in range(50):
			var x = randi() % width
			var y = randi() % height
			if tiles[x][y] == GridState.TileType.ROAD:
				enemies.append({
					"name": "Стражник",
					"x": x, "y": y, "hp": 15, "max_hp": 15,
					"ac": 14, "attack_bonus": 4, "damage_dice": "1d8+2"
				})
				break
	return enemies

static func _place_city_npcs(tiles: Array, width: int, height: int, population: int) -> Array:
	var npcs = []
	var npc_count = min(population / 10, 30)
	var dialogues = ["Здравствуй, путник!", "Хороший сегодня день.", "Осторожнее, здесь опасно."]
	for i in range(npc_count):
		for attempt in range(50):
			var x = randi() % width
			var y = randi() % height
			if tiles[x][y] != GridState.TileType.ROAD and tiles[x][y] != GridState.TileType.HOUSE_WALL:
				npcs.append({
					"name": "Житель", "x": x, "y": y,
					"type": "citizen", "dialogue": dialogues[randi() % dialogues.size()]
				})
				break
	return npcs

static func _create_city_exits(tiles: Array, width: int, height: int) -> Array:
	var exits = []
	for x in range(width):
		if tiles[x][0] == GridState.TileType.ROAD:
			exits.append({"x": x, "y": 0, "description": "Северные ворота"})
			break
	for x in range(width):
		if tiles[x][height-1] == GridState.TileType.ROAD:
			exits.append({"x": x, "y": height-1, "description": "Южные ворота"})
			break
	return exits

static func _tiles_to_string_array(tiles: Array) -> Array:
	var result = []
	for x in range(tiles.size()):
		result.append([])
		for y in range(tiles[x].size()):
			match tiles[x][y]:
				GridState.TileType.ROAD: result[x].append("road")
				GridState.TileType.HOUSE_WALL: result[x].append("house_wall")
				GridState.TileType.SHOP_COUNTER: result[x].append("shop_counter")
				GridState.TileType.TAVERN_BAR: result[x].append("tavern_bar")
				GridState.TileType.FORGE: result[x].append("forge")
				GridState.TileType.CASTLE_WALL: result[x].append("castle_wall")
				GridState.TileType.PARK: result[x].append("park")
				GridState.TileType.FOUNTAIN: result[x].append("fountain")
				GridState.TileType.STATUE: result[x].append("statue")
				_: result[x].append("floor")
	return result
