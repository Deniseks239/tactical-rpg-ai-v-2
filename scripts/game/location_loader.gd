extends Node
class_name LocationLoader

signal location_generated(location_data: LocationData)
signal location_generation_failed(error: String)

@onready var ai_client: AIClientOllama = $AIClientOllama
@onready var location_parser: LocationParser = $LocationParser
@onready var location_manager: LocationManager = $"../LocationManager"
@onready var game_controller: GameController = $"../GameController"

var current_generation_params: Dictionary = {}

func generate_location_async(params: Dictionary) -> void:
	current_generation_params = params
	
	# Прямой текст промпта без PromptTemplates
	var prompt = """
	Сгенерируй JSON-описание локации для пошаговой RPG.
	Тип локации: {location_type}
	Размер сетки: {size}x{size}
	Сложность: {difficulty}
	Дополнительный контекст: {context}
	
	Формат ответа должен быть строго JSON с полями:
	{{
		"location_name": "название",
		"biome": "лес/пещера/город/подземелье",
		"size": {size},
		"enemies": [{{"type": "гоблин", "count": 1}}],
		"exits": [{{"x": 0, "y": 0, "description": "выход"}}],
		"player_start": [4, 4],
		"description": "атмосферное описание"
	}}
	""".format({
		"location_type": params.get("location_type", "random"),
		"size": params.get("size", 8),
		"difficulty": params.get("difficulty", "normal"),
		"context": params.get("context", "")
	})
	
	ai_client.generate_async(prompt, _on_ai_response.bind(params))

func _on_ai_response(response: String, params: Dictionary) -> void:
	print("LocationLoader: Ответ AI получен, длина: ", response.length())
	var location_data = location_parser.parse_location_description(response)
	if location_data:
		location_data.id = _generate_location_id()
		location_data.generation_params = params
		_on_location_generated(location_data, params)
	else:
		location_generation_failed.emit("Не удалось распарсить ответ AI")
		printerr("LocationLoader: Парсинг локации провален")

func _on_location_generated(location_data: LocationData, params: Dictionary) -> void:
	var game_controller = get_node("/root/GameControllerAuto")
	if game_controller and game_controller.has_method("_hide_loading_screen"):
		game_controller._show_loading_screen("Мастер подземелий создаёт мир...")
	print("LocationLoader: _on_location_generated. Новая локация ID: ", location_data.id)
	
	location_manager.add_location(location_data)
	
	var previous_location_id = params.get("previous_location_id", "")
	var return_door_pos = params.get("return_door_position", Vector2i(-1, -1))
	var return_door_desc = params.get("return_door_description", "Обратный путь")
	
	print("  previous_location_id: ", previous_location_id)
	print("  return_door_position: ", return_door_pos)
	
	if previous_location_id != "" and return_door_pos != Vector2i(-1, -1):
		_add_return_door(location_data.id, previous_location_id, return_door_pos, return_door_desc)
	else:
		print("LocationLoader: previous_location_id пустой или позиция не задана, обратная дверь не создаётся")
	
	if game_controller:
		game_controller._on_new_location_ready(location_data.id)
	else:
		printerr("LocationLoader: game_controller не найден!")
	
	location_generated.emit(location_data)
	if game_controller and game_controller.has_method("_hide_loading_screen"):
		game_controller._hide_loading_screen()

func _add_return_door(location_id: String, previous_location_id: String, return_door_position: Vector2i, return_door_description: String = "Обратный путь") -> void:
	print("LocationLoader: _add_return_door вызван для локации ", location_id)
	print("  предыдущая локация: ", previous_location_id)
	print("  позиция двери: ", return_door_position)
	
	var location_data = location_manager.get_location(location_id)
	if not location_data:
		printerr("LocationLoader: Не удалось найти локацию ", location_id)
		return
	
	# Проверка занятости клетки
	var cell_occupied = false
	for door in location_data.doors:
		if door.position == return_door_position:
			cell_occupied = true
			break
	if not cell_occupied:
		for enemy in location_data.enemies:
			if enemy.position == return_door_position:
				cell_occupied = true
				break
	if not cell_occupied and location_data.player_spawn_position == return_door_position:
		cell_occupied = true
	
	if cell_occupied:
		printerr("LocationLoader: Клетка ", return_door_position, " занята, обратная дверь не создана")
		return
	
	# Создаём дверь как Dictionary (вместо DoorData)
	var door_dict = {
		"position": return_door_position,
		"description": return_door_description,
		"target_location_id": previous_location_id,
		"target_door_id": ""
	}
	print("LocationLoader: Создана обратная дверь: ", door_dict)
	
	# Добавляем дверь в данные локации (предполагаем, что location_data.doors - это массив Dictionary)
	location_data.doors.append(door_dict)
	print("LocationLoader: Обратная дверь добавлена в данные локации ", location_id)
	
	# Если локация активна, отображаем дверь
	if game_controller and game_controller.current_location_id == location_id:
		print("LocationLoader: Локация активна, добавляем дверь на сетку")
		# Преобразуем словарь в DoorData, если grid_manager.add_door() ожидает объект DoorData
		var door_obj = _dict_to_door(door_dict)
		game_controller.grid_manager.add_door(door_obj)
	else:
		print("LocationLoader: Локация не активна, дверь будет отображена при её загрузке")

# Вспомогательная функция для конвертации словаря в DoorData (если класс DoorData существует)
func _dict_to_door(dict: Dictionary):
	# Пытаемся создать DoorData, если класс доступен
	var door = null
	if Engine.has_singleton("DoorData") or ClassDB.class_exists("DoorData"):
		door = DoorData.new()
	else:
		# Если DoorData нет, создаём простой объект с теми же свойствами
		door = Resource.new()
		door.set_script(load("res://scripts/game/door_data.gd"))  # если есть файл door_data.gd
		# Если нет файла, придётся использовать Dictionary, но grid_manager.add_door() может ожидать объект
		# В этом случае нужно будет изменить grid_manager.gd, чтобы он принимал Dictionary
		# Пока оставим заглушку
		return dict
	
	door.position = dict["position"]
	door.description = dict["description"]
	door.target_location_id = dict["target_location_id"]
	door.target_door_id = dict["target_door_id"]
	return door

func _generate_location_id() -> String:
	return "loc_" + str(randi()).sha256_text().substr(0, 10)
