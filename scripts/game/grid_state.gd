extends Resource
class_name GridState

enum TileType { FLOOR,
	WALL,
	TABLE,
	CHAIR,
	DOOR,
	TRAP,
	CHEST,
	STAIRS,
	GRASS,      # трава
	STONE,      # каменный пол
	DIRT,       # земля
	WATER,       # вода (непроходимо, например)
	ROAD,           # дорога/улица
	HOUSE_WALL,     # стена дома
	HOUSE_DOOR,     # дверь дома
	SHOP_COUNTER,   # прилавок
	TAVERN_BAR,     # барная стойка
	FORGE,          # горн
	CASTLE_WALL,    # стена замка
	CASTLE_GATE,    # ворота замка
	PARK,           # парк/сад
	FOUNTAIN,       # фонтан
	STATUE          # статуя
}

@export var width: int = 8
@export var height: int = 8
@export var cell_size: int = 64
var doors: Dictionary = {}  # ключ "x_y" -> DoorData
var tiles: Array = []
var units: Dictionary = {}  # "x_y" -> {"id": String, "name": String, "type": String}
var objects: Dictionary = {}

func initialize():
	tiles.clear()
	for x in range(width):
		tiles.append([])
		for y in range(height):
			tiles[x].append({"type": TileType.FLOOR, "metadata": {}})

func is_walkable(x: int, y: int, unit_id: String = "") -> bool:
	if x < 0 or x >= width or y < 0 or y >= height:
		return false
	
	var tile_type = tiles[x][y]["type"]
	
	# Непроходимые типы тайлов
	match tile_type:
		TileType.WALL, TileType.TABLE, TileType.CHAIR, TileType.SHOP_COUNTER, \
		TileType.TAVERN_BAR, TileType.FORGE, TileType.HOUSE_WALL, \
		TileType.CASTLE_WALL, TileType.FOUNTAIN, TileType.STATUE:
			return false
	
	# Проверка на двери дома — они проходимы
	if tile_type == TileType.HOUSE_DOOR or tile_type == TileType.CASTLE_GATE:
		pass  # проходимы
	
	var pos_key = str(x) + "_" + str(y)
	if units.has(pos_key) and units[pos_key]["id"] != unit_id:
		return false
	return true

func get_movement_cost(x: int, y: int) -> int:
	var tile = tiles[x][y]
	match tile["type"]:
		TileType.CHAIR, TileType.TABLE:
			return 2
		_:
			return 1

func set_unit(unit_id: String, unit_name: String, unit_type: String, x: int, y: int):
	var pos_key = str(x) + "_" + str(y)
	units[pos_key] = {"id": unit_id, "name": unit_name, "type": unit_type}

func remove_unit(unit_id: String):
	for pos_key in units.keys():
		if units[pos_key]["id"] == unit_id:
			units.erase(pos_key)
			break

func get_unit_position(unit_id: String) -> Vector2i:
	for pos_key in units.keys():
		if units[pos_key]["id"] == unit_id:
			var coords = pos_key.split("_")
			return Vector2i(int(coords[0]), int(coords[1]))
	return Vector2i(-1, -1)

func to_dict() -> Dictionary:
	var grid_data = []
	for x in range(width):
		var row = []
		for y in range(height):
			var type_str = "floor"
			match tiles[x][y]["type"]:
				TileType.WALL: type_str = "wall"
				TileType.TABLE: type_str = "table"
				TileType.CHAIR: type_str = "chair"
				TileType.DOOR: type_str = "door"
				TileType.TRAP: type_str = "trap"
				TileType.CHEST: type_str = "chest"
				TileType.STAIRS: type_str = "stairs"
			row.append(type_str)
		grid_data.append(row)
	
	var units_data = {}
	for pos_key in units.keys():
		var u = units[pos_key]
		var coords = pos_key.split("_")
		units_data[pos_key] = {
			"name": u["name"],
			"type": u["type"],
			"x": int(coords[0]),
			"y": int(coords[1])
		}
	
	return {
		"width": width,
		"height": height,
		"grid": grid_data,
		"units": units_data
	}
