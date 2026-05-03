extends Resource
class_name LocationData

@export var id: String                    # уникальный ID локации
@export var name: String                  # название
@export var description: String           # описание от AI
@export var parent_location_id: String    # ID родительской локации
@export var door_id: String               # ID двери, через которую сюда вошли

# Данные карты
@export var width: int = 16
@export var height: int = 16
@export var tiles: Array = []             # 2D массив типов клеток
@export var heights: Array = []           # 2D массив высот

# Сущности
@export var enemies: Array = []           # враги
@export var npcs: Array = []              # мирные NPC
@export var objects: Array = []           # объекты (двери, сундуки)
@export var exits: Array = []             # выходы в другие локации

# Позиции
@export var player_start_x: int = 8
@export var player_start_y: int = 8
static var base_save_path: String = "user://locations/"

func save() -> String:
	var save_path = base_save_path + id + ".tres"
	var error = ResourceSaver.save(self, save_path)
	if error == OK:
		print("Локация сохранена: ", save_path)
		return save_path
	else:
		print("Ошибка сохранения: ", error)
		return ""

static func load_location(location_id: String) -> LocationData:
	var path = "user://locations/" + location_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path)
	return null
