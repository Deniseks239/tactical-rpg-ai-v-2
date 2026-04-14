extends Node
class_name LocationManager

var current_location: LocationData
var locations: Dictionary = {}  # id -> LocationData
const LocationParser = preload("res://scripts/game/location_parser.gd")

func _ready():
	# Создаём папку для сохранений, если её нет
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("locations"):
		dir.make_dir("locations")

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
	
	print("LocationManager: Новая локация сгенерирована из описания: ", location.name)
	return location

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
