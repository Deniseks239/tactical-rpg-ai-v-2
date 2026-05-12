extends Node
class_name LocationManager

var current_location: LocationData
var locations: Dictionary = {}  # id -> LocationData
# Словарь для карты мира: ключ - location_id, значение - { "tiles": [], "doors": {}, "connections": [] }
var world_map_data: Dictionary = {}
const LocationParser = preload("res://scripts/game/location_parser.gd")

func _ready():
	# Получаем путь сохранения от менеджера кампании
	var campaign_mgr = _get_campaign_manager()
	if campaign_mgr and campaign_mgr.has_method("get_current_save_path"):
		var campaign_path = campaign_mgr.get_current_save_path()
		if not campaign_path.is_empty():
			var loc_path = campaign_path + "/locations"
			DirAccess.make_dir_recursive_absolute(loc_path)
			LocationData.base_save_path = loc_path + "/"
			print("LocationManager: путь сохранения локаций: ", LocationData.base_save_path)
			return
	
	# Fallback — старый путь
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("locations"):
		dir.make_dir("locations")
	LocationData.base_save_path = "user://locations/"

func generate_location(description: String, additional_params: Dictionary = {}) -> LocationData:
	# 1. Парсим описание в параметры для процедурной генерации
	var params = LocationParser.parse_location_description(description)
	
	# 2. Добавляем обратный выход В ПАРАМЕТРЫ (до генерации карты)
	if additional_params.has("return_location_id") and additional_params["return_location_id"] != "":
		var return_door = {
			"x": additional_params.get("return_door_x", 0),
			"y": additional_params.get("return_door_y", 0),
			"description": "Обратный проход в " + additional_params.get("previous_location", "предыдущую локацию"),
			"target_location_id": additional_params["return_location_id"]
		}
		# Добавляем выход прямо в параметры для процедурной генерации
		params["exits"].append(return_door)
		print("LocationManager: Добавлен обратный выход в параметры генерации")
	
	# 3. Создаём объект локации
	var location = LocationData.new()
	location.id = params.get("id", "loc_" + str(randi()))
	location.name = params.get("location_name", "Неизвестная локация")
	location.description = params.get("description", description)
	location.parent_location_id = params.get("parent_location_id", "")
	location.door_id = params.get("door_id", "")
	
	# 4. Передаём параметры в процедурную генерацию карты
	var map_data = ProceduralMap.generate(params)
	location.tiles = map_data.get("tiles", [])
	location.heights = map_data.get("heights", [])
	location.enemies = map_data.get("enemies", [])
	location.npcs = map_data.get("npcs", [])
	location.objects = map_data.get("objects", [])
	location.exits = map_data.get("exits", [])
	location.player_start_x = map_data.get("player_start", [8, 8])[0]
	location.player_start_y = map_data.get("player_start", [8, 8])[1]
	location.width = map_data.get("size", 16)
	location.height = map_data.get("size", 16)
	
	# 5. Сохраняем локацию
	locations[location.id] = location
	location.save()
	
	# 6. Применяем локацию
	set_current_location(location, Vector2i(-1, -1))
	save_current_location_to_world_map()
	# 7. Обновляем дверь в родительской локации, чтобы она знала ID новой локации
	if additional_params.has("return_location_id") and additional_params["return_location_id"] != "":
		var parent_location_id = additional_params["return_location_id"]
		var parent_location = load_location(parent_location_id)
		if parent_location:
			var door_x = additional_params.get("return_door_x", -1)
			var door_y = additional_params.get("return_door_y", -1)
			# Ищем дверь в родительской локации и обновляем её target_location_id
			for exit_data in parent_location.exits:
				# Дверь могла быть на соседней клетке (обратная), но нам нужна та, через которую вошли
				# Она находится на позиции, переданной как return_door_x/y
				if exit_data.get("x") == door_x and exit_data.get("y") == door_y:
					exit_data["target_location_id"] = location.id
					print("LocationManager: Обновлена дверь в родительской локации на позиции ", door_x, ",", door_y, " -> target_location_id = ", location.id)
					break
			parent_location.save()
			
	print("LocationManager: Новая локация сгенерирована из описания: ", location.name)
	var gc = Engine.get_main_loop().root.get_node("GameControllerAuto")
	if gc and gc.has_method("_hide_loading_screen"):
		gc._hide_loading_screen()
		print("LocationManager: Экран загрузки скрыт")
	return location

func get_or_create_location(location_id: String, description: String = "", additional_params: Dictionary = {}) -> LocationData:
	print("LocationManager: get_or_create_location для ID: ", location_id)
	
	# 1. Пытаемся загрузить существующую локацию
	var existing = load_location(location_id)
	if existing:
		print("LocationManager: Локация уже существует, загружаем: ", existing.name)
		# Обновляем target_location_id из структуры кампании
		#_update_door_targets_from_campaign(existing)
		# Обновляем обратную дверь, если нужно
		if additional_params.has("return_location_id") and additional_params["return_location_id"] != "":
			_update_return_door(existing, additional_params)
		set_current_location(existing, Vector2i(-1, -1))
		save_current_location_to_world_map()
		return existing
	
	# 2. Проверяем структуру кампании
	var campaign_mgr = _get_campaign_manager()
	if campaign_mgr and campaign_mgr.has_campaign():
		var loc_info = campaign_mgr.get_location_info(location_id)
		if not loc_info.is_empty():
			description = loc_info.get("description", description)
			print("LocationManager: Используем описание из кампании для ", location_id)
	
	# 3. Если нет описания — запрашиваем у ИИ
	if description.is_empty():
		print("LocationManager: WARNING — нет описания для генерации локации ", location_id)
		description = "Тёмное помещение с каменными стенами."
	
	# 4. Генерируем новую локацию
	var params = LocationParser.parse_location_description(description)
	params["id"] = location_id  # Принудительно задаём ID из структуры
	# Добавляем NPC из структуры кампании для стартовой локации
	if campaign_mgr and campaign_mgr.has_campaign():
		var start_loc_id = campaign_mgr.campaign_data.get("world_structure", {}).get("starting_location", {}).get("id", "")
		if start_loc_id == location_id:
			var all_npcs = campaign_mgr.campaign_data.get("npcs", [])
			for npc in all_npcs:
				# Ищем свободную клетку для NPC
				var nx = randi_range(1, params.get("width", 8) - 2)
				var ny = randi_range(1, params.get("height", 8) - 2)
				params["npcs"].append({
					"name": npc.get("name", "NPC"),
					"role": npc.get("role", ""),
					"x": nx,
					"y": ny,
					"npc_id": npc.get("id", "")
				})
			print("LocationManager: добавлены NPC из кампании в стартовую локацию")
	# Добавляем сюжетные двери из структуры мира
	if campaign_mgr and campaign_mgr.has_campaign():
		var next_locations = campaign_mgr.get_next_locations(location_id)
		for next_id in next_locations:
			var next_info = campaign_mgr.get_location_info(next_id)
			if not next_info.is_empty():
				var map_size = 8 
				var exit_data = {
					"x": min(7, map_size - 1),
					"y": min(4, map_size - 1),
					"description": next_info.get("connection_description", "Проход в " + next_info.get("name", "?")) if not next_info.is_empty() else "Проход",
					"target_location_id": next_id
				}
				params["exits"].append(exit_data)
				print("LocationManager: Добавлен сюжетный выход в ", next_id)
	
	# Добавляем обратный выход
	var map_width = params.get("width", 8)
	var map_height = params.get("height", 8)
	if additional_params.has("return_location_id") and additional_params["return_location_id"] != "":
		var ret_x = clamp(additional_params.get("return_door_x", 0), 0, map_width - 1)
		var ret_y = clamp(additional_params.get("return_door_y", 0), 0, map_height - 1)
		var return_door = {
			"x": ret_x,
			"y": ret_y,
			"description": "Обратный проход в " + additional_params.get("previous_location", "предыдущую локацию"),
			"target_location_id": additional_params["return_location_id"]
		}
		# Добавляем в params, чтобы передать в генератор
		if not "exits" in params:
			params["exits"] = []
		params["exits"].append(return_door)
	# Считаем количество выходов, которые не являются обратными (у них пустой target_location_id)
	var forward_exits = 0
	for e in params.get("exits", []):
		if e.get("target_location_id", "") == "":
			forward_exits += 1
	
	# Если нет ни одной двери вперёд – добавляем
	if forward_exits == 0:
		# Получаем координаты обратной двери, чтобы не поставить новую на то же место
		var back_door = params["exits"][0]
		var back_x = back_door.get("x", -1)
		var back_y = back_door.get("y", -1)
		
		var door_pos = _get_random_door_position(map_width, map_height, params.get("location_type", "default"))
		# Если случайно попали на ту же клетку – повторяем, пока не разойдутся
		while door_pos.x == back_x and door_pos.y == back_y:
			door_pos = _get_random_door_position(map_width, map_height, params.get("location_type", "default"))
		
		params["exits"].append({
			"x": door_pos.x,
			"y": door_pos.y,
			"description": "Тёмный проход вперёд",
			"target_location_id": ""
		})
		print("LocationManager: добавлен выход вперёд на (", door_pos.x, ",", door_pos.y, ")")
	
	var location = LocationData.new()
	location.id = location_id
	location.name = params.get("location_name", "Неизвестная локация")
	location.description = description
	location.parent_location_id = params.get("parent_location_id", "")
	location.door_id = params.get("door_id", "")
	
	var map_data = ProceduralMap.generate(params)
	location.tiles = map_data.get("tiles", [])
	location.heights = map_data.get("heights", [])
	location.enemies = map_data.get("enemies", [])
	location.npcs = map_data.get("npcs", [])
	location.objects = map_data.get("objects", [])
	
	# === НАДЁЖНАЯ ПРИВЯЗКА target_location_id ПО КООРДИНАТАМ ===
	# 1. Сначала берём все выходы, которые сгенерировала карта
	var generated_exits = map_data.get("exits", [])
	
	# 2. Проходим по всем сюжетным дверям из params
	for param_exit in params.get("exits", []):
		if not param_exit.has("target_location_id") or param_exit["target_location_id"] == "":
			continue  # это обратная дверь или дверь без ID, пропускаем
			
		# 3. Ищем дверь с такими же координатами среди сгенерированных
		for gen_exit in generated_exits:
			if gen_exit.get("x") == param_exit.get("x") and gen_exit.get("y") == param_exit.get("y"):
				gen_exit["target_location_id"] = param_exit["target_location_id"]
				print("LocationManager: Привязан target_location_id=", param_exit["target_location_id"], " к двери на (", param_exit["x"], ",", param_exit["y"], ")")
				break
	# ===============================================================
	location.exits = generated_exits
	location.player_start_x = map_data.get("player_start", [8, 8])[0]
	location.player_start_y = map_data.get("player_start", [8, 8])[1]
	location.width = map_data.get("size", 16)
	location.height = map_data.get("size", 16)

	locations[location_id] = location
	location.save()

	set_current_location(location, Vector2i(-1, -1))
	# Обновляем дверь в родительской локации по ключу
	var gc = Engine.get_main_loop().root.get_node("GameControllerAuto")
	if gc and gc.pending_parent_door_key != "" and gc.pending_parent_location_id != "":
		var parent_loc = load_location(gc.pending_parent_location_id)
		if parent_loc:
			# Ищем дверь по координатному ключу в grid_state
			var door_key = gc.pending_parent_door_key
			var door_x = int(door_key.split("_")[0])
			var door_y = int(door_key.split("_")[1])
			for exit_data in parent_loc.exits:
				if exit_data.get("x") == door_x and exit_data.get("y") == door_y:
					exit_data["target_location_id"] = location.id
					parent_loc.save()
					print("LocationManager: обновлён target_location_id у двери (", door_x, ",", door_y, ") в ", gc.pending_parent_location_id, " -> ", location.id)
					break
		# Очищаем временные переменные
		gc.pending_parent_door_key = ""
		gc.pending_parent_location_id = ""

	# Обновляем кэш кампании для следующих переходов
	if campaign_mgr and campaign_mgr.has_campaign():
		var next_locs = campaign_mgr.get_next_locations(location_id)
		var door_index = 0
		for exit_data in location.exits:
			if exit_data.get("target_location_id", "") != "":
				continue
			if door_index < next_locs.size():
				exit_data["target_location_id"] = next_locs[door_index]
				door_index += 1
		location.save()
	#_update_door_targets_from_campaign(location)
	print("LocationManager: Новая локация создана: ", location.name, " (ID: ", location_id, ")")
	return location

# Вспомогательный метод для обновления обратной двери
func _update_return_door(location: LocationData, additional_params: Dictionary):
	var parent_id = additional_params.get("return_location_id", "")
	var door_x = additional_params.get("return_door_x", -1)
	var door_y = additional_params.get("return_door_y", -1)
	
	var parent = load_location(parent_id)
	if parent:
		for exit_data in parent.exits:
			if exit_data.get("x") == door_x and exit_data.get("y") == door_y:
				exit_data["target_location_id"] = location.id
				parent.save()
				print("LocationManager: Обновлена дверь в ", parent_id)
func _update_parent_door_target(parent_loc_id: String, door_x: int, door_y: int, new_loc_id: String):
	var parent_loc = load_location(parent_loc_id)
	if parent_loc:
		for exit_data in parent_loc.exits:
			if exit_data.get("x") == door_x and exit_data.get("y") == door_y:
				exit_data["target_location_id"] = new_loc_id
				print("LocationManager: обновлена дверь в ", parent_loc_id, " на (", door_x, ",", door_y, ") -> ", new_loc_id)
				parent_loc.save()
				break

# Получение CampaignManager
func _get_campaign_manager():
	var root = Engine.get_main_loop().root
	if root.has_node("CampaignManagerAuto"):
		return root.get_node("CampaignManagerAuto")
	return null
func load_location(location_id: String) -> LocationData:
	if locations.has(location_id):
		return locations[location_id]
	
	var loaded = LocationData.load_location(location_id)
	if loaded:
		locations[location_id] = loaded
		return loaded
	return null

func set_current_location(location: LocationData, entry_door_pos: Vector2i = Vector2i(-1, -1)):
	current_location = location
	_apply_location_to_game(location, entry_door_pos)

func _apply_location_to_game(location: LocationData, entry_door_pos: Vector2i = Vector2i(-1, -1)):
	var game_controller = get_node("/root/GameControllerAuto")
	if game_controller:
		for unit_id in game_controller.combat_state.units.keys():
			if unit_id != "player_1":
				game_controller.grid_state.remove_unit(unit_id)
				game_controller.combat_state.remove_unit(unit_id)
		game_controller._apply_map_data({
			"size": location.width,
			"tiles": location.tiles,
			"heights": location.heights,
			"enemies": location.enemies,
			"npcs": location.npcs,
			"objects": location.objects,
			"exits": location.exits,
			"player_start": [location.player_start_x, location.player_start_y],
			"location_name": location.name
		}, entry_door_pos)
		
		# Обновляем сетку
		game_controller._refresh_grid()
		
		# Добавляем NPC как юнитов (не врагов)
		for npc in location.npcs:
			var unit_id = "npc_" + str(randi())
			var pos_key = str(npc.x) + "_" + str(npc.y)
			game_controller.grid_state.set_unit(unit_id, npc.name, "npc", npc.x, npc.y)
			# Сохраняем npc_id, чтобы диалог мог найти его в кампании
			if npc.has("npc_id") and game_controller.grid_state.units.has(pos_key):
				game_controller.grid_state.units[pos_key]["npc_id"] = npc["npc_id"]
func _update_door_targets_from_campaign(location: LocationData):
	var campaign_mgr = _get_campaign_manager()
	if not campaign_mgr or not campaign_mgr.has_campaign():
		print("LocationManager: Нет CampaignManager или кампании, двери не обновлены")
		return
	
	var next_locations = campaign_mgr.get_next_locations(location.id)
	print("LocationManager: обновляю target_location_id для ", location.id, " -> ", next_locations)
	
	# Удаляем ВСЕ старые двери, у которых нет target_location_id или он пустой
	var i = location.exits.size() - 1
	while i >= 0:
		if location.exits[i].get("target_location_id", "") == "":
			location.exits.remove_at(i)
		i -= 1
	
	# Добавляем новые сюжетные выходы в конец массива
	for next_id in next_locations:
		var next_info = campaign_mgr.get_location_info(next_id)
		if not next_info.is_empty():
			var exit_data = {
				"x": min(7, location.width - 1),
				"y": min(4, location.height - 1),
				"description": next_info.get("connection_description", "Проход в " + next_info.get("name", "?")),
				"target_location_id": next_id
			}
			location.exits.append(exit_data)
	
	# Сохраняем обновлённую локацию
	location.save()
	locations[location.id] = location
func save_current_location_to_world_map():
	if not current_location:
		return
	
	var loc_id = current_location.id
	if world_map_data.has(loc_id):
		return  # уже сохраняли
	
	# Создаём мини-карту: сжимаем tiles до 2D массива строк
	var mini_tiles = []
	for x in range(current_location.width):
		var row = []
		for y in range(current_location.height):
			var tile_str = current_location.tiles[x][y]
			if tile_str is String:
				row.append(_tile_type_to_char(tile_str))
			else:
				row.append(_tile_type_to_char(tile_str.get("type", GridState.TileType.FLOOR)))
		mini_tiles.append(row)
	
	# Собираем информацию о дверях и их направлениях
	var doors_info = {}
	for exit_data in current_location.exits:
		var door_key = str(exit_data.get("x")) + "_" + str(exit_data.get("y"))
		doors_info[door_key] = {
			"target_location_id": exit_data.get("target_location_id", ""),
			"description": exit_data.get("description", "Дверь")
		}
	
	world_map_data[loc_id] = {
		"tiles": mini_tiles,
		"doors": doors_info,
		"connections": [],  # сюда будем добавлять связи при переходах
		"name": current_location.name
	}
	print("LocationManager: мини-карта сохранена для ", loc_id)
func _tile_type_to_char(tile_type_str: String) -> String:
	match tile_type_str:
		"wall": return "W"
		"floor": return "."
		"grass": return "G"
		"dirt": return "D"
		"water": return "~"
		"table": return "T"
		"chair": return "C"
		_: return "."
func add_world_connection(from_id: String, to_id: String, from_door_x: int, from_door_y: int, to_door_x: int, to_door_y: int):
	if not world_map_data.has(from_id) or not world_map_data.has(to_id):
		return
	
	# Проверяем, нет ли уже такой связи
	for conn in world_map_data[from_id]["connections"]:
		if conn["target_id"] == to_id:
			return
	
	world_map_data[from_id]["connections"].append({
		"target_id": to_id,
		"door_x": from_door_x,
		"door_y": from_door_y
	})
	world_map_data[to_id]["connections"].append({
		"target_id": from_id,
		"door_x": to_door_x,
		"door_y": to_door_y
	})
	print("LocationManager: связь добавлена ", from_id, " <-> ", to_id)
func _get_random_door_position(width: int, height: int, location_type: String = "default") -> Vector2i:
	# Открытые локации — дверь внутри
	if location_type in ["city", "town", "forest", "road", "park", "garden", "plaza", "market"]:
		return _get_random_door_position_inside(width, height)
	# Закрытые или неизвестные — дверь на границе
	return _get_random_door_position_on_edge(width, height)

func _get_random_door_position_on_edge(width: int, height: int) -> Vector2i:
	var side = randi_range(0, 3)
	var x = 0
	var y = 0
	match side:
		0: # Север
			x = randi_range(1, width - 2)
			y = 0
		1: # Восток
			x = width - 1
			y = randi_range(1, height - 2)
		2: # Юг
			x = randi_range(1, width - 2)
			y = height - 1
		3: # Запад
			x = 0
			y = randi_range(1, height - 2)
	return Vector2i(x, y)

func _get_random_door_position_inside(width: int, height: int) -> Vector2i:
	# Пытаемся найти свободную клетку (не край, не стена) 10 раз
	for attempt in 10:
		var x = randi_range(1, width - 2)
		var y = randi_range(1, height - 2)
		if current_location and current_location.tiles.size() > x and current_location.tiles[x].size() > y:
			var tile_type = current_location.tiles[x][y]
			# Если клетка — стена, ищем дальше
			if tile_type == "wall":
				continue
		return Vector2i(x, y)
	# Фоллбэк — центр карты
	return Vector2i(width / 2, height / 2)
