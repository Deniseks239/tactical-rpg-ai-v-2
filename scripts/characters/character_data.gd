extends Resource
class_name CharacterData

@export var id: String = ""
@export var character_name: String = ""  # Переименуем, чтобы не конфликтовать с Node.name
@export var class_type: String = ""
@export var race: String = ""
@export var level: int = 1
@export var hp: int = 20
@export var max_hp: int = 20
@export var ac: int = 15
@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10
@export var inventory: Array[String] = []
@export var experience: int = 0

func save() -> String:
	var save_path = "user://characters/" + id + ".tres"
	var error = ResourceSaver.save(self, save_path)
	if error == OK:
		print("Персонаж сохранён: ", save_path)
		return save_path
	else:
		print("Ошибка сохранения: ", error)
		return ""

static func load_character(character_id: String) -> CharacterData:
	var path = "user://characters/" + character_id + ".tres"
	if ResourceLoader.exists(path):
		return load(path)
	return null

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": character_name,
		"class": class_type,
		"race": race,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"ac": ac,
		"inventory": inventory
	}
