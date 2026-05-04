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
	if additional_params.has("return_location_id") and additional_params["return_location_id"] != "":
		var return_door = {
			"x": additional_params.get("return_door_x", 0),
			"y": additional_params.get("return_door_y", 0),
			"description": "Обратный проход в " + additional_params.get("previous_location", "предыдущую локацию"),
			"target_location_id": additional_params["return_location_id"]
		}
		params["exits"].append(return_door)
	
	var location = LocationData.new()
	location.id = location_id
	location.name = params.get("location_name", "Неизвестная локация")
	location.description = description
	location.parent_location_id = params.get("parent_location_id", "")
	location.door_id = params.get("door_id", "")
	# Если парсер не создал ни одного выхода – добавляем стандартный
	if params.get("exits", []).is_empty():
		params["exits"] = [{
			"x": 7,
			"y": 4,
			"description": "Тёмный проход",
			"target_location_id": ""
		}]
		print("LocationManager: добавлен выход по умолчанию")
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
			var npc_id = "npc_" + str(randi())
			game_controller.grid_state.set_unit(npc_id, npc.name, "npc", npc.x, npc.y)
			# NPC не добавляем в боевую систему
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
			row.append(_tile_type_to_char(current_location.tiles[x][y]["type"]))
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
func _tile_type_to_char(tile_type) -> String:
	match tile_type:
		GridState.TileType.WALL: return "W"
		GridState.TileType.FLOOR: return "."
		GridState.TileType.GRASS: return "G"
		GridState.TileType.DIRT: return "D"
		GridState.TileType.WATER: return "~"
		GridState.TileType.TABLE: return "T"
		GridState.TileType.CHAIR: return "C"
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
