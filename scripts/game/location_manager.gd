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

func generate_location(description: String) -> LocationData:
	# 1. Парсим описание в параметры для процедурной генерации
	var params = LocationParser.parse_location_description(description)
	
	# 2. Создаём объект локации
	var location = LocationData.new()
	location.id = params.get("id", "loc_" + str(randi()))
	location.name = params.get("location_name", "Неизвестная локация")
	location.description = params.get("description", description)
	location.parent_location_id = params.get("parent_location_id", "")
	location.door_id = params.get("door_id", "")
	
	# 3. Передаём параметры в процедурную генерацию карты
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
	
	# 4. Сохраняем локацию
	locations[location.id] = location
	location.save()
	
	# 5. ПРИМЕНЯЕМ ЛОКАЦИЮ (ВОТ ЭТО ВАЖНО!)
	set_current_location(location)
	
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

func set_current_location(location: LocationData):
	current_location = location
	_apply_location_to_game(location)

func _apply_location_to_game(location: LocationData):
	var game_controller = get_node("/root/GameControllerAuto")
	if game_controller:
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
		})
		
		# Обновляем сетку
		game_controller._refresh_grid()
		
		# Добавляем NPC как юнитов (не врагов)
		for npc in location.npcs:
			var npc_id = "npc_" + str(randi())
			game_controller.grid_state.set_unit(npc_id, npc.name, "npc", npc.x, npc.y)
			# NPC не добавляем в боевую систему
