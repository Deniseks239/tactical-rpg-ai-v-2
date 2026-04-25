extends Node
class_name GameController

signal game_message(text: String)

var grid_state: GridState
var combat_state: CombatState
var game_state: GameState
var ai_client: AIClientOllama
var is_waiting_for_ai: bool = false
var pending_action: String = ""
var game_over: bool = false
var pending_events: Array = []  # события за ход игрока
var _pending_attacks: Array = []
var debug_mode: bool = true
var current_player_name: String = "Арагорн"
var pending_return_location_id: String = ""
var pending_return_door_x: int = 0
var pending_return_door_y: int = 0
var pending_previous_location: String = ""
var loading_screen: CanvasLayer = null
var story_intro: String = ""

func _ready():
	grid_state = GridState.new()
	grid_state.initialize()
	combat_state = CombatState.new()
	game_state = GameState.new()
	
	# Создаём игрока (временно, будет заменён при генерации карты)
	grid_state.set_unit("player_1", "Арагорн", "player", 3, 4)
	combat_state.add_unit("player_1", {
		"name": "Арагорн",
		"type": "player",
		"hp": 20,
		"max_hp": 20,
		"ac": 15,
		"attack_bonus": 5
	})
	
	# Устанавливаем порядок ходов
	combat_state.initiative_order = ["player_1"]
	combat_state.current_turn_index = 0
	
	# AI клиент
	ai_client = AIClientOllama.new()
	add_child(ai_client)
	ai_client.model_name = "dnd-master-nothink"
	ai_client.response_received.connect(_on_ai_response)
	ai_client.error_occurred.connect(_on_ai_error)
	
	print("GameController готов. Сетка инициализирована.")
	
	# Ждём один кадр, чтобы GridManager успел инициализироваться
	await get_tree().process_frame
	
	# Запускаем AI генерацию
	#_start_game()
	print("GameController готов. Ожидание создания персонажа.")

func _start_game():
	_show_loading_screen("Мастер подземелий создаёт мир...")
	ai_client.model_name = "dnd-master-nothink"
	print("GameController: Принудительно установлена модель ", ai_client.model_name)
	print("Запрос к AI на текстовое описание начальной локации")
	var prompt = PromptTemplatesAuto.get_start_location_prompt()
	ai_client.send_request([{"role": "user", "content": prompt}], {}, {}, "location_text")
func _get_players_info() -> Array:
	var players = []
	for unit_id in combat_state.units.keys():
		var unit = combat_state.units[unit_id]
		if unit.get("type") == "player":
			var pos = grid_state.get_unit_position(unit_id)
			players.append({
				"id": unit_id,
				"name": unit.get("name"),
				"hp": unit.get("hp"),
				"max_hp": unit.get("max_hp"),
				"ac": unit.get("ac"),
				"x": pos.x,
				"y": pos.y
			})
	return players

func _get_enemies_info() -> Array:
	var enemies = []
	for unit_id in combat_state.units.keys():
		var unit = combat_state.units[unit_id]
		if unit.get("type") == "enemy":
			var pos = grid_state.get_unit_position(unit_id)
			enemies.append({
				"id": unit_id,
				"name": unit.get("name"),
				"hp": unit.get("hp"),
				"max_hp": unit.get("max_hp"),
				"ac": unit.get("ac"),
				"attack_bonus": unit.get("attack_bonus", 3),
				"x": pos.x,
				"y": pos.y
			})
	return enemies

func _handle_action(action: Dictionary):
	var action_type = action.get("action", "")
	
	match action_type:
		"generate_map":
			var params = action.get("parameters", {})
			print("Генерация карты с параметрами: ", params)
			var map_data = ProceduralMap.generate(params)
			_apply_map_data(map_data)
			game_message.emit("Сгенерирована локация: " + map_data.get("location_name", "Неизвестная"))
		
		"game_message":
			var text = action.get("text", "")
			if text:
				game_message.emit(text)
				print("AI: ", text)
		
		"spawn_enemy":
			var name = action.get("name", "")
			if name.is_empty():
				print("Ошибка: spawn_enemy без имени")
				return
			var x = action.get("x", -1)
			var y = action.get("y", -1)
			if x >= 0 and x < grid_state.width and y >= 0 and y < grid_state.height:
				var enemy_id = "enemy_" + str(randi())
				grid_state.set_unit(enemy_id, name, "enemy", x, y)
				combat_state.add_unit(enemy_id, {
					"name": name,
					"type": "enemy",
					"hp": action.get("hp", 12),
					"max_hp": action.get("hp", 12),
					"ac": action.get("ac", 12),
					"attack_bonus": action.get("attack_bonus", 3),
					"damage_dice": action.get("damage_dice", "1d6+2")
				})
				combat_state.initiative_order.append(enemy_id)
				print("Создан враг: ", name, " на ", x, ",", y)
		
		_:
			print("Неизвестное действие: ", action_type)

func _string_to_tile_type(type_str: String):
	match type_str:
		"floor": return GridState.TileType.FLOOR
		"wall": return GridState.TileType.WALL
		"grass": return GridState.TileType.GRASS
		"stone": return GridState.TileType.STONE
		"dirt": return GridState.TileType.DIRT
		"water": return GridState.TileType.WATER
		"table": return GridState.TileType.FLOOR
		_:
			print("Неизвестный тип плитки: ", type_str)
			return null

func _on_ai_response(response: Dictionary):
	var typ = response.get("type")
	
	print("=== _on_ai_response: typ = ", typ)
	
	if typ == "actions":
		var actions = response["data"]
		print("Получено действий от AI: ", actions.size())
		for i in range(actions.size()):
			var action = actions[i]
			print("Действие ", i, ": ", action)
			_handle_action(action)
		_refresh_grid()
	
	elif typ == "tool_calls":
		var tool_calls = response["data"]
		print("Получены вызовы инструментов: ", tool_calls)
		for tool_call in tool_calls:
			var function_name = tool_call["function"]["name"]
			var arguments = JSON.parse_string(tool_call["function"]["arguments"])
			match function_name:
				"attack_enemy":
					print("Атака врага: ", arguments["enemy_name"])
				"move_player":
					print("Перемещение: ", arguments["direction"])
		return
	
	elif typ == "text":
		var text = response["data"]
		
		# ПРОВЕРЯЕМ: это ответ на запрос структуры кампании или story_intro
		if pending_action == "story_intro":
			_on_story_received(text)
			return
		
		# ===== ПРОВЕРЯЕМ JSON ДЛЯ ГЕНЕРАЦИИ ЛОКАЦИИ (старый способ) =====
		var json_start = text.find("{")
		var json_end = text.rfind("}")
		if json_start != -1 and json_end != -1 and json_end > json_start:
			var json_str = text.substr(json_start, json_end - json_start + 1)
			var json = JSON.new()
			var parse_result = json.parse_string(json_str)
			if parse_result is Dictionary:
				print("JSON успешно распарсен")
				if parse_result.get("action") == "generate_location":
					var params = parse_result.get("parameters", {})
					print("Генерация локации с параметрами: ", params)
					var location_manager = get_node("/root/LocationManagerAuto")
					if location_manager:
						var new_location = location_manager.generate_location(text, {"return_location_id": pending_return_location_id, "return_door_x": pending_return_door_x, "return_door_y": pending_return_door_y, "previous_location": pending_previous_location})
						location_manager.set_current_location(new_location)
						return
		
		# ===== ПРОВЕРЯЕМ СТРУКТУРИРОВАННУЮ КОМАНДУ [команда:цель:число] =====
		var regex = RegEx.new()
		regex.compile("\\[([a-z]+):([a-zа-я]+):(\\d+)\\]")
		var match = regex.search(text)
		
		if match:
			var command = match.get_string(1)
			var target = match.get_string(2)
			var value = int(match.get_string(3))
			
			print("Команда: ", command, ", цель: ", target, ", значение: ", value)
			
			match command:
				"attack":
					_perform_attack_by_name(target)
				"move":
					_perform_move_by_direction(target)
				"examine":
					game_message.emit("Осмотр: " + target)
			return
		
		# Текстовая генерация локации (использует структуру кампании)
		if not text.begins_with("[") and not text.begins_with("{"):
			var location_manager = get_node("/root/LocationManagerAuto")
			if location_manager and (location_manager.current_location == null or pending_action == "entering_door"):
				print("Получено текстовое описание локации, передаём в LocationManager")
		
				var additional_params = {}
				if pending_return_location_id != "":
					additional_params = {
						"return_location_id": pending_return_location_id,
						"return_door_x": pending_return_door_x,
						"return_door_y": pending_return_door_y,
						"previous_location": pending_previous_location
					}
					pending_return_location_id = ""
					pending_return_door_x = 0
					pending_return_door_y = 0
					pending_previous_location = ""
		
				pending_action = ""
				
				var campaign_mgr = get_node_or_null("/root/CampaignManagerAuto")
				var target_loc_id = ""
				
				if additional_params.has("return_location_id"):
					target_loc_id = additional_params["return_location_id"]
				elif campaign_mgr and campaign_mgr.has_campaign():
					target_loc_id = "loc_" + str(text.hash())
				
				if target_loc_id != "":
					location_manager.get_or_create_location(target_loc_id, text, {})
				else:
					var new_location = location_manager.generate_location(text, additional_params)
					location_manager.set_current_location(new_location)
				
				return
		
		# ===== ОБЫЧНЫЙ ТЕКСТ =====
		if text and not text.is_empty():
			# НЕ показываем JSON игроку
			if not text.begins_with("{") and not text.begins_with("["):
				game_message.emit(text)
				print("AI говорит: ", text)
		
		is_waiting_for_ai = false
		
		if pending_action == "battle_summary":
			print("Суммарное описание хода получено, передаём ход врагам")
			pending_action = ""
			clear_events()
			_proceed_to_enemy_turn()
			return
		
		if combat_state.action_points <= 0 and combat_state.get_all_enemies().size() > 0:
			print("Очки действий закончились, передаём ход врагам")
			_proceed_to_enemy_turn()
			return
	
	elif typ == "description":
		var text = response["data"]
		if text and not text.is_empty():
			game_message.emit(text)
			print("Описание: ", text)
		
		is_waiting_for_ai = false
		
		if pending_action == "enemy_turn":
			if _pending_attacks.size() > 0:
				var next_attack = _pending_attacks.pop_front()
				print("Описываем следующую атаку врага: ", next_attack["name"])
				if next_attack["is_hit"]:
					request_action_description("атака врага", next_attack["name"], "Арагорн", next_attack["damage"], true)
				else:
					request_action_description("атака врага", next_attack["name"], "Арагорн", 0, false)
			else:
				print("Все атаки врагов описаны, передаём ход игроку")
				pending_action = ""
				if combat_state.units.get("player_1", {}).get("hp", 0) <= 0:
					game_message.emit("Арагорн повержен! Игра окончена.")
					game_over = true
					return
				var enemies = combat_state.get_all_enemies()
				if enemies.is_empty():
					game_message.emit("Все враги повержены! Вы победили!")
					combat_state.mode = CombatState.GameMode.PEACEFUL
				else:
					combat_state.current_turn_index = 0
					combat_state.reset_action_points()
					game_message.emit("Ваш ход!")
					_refresh_grid()
		
		elif pending_action == "player_attack":
			print("Атака игрока завершена (description)")
			pending_action = ""
			if combat_state.action_points <= 0 and not game_over:
				end_player_turn()
		
		elif pending_action == "battle_summary":
			print("Суммарное описание хода получено (description), передаём ход врагам")
			pending_action = ""
			clear_events()
			_proceed_to_enemy_turn()
			return
	
	else:
		print("Неизвестный тип ответа: ", typ)

func request_action_description(action_text: String, attacker: String, defender: String, damage: int, is_hit: bool):
	is_waiting_for_ai = true
	game_message.emit("🤔 Мастер подземелий размышляет...")
	
	var context = {
		"action_text": action_text,
		"attacker": attacker,
		"defender": defender,
		"damage": damage,
		"is_hit": is_hit
	}
	
	# Используем короткий промпт для описаний
	ai_client.send_request([], {}, context, "description")
	
func _on_ai_error(error: String):
	print("Ошибка AI: ", error)
	game_message.emit("Ошибка подключения к AI: " + error)
	is_waiting_for_ai = false
	
func process_player_action(action_text: String):
	print("=== process_player_action вызван ===")
	print("Текст: ", action_text)
	var context = {"input": action_text}
	ai_client.send_request([], {}, context, "test_tools")
func _refresh_grid():
	var root = get_tree().current_scene
	if not root:
		print("Корневая сцена не найдена")
		return
	
	# Пробуем найти GridManager в разных местах
	var grid_manager = null
	
	# Вариант 1: прямой потомок Control
	if root.has_node("GridManager"):
		grid_manager = root.get_node("GridManager")
	# Вариант 2: внутри GridContainer
	elif root.has_node("GridContainer/GridManager"):
		grid_manager = root.get_node("GridContainer/GridManager")
	# Вариант 3: ищем по типу
	else:
		grid_manager = root.find_child("GridManager", true, false)
	
	if grid_manager and grid_manager.has_method("refresh_grid"):
		grid_manager.refresh_grid()
	else:
		print("GridManager не найден! Проверьте структуру сцены")
		
func end_player_turn():
	if debug_mode: print("=== end_player_turn вызван ===")
	if game_over:
		return
	
	var enemies = combat_state.get_all_enemies()
	if enemies.is_empty():
		print("Нет врагов, переключаемся в мирный режим")
		combat_state.mode = CombatState.GameMode.PEACEFUL
		combat_state.phase = CombatState.Phase.EXPLORATION
		combat_state.initiative_order = []
		combat_state.current_turn_index = 0
		combat_state.action_points = 3
		pending_action = ""
		pending_events.clear()
		game_message.emit("Все враги повержены! Вы победили!")
		_refresh_grid()
		return
	
	# Если есть события — отправляем на описание
	if pending_events.size() > 0:
		request_battle_summary()
		return
	
	# Если нет событий, сразу передаём ход врагам
	_proceed_to_enemy_turn()

func _simple_enemy_turn():
	print("=== _simple_enemy_turn вызван ===")
	print("is_waiting_for_ai = ", is_waiting_for_ai)
	print("game_over = ", game_over)
	if combat_state.mode != CombatState.GameMode.COMBAT:
		print("Не боевой режим, враги не атакуют")
		return
	
	
	if is_waiting_for_ai:
		print("WARNING: is_waiting_for_ai = true, принудительно сбрасываем")
		is_waiting_for_ai = false
	
	if game_over:
		return
	if is_waiting_for_ai:
		print("WARNING: is_waiting_for_ai = true, принудительно сбрасываем")
		is_waiting_for_ai = false
	
	if game_over:
		return
	
	if debug_mode: print("=== _simple_enemy_turn вызван ===")
	
	var enemies = combat_state.get_all_enemies()
	if debug_mode: print("Врагов: ", enemies.size())
	
	if enemies.is_empty():
		game_message.emit("Все враги повержены! Вы победили!")
		combat_state.current_turn_index = 0
		combat_state.reset_action_points()
		game_message.emit("Ваш ход!")
		_refresh_grid()
		return
	
	var player_pos = grid_state.get_unit_position("player_1")
	if debug_mode: print("Позиция игрока: ", player_pos)
	
	# Движение врагов
	for enemy_id in enemies:
		var enemy_pos = grid_state.get_unit_position(enemy_id)
		if debug_mode: print("Враг ", enemy_id, " на позиции ", enemy_pos)
		
		var dx = player_pos.x - enemy_pos.x
		var dy = player_pos.y - enemy_pos.y
		var distance = max(abs(dx), abs(dy))
		
		if distance > 1:
			var new_x = enemy_pos.x
			var new_y = enemy_pos.y
			
			if abs(dx) > 0:
				new_x += 1 if dx > 0 else -1
			elif abs(dy) > 0:
				new_y += 1 if dy > 0 else -1
			
			if grid_state.is_walkable(new_x, new_y, enemy_id):
				grid_state.remove_unit(enemy_id)
				grid_state.set_unit(enemy_id, combat_state.units[enemy_id]["name"], "enemy", new_x, new_y)
				if debug_mode: print(combat_state.units[enemy_id]["name"], " переместился на ", new_x, ",", new_y)
	
	_refresh_grid()
	
	# Сбор атак
	var attacks_to_describe = []
	
	for enemy_id in enemies:
		var enemy_pos = grid_state.get_unit_position(enemy_id)
		var dx = player_pos.x - enemy_pos.x
		var dy = player_pos.y - enemy_pos.y
		var distance = max(abs(dx), abs(dy))
		
		if distance <= 1:
			var enemy = combat_state.units[enemy_id]
			var roll = randi() % 20 + 1
			var attack_bonus = enemy.get("attack_bonus", 3)
			var ac = combat_state.units["player_1"].get("ac", 15)
			var is_hit = (roll + attack_bonus >= ac)
			
			if debug_mode: print(enemy["name"], " атакует: бросок ", roll, "+", attack_bonus, " vs AC ", ac, " = ", is_hit)
			
			if is_hit:
				var damage = combat_state.calculate_damage(enemy.get("damage_dice", "1d6+2"))
				var old_hp = combat_state.units["player_1"]["hp"]
				var new_hp = combat_state.units["player_1"]["hp"] - damage
				combat_state.units["player_1"]["hp"] = new_hp
				print("DEBUG: Враг ", enemy["name"], " нанёс ", damage, " урона. HP было ", old_hp, ", стало ", new_hp)
				attacks_to_describe.append({
					"name": enemy["name"],
					"damage": damage,
					"is_hit": true,
					"enemy_id": enemy_id
				})
				
				if debug_mode: print("Нанесён урон ", damage, ", у игрока осталось ", new_hp, " HP")
				
				if new_hp <= 0:
					game_message.emit("Арагорн повержен! Игра окончена.")
					game_over = true
					return
			else:
				attacks_to_describe.append({
					"name": enemy["name"],
					"damage": 0,
					"is_hit": false,
					"enemy_id": enemy_id
				})
				if debug_mode: print("Промах!")
		else:
			if debug_mode: print(combat_state.units[enemy_id]["name"], " слишком далеко для атаки")
	
	# Если есть атаки, описываем их
	if attacks_to_describe.size() > 0:
		print("=== Ход врагов: собрано атак для описания: ", attacks_to_describe.size())
		for i in range(attacks_to_describe.size()):
			print("  Атака ", i, ": ", attacks_to_describe[i]["name"])
	
		pending_action = "enemy_turn"
		_pending_attacks = attacks_to_describe
		print("_pending_attacks сохранён. Размер: ", _pending_attacks.size())
	
		var attack = _pending_attacks.pop_front()
		print("Начинаем описывать первую атаку: ", attack["name"])
		print("После pop_front, _pending_attacks.size() = ", _pending_attacks.size())
	
		if attack["is_hit"]:
			request_action_description("атака врага", attack["name"], "Арагорн", attack["damage"], true)
		else:
			request_action_description("атака врага", attack["name"], "Арагорн", 0, false)
	else:
		# Если враги не атаковали, сразу передаём ход обратно
		if debug_mode: print("Враги не атаковали, передаём ход игроку")
		pending_action = ""
		combat_state.current_turn_index = 0
		combat_state.reset_action_points()
		game_message.emit("Ваш ход!")
		_refresh_grid()
		
func request_map_parameters(location_name: String, biome: String, player_party: Array):
	var prompt = {
		"instruction": "Создай параметры для процедурной генерации карты.",
		"location_name": location_name,
		"biome": biome,
		"player_party": player_party,
		"output_format": {
			"size": 16,
			"features": [
				{"type": "wall", "pattern": "perimeter", "thickness": 1},
				{"type": "room", "x": 4, "y": 4, "width": 6, "height": 6},
				{"type": "corridor", "from": [4, 4], "to": [10, 10], "width": 2}
			],
			"enemies": [
				{"type": "skeleton", "count": 2},
				{"type": "goblin", "count": 1}
			],
			"objects": [
				{"type": "chest", "position": [12, 5]}
			],
			"player_start": [3, 4]
		}
	}
	
	ai_client.send_request([], {}, prompt)
	
func _apply_map_data(map_data: Dictionary, entry_door_pos: Vector2i = Vector2i(-1, -1)):
	var size = map_data.get("size", 16)
	
	# Обновляем размер сетки
	if size != grid_state.width:
		grid_state.width = size
		grid_state.height = size
		grid_state.initialize()
	# ===== ОЧИЩАЕМ СТАРЫЕ ДВЕРИ =====
	if "doors" in grid_state:
		grid_state.doors.clear()
	# =================================
	
	# Применяем тайлы
	var tiles = map_data.get("tiles", [])
	for x in range(min(tiles.size(), grid_state.width)):
		for y in range(min(tiles[x].size(), grid_state.height)):
			var tile_type_str = tiles[x][y]
			var tile_type = _string_to_tile_type(tile_type_str)
			if tile_type != null:
				grid_state.tiles[x][y]["type"] = tile_type
	
	# Удаляем старых врагов
	for unit_id in combat_state.units.keys():
		if unit_id != "player_1":
			grid_state.remove_unit(unit_id)
			combat_state.remove_unit(unit_id)
	
	# Размещаем врагов
	var enemies = map_data.get("enemies", [])
	for enemy in enemies:
		var enemy_id = "enemy_" + str(randi())
		var x = enemy.get("x", 0)
		var y = enemy.get("y", 0)
		if x >= 0 and x < grid_state.width and y >= 0 and y < grid_state.height:
			grid_state.set_unit(enemy_id, enemy.get("name", "Враг"), "enemy", x, y)
			combat_state.add_unit(enemy_id, {
				"name": enemy.get("name", "Враг"),
				"type": "enemy",
				"hp": enemy.get("hp", 12),
				"max_hp": enemy.get("hp", 12),
				"ac": enemy.get("ac", 12),
				"attack_bonus": enemy.get("attack_bonus", 3),
				"damage_dice": enemy.get("damage_dice", "1d6+2")
			})
	
	# ===== ДОБАВИТЬ ЭТОТ БЛОК ДЛЯ ДВЕРЕЙ =====
	var exits = map_data.get("exits", [])
	for door_data in exits:
		var door = DoorData.new()
		door.position = Vector2i(door_data.get("x", 0), door_data.get("y", 0))
		door.description = door_data.get("description", "Дверь")
		door.target_location_id = door_data.get("target_location_id", "")
		door.target_door_id = door_data.get("target_door_id", "")
		var grid_manager = _get_grid_manager()
		if grid_manager:
			grid_manager.add_door(door)
	
	var player_start = map_data.get("player_start", [size/2, size/2])
	var spawn_pos = Vector2i(player_start[0], player_start[1])

	# Если передана позиция входной двери, ищем свободную клетку рядом с ней
	if entry_door_pos.x >= 0 and entry_door_pos.y >= 0:
		var free_pos = _find_free_cell_near(entry_door_pos, map_data)
		if free_pos != Vector2i(-1, -1):
			spawn_pos = free_pos
			print("Игрок появится рядом с дверью на ", spawn_pos)

	grid_state.remove_unit("player_1")
	grid_state.set_unit("player_1", current_player_name, "player", spawn_pos.x, spawn_pos.y)
	print("Игрок создан на позиции ", spawn_pos.x, ",", spawn_pos.y, " с именем ", current_player_name)
	
	_refresh_grid()
	
	print("Карта применена: ", map_data.get("location_name", "Неизвестная локация"))
	combat_state.mode = CombatState.GameMode.PEACEFUL
	combat_state.phase = CombatState.Phase.EXPLORATION
	combat_state.initiative_order = []
	combat_state.current_turn_index = 0
	combat_state.action_points = 3

func request_location_generation(location_context: Dictionary):
	print("Запрос на вход в дверь с контекстом: ", location_context)
	
	pending_return_location_id = location_context.get("return_location_id", "")
	pending_return_door_x = location_context.get("return_door_x", 0)
	pending_return_door_y = location_context.get("return_door_y", 0)
	pending_previous_location = location_context.get("previous_location", "Неизвестно")
	
	# НОВОЕ: Проверяем target_location_id из двери
	var target_id = location_context.get("target_location_id", "")
	
	if target_id != "":
		print("GameController: Целевая локация указана в двери: ", target_id)
		
		var campaign_mgr = get_node_or_null("/root/CampaignManagerAuto")
		var location_manager = get_node("/root/LocationManagerAuto")
		
		# Проверяем, существует ли уже эта локация
		if location_manager and location_manager.load_location(target_id):
			print("GameController: Локация уже существует, загружаем ", target_id)
			location_manager.get_or_create_location(target_id, "", {
				"return_location_id": pending_return_location_id,
				"return_door_x": pending_return_door_x,
				"return_door_y": pending_return_door_y,
				"previous_location": pending_previous_location
			})
			return
		
		# Если есть структура кампании — используем описание оттуда
		if campaign_mgr and campaign_mgr.has_campaign():
			var loc_info = campaign_mgr.get_location_info(target_id)
			if not loc_info.is_empty():
				print("GameController: Локация из структуры кампании, генерируем ", target_id)
				location_manager.get_or_create_location(target_id, loc_info.get("description", ""), {
					"return_location_id": pending_return_location_id,
					"return_door_x": pending_return_door_x,
					"return_door_y": pending_return_door_y,
					"previous_location": pending_previous_location
				})
				return
		
		# Если ничего не нашли — запрашиваем ИИ
		print("GameController: Нет данных о локации, запрашиваем ИИ...")
		_show_loading_screen("Мастер подземелий описывает место...")
		pending_action = "entering_door"
		var context_str = "Переход из: " + pending_previous_location + ". ID новой локации: " + target_id
		var prompt = PromptTemplatesAuto.get_location_prompt_with_context(context_str)
		ai_client.send_request([{"role": "user", "content": prompt}], {}, location_context, "location_text")
	else:
		# Старое поведение (если target_id не указан)
		_show_loading_screen("Мастер подземелий описывает место...")
		pending_action = "entering_door"
		var context_str = "Переход из: " + pending_previous_location
		var prompt = PromptTemplatesAuto.get_location_prompt_with_context(context_str)
		ai_client.send_request([{"role": "user", "content": prompt}], {}, location_context, "location_text")
func request_death_description(defender: String):
	is_waiting_for_ai = true
	game_message.emit("AI описывает гибель врага...")
	
	var context = {
		"defender": defender
	}
	
	ai_client.send_request([], {}, context, "death")
	
func add_event(event: Dictionary):
	pending_events.append(event)
	print("Событие добавлено. Всего событий: ", pending_events.size())
func request_battle_summary():
	if pending_events.is_empty():
		print("Нет событий для описания")
		_proceed_to_enemy_turn()
		return
	
	is_waiting_for_ai = true
	pending_action = "battle_summary"
	game_message.emit("📜 Мастер подземелий подводит итог хода...")
	
	var context = {
		"events": pending_events,
		"player_name": "Арагорн"
	}
	
	ai_client.send_request([], {}, context, "battle_summary")

func clear_events():
	pending_events.clear()

func _proceed_to_enemy_turn():
	print("=== _proceed_to_enemy_turn вызван ===")
	
	# Сброс выделения
	var root = get_tree().current_scene
	var grid_manager = null
	if root:
		if root.has_node("GridManager"):
			grid_manager = root.get_node("GridManager")
		elif root.has_node("GridContainer/GridManager"):
			grid_manager = root.get_node("GridContainer/GridManager")
		else:
			grid_manager = root.find_child("GridManager", true, false)
	
	if grid_manager:
		grid_manager.selected_unit_id = ""
		grid_manager._clear_highlight()
	
	combat_state.reset_action_points()
	
	# Переключаемся на ход врагов
	combat_state.current_turn_index = 1
	if combat_state.current_turn_index >= combat_state.initiative_order.size():
		combat_state.current_turn_index = 0
	
	print("current_turn_index = ", combat_state.current_turn_index)
	
	game_message.emit("Ход врагов...")
	_simple_enemy_turn()
func parse_location_description(description: String):
	var result = {
		"biome": "dungeon",
		"enemies": [],
		"exits": []
	}
	
	var desc_lower = description.to_lower()
	
	# Определяем биом
	if desc_lower.find("пещер") != -1 or desc_lower.find("подземель") != -1:
		result["biome"] = "dungeon"
	elif desc_lower.find("лес") != -1:
		result["biome"] = "forest"
	
	# Ищем врагов
	var enemy_keywords = ["скелет", "гоблин", "орк", "крыса"]
	for keyword in enemy_keywords:
		if desc_lower.find(keyword) != -1:
			result["enemies"].append({"type": keyword, "count": 1})
	
	# Ищем выходы
	if desc_lower.find("проход") != -1 or desc_lower.find("дверь") != -1:
		result["exits"].append({"x": 7, "y": 4, "description": "Проход"})
	
	return result
func test_function_calling():
	print("=== ТЕСТ FUNCTION CALLING ===")
	
	var prompt = "Атакуй гоблина!"
	var test_messages = [{"role": "user", "content": prompt}]
	
	# Отправляем запрос с tools
	ai_client.send_request(test_messages, {}, {}, "test_tools")
func _perform_attack_by_name(enemy_name: String):
	# Ищем врага по имени
	var enemy_id = _find_enemy_by_name(enemy_name)
	if enemy_id:
		var grid_manager = _get_grid_manager()
		if grid_manager:
			grid_manager._attack("player_1", enemy_id)
	else:
		game_message.emit("Не найден враг: " + enemy_name)

func _perform_move_by_direction(direction: String):
	var current_pos = grid_state.get_unit_position("player_1")
	var new_pos = current_pos
	
	match direction.to_lower():
		"север", "north":
			new_pos.y -= 1
		"юг", "south":
			new_pos.y += 1
		"запад", "west":
			new_pos.x -= 1
		"восток", "east":
			new_pos.x += 1
	
	var grid_manager = _get_grid_manager()
	if grid_manager:
		grid_manager._try_move_unit("player_1", new_pos.x, new_pos.y)

func _find_enemy_by_name(name: String) -> String:
	var name_lower = name.to_lower()
	
	for unit_id in combat_state.units.keys():
		var unit = combat_state.units[unit_id]
		if unit.get("type") == "enemy":
			var enemy_name = unit.get("name", "").to_lower()
			# Проверяем точное совпадение или вхождение
			if enemy_name == name_lower or enemy_name.find(name_lower) != -1 or name_lower.find(enemy_name) != -1:
				return unit_id
	return ""

func _get_grid_manager():
	var root = get_tree().current_scene
	if root:
		if root.has_node("GridManager"):
			return root.get_node("GridManager")
		elif root.has_node("GridContainer/GridManager"):
			return root.get_node("GridContainer/GridManager")
	return null
func test_structured_text():
	print("=== ТЕСТ СТРУКТУРИРОВАННОГО ТЕКСТА ===")
	
	var prompt = "Атакую гоблина"
	var context = {"input": prompt}
	
	ai_client.send_request([], {}, context, "test_tools")
	
func skip_turn():
	print("=== skip_turn вызван ===")
	if game_over:
		return
	
	# Проверяем, боевой ли режим и ход игрока
	if combat_state.mode == CombatState.GameMode.COMBAT:
		if combat_state.is_player_turn():
			print("Пропуск хода игрока")
			combat_state.action_points = 0
			end_player_turn()
		else:
			print("Сейчас ход врагов, пропустить нельзя")
			game_message.emit("Сейчас ход врагов")
	else:
		print("Мирный режим, пропуск хода не нужен")
		game_message.emit("Вы не в бою")
		
func start_with_character(character: CharacterData):
	print("Запуск игры с персонажем: ", character.character_name)
	
	current_player_name = character.character_name
	
	grid_state.remove_unit("player_1")
	grid_state.set_unit("player_1", character.character_name, "player", 3, 4)
	
	combat_state.units["player_1"] = {
		"name": character.character_name,
		"type": "player",
		"hp": character.hp,
		"max_hp": character.max_hp,
		"ac": character.ac,
		"attack_bonus": 5,
		"inventory": character.inventory
	}
	
	_show_loading_screen("Мастер подземелий плетёт историю...")
	_request_story_intro([character])
func request_victory_description():
	is_waiting_for_ai = true
	game_message.emit("AI описывает победу...")
	
	var prompt = "Опиши эпичную победу над последним врагом одной короткой фразой."
	ai_client.send_request([{"role": "user", "content": prompt}], {}, {}, "description")
# Ищет свободную клетку рядом с указанной позицией
func _find_free_cell_near(pos: Vector2i, map_data: Dictionary) -> Vector2i:
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	var size = map_data.get("size", 16)
	var tiles = map_data.get("tiles", [])
	var enemies = map_data.get("enemies", [])
	var exits = map_data.get("exits", [])
	
	for dir in directions:
		var nx = pos.x + dir.x
		var ny = pos.y + dir.y
		if nx < 0 or nx >= size or ny < 0 or ny >= size:
			continue
		# Проверка на стену
		if tiles.size() > nx and tiles[nx].size() > ny:
			var tile_type = tiles[nx][ny]
			if tile_type == "wall":
				continue
		# Проверка на врага
		var occupied = false
		for enemy in enemies:
			if enemy.get("x") == nx and enemy.get("y") == ny:
				occupied = true
				break
		if occupied:
			continue
		# Проверка на другую дверь (не ту, через которую вошли)
		for exit_data in exits:
			if exit_data.get("x") == nx and exit_data.get("y") == ny:
				occupied = true
				break
		if occupied:
			continue
		return Vector2i(nx, ny)
	return Vector2i(-1, -1)

func _show_loading_screen(text: String = "Загрузка..."):
	if loading_screen:
		return
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	loading_screen = canvas_layer
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.modulate = Color(0, 0, 0, 0.85)
	canvas_layer.add_child(panel)
	
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(1, 1, 1, 1)
	canvas_layer.add_child(label)
	
	get_tree().root.add_child(canvas_layer)

func _hide_loading_screen():
	if loading_screen:
		loading_screen.queue_free()
		loading_screen = null
func _request_story_intro(characters: Array):
	var prompt = PromptTemplatesAuto.get_story_intro_prompt(characters)
	ai_client.model_name = "dnd-master-nothink"
	pending_action = "story_intro"
	ai_client.send_request([{"role": "user", "content": prompt}], {}, {}, "story")

# game_controller.gd — ЗАМЕНИТЬ _on_story_received
func _on_story_received(story_text: String):
	story_intro = story_text.strip_edges()
	print("Сюжетная завязка сохранена:\n", story_intro)
	pending_action = ""
	# Создаём CampaignManager, если ещё не создан
	var campaign_mgr = get_node_or_null("/root/CampaignManagerAuto")
	if not campaign_mgr:
		campaign_mgr = CampaignManager.new()
		campaign_mgr.name = "CampaignManagerAuto"
		get_tree().root.add_child(campaign_mgr)
		campaign_mgr.initialize(ai_client)
		campaign_mgr.campaign_loaded.connect(_on_campaign_structure_ready)
		campaign_mgr.campaign_error.connect(_on_campaign_error)
	
	# Запрашиваем структуру кампании
	_show_loading_screen("Мастер подземелий создаёт сюжет...")
	
	# Ищем персонажа (для передачи в промпт)
	var player_char = _get_player_character()
	if player_char:
		campaign_mgr.request_campaign_structure(story_intro, player_char)
	else:
		# Fallback: если персонаж не найден, генерируем без него
		campaign_mgr.request_campaign_structure(story_intro, CharacterData.new())

func _get_player_character() -> CharacterData:
	# Пытаемся загрузить персонажа из CharacterManager
	var char_mgr = get_node_or_null("/root/CharacterManagerAuto")
	if char_mgr and char_mgr.has_method("get_current_character"):
		return char_mgr.get_current_character()
	return null

func _on_campaign_structure_ready(campaign_data: Dictionary):
	print("GameController: Структура кампании получена!")
	_hide_loading_screen()
	
	# Получаем стартовую локацию из структуры
	var world = campaign_data.get("world_structure", {})
	var start_loc = world.get("starting_location", {})
	var start_loc_id = start_loc.get("id", "loc_start")
	var start_loc_desc = start_loc.get("description", story_intro)
	
	# Используем get_or_create_location вместо generate_location
	var location_manager = get_node("/root/LocationManagerAuto")
	if location_manager:
		location_manager.get_or_create_location(start_loc_id, start_loc_desc, {})
		location_manager.current_location.description = start_loc_desc
		game_message.emit(story_intro)
		print("GameController: Стартовая локация создана: ", start_loc.get("name", "Неизвестно"))

func _on_campaign_error(error: String):
	print("GameController: Ошибка кампании — ", error)
	_hide_loading_screen()
	game_message.emit("⚠️ Ошибка генерации сюжета, создаю простую локацию...")
	
	# Fallback: старая логика
	var location_manager = get_node("/root/LocationManagerAuto")
	if location_manager:
		var new_location = location_manager.generate_location(story_intro, {})
		location_manager.set_current_location(new_location)
