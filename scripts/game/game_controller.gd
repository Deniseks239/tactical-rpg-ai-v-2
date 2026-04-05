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
	ai_client.model_name = "gemma3:4b"
	ai_client.response_received.connect(_on_ai_response)
	ai_client.error_occurred.connect(_on_ai_error)
	
	print("GameController готов. Сетка инициализирована.")
	
	# Ждём один кадр, чтобы GridManager успел инициализироваться
	await get_tree().process_frame
	
	# Запускаем AI генерацию
	_start_game()

func _start_game():
	print("Запрос к AI на генерацию начальной локации")
	
	var prompt = """
Верни ТОЛЬКО JSON. Формат:
{"action": "generate_location", "parameters": {"location_name": "название", "description": "описание", "biome": "dungeon", "size": 8, "enemies": [{"type": "goblin", "count": 2}], "exits": [], "player_start": [4, 4]}}
Важно: exits должен быть пустым массивом [].
Создай простую локацию. Размер 8x8. Используй не более 2 типов врагов.
"""
	
	ai_client.send_request([{"role": "user", "content": prompt}], {}, {}, "location")
	
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
			
			if action.get("action") == "generate_location":
				var params = action.get("parameters", {})
				print("Генерация локации с параметрами: ", params)
				var location_manager = get_node("/root/LocationManagerAuto")
				if location_manager:
					var new_location = location_manager.generate_location(params)
					location_manager.set_current_location(new_location)
					return
			
			_handle_action(action)
		
		_refresh_grid()
	
	elif typ == "text":
		if pending_action == "battle_summary":
			print("Суммарное описание хода получено")
			pending_action = ""
			clear_events()
			_proceed_to_enemy_turn()
			return
		var text = response["data"]
		
		# Пытаемся найти JSON в тексте (для генерации локации)
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
						var new_location = location_manager.generate_location(params)
						location_manager.set_current_location(new_location)
						return
		
		if text and not text.is_empty():
			game_message.emit(text)
			print("AI говорит: ", text)
		
		is_waiting_for_ai = false
		
		# Если это был ответ на суммарное описание хода
		if pending_action == "battle_summary":
			print("Суммарное описание хода получено")
			pending_action = ""
			clear_events()
			_proceed_to_enemy_turn()
			return
		
		# Обработка после получения ответа
		if pending_action == "player_attack":
			print("Атака игрока завершена (text)")
			pending_action = ""
			if combat_state.action_points <= 0 and not game_over:
				end_player_turn()
		
		elif pending_action == "enemy_turn":
			print("Обработка хода врагов (text)")
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
				else:
					combat_state.current_turn_index = 0
					combat_state.reset_action_points()
					game_message.emit("Ваш ход!")
					_refresh_grid()
	
	elif typ == "description":
		var text = response["data"]
		if text and not text.is_empty():
			game_message.emit(text)
			print("Описание: ", text)
		
		is_waiting_for_ai = false
		
		if pending_action == "enemy_turn":
			print("=== Обработка описания атаки врага ===")
			print("Осталось атак для описания: ", _pending_attacks.size())
			
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
	if pending_events.size() > 0:
		request_battle_summary()
	else:
		_proceed_to_enemy_turn()
	
	# Находим GridManager
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
	else:
		print("GridManager не найден!")
	
	# Сбрасываем очки действий
	combat_state.reset_action_points()
	
	var enemies = combat_state.get_all_enemies()
	if debug_mode: print("Врагов перед ходом врагов: ", enemies.size())
	
	if enemies.is_empty():
		game_message.emit("Все враги повержены! Вы победили!")
		return
	
	# Переключаемся на ход врагов
	combat_state.current_turn_index = 1
	if combat_state.current_turn_index >= combat_state.initiative_order.size():
		combat_state.current_turn_index = 0
	
	if debug_mode: print("current_turn_index = ", combat_state.current_turn_index)
	
	game_message.emit("Ход врагов...")
	_simple_enemy_turn()

func _simple_enemy_turn():
	print("=== _simple_enemy_turn вызван ===")
	print("is_waiting_for_ai = ", is_waiting_for_ai)
	print("game_over = ", game_over)
	
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
				var new_hp = combat_state.units["player_1"]["hp"] - damage
				combat_state.units["player_1"]["hp"] = new_hp
				
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
	
func _apply_map_data(map_data: Dictionary):
	var size = map_data.get("size", 16)
	
	# Обновляем размер сетки
	if size != grid_state.width:
		grid_state.width = size
		grid_state.height = size
		grid_state.initialize()
	
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
	combat_state.initiative_order = ["player_1"]
	
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
			combat_state.initiative_order.append(enemy_id)
	
	# Размещаем игрока
	var player_start = map_data.get("player_start", [size/2, size/2])
	grid_state.remove_unit("player_1")
	grid_state.set_unit("player_1", "Арагорн", "player", player_start[0], player_start[1])
	var npcs = map_data.get("npcs", [])
	for npc in npcs:
		var npc_id = "npc_" + str(randi())
		var x = npc.get("x", 0)
		var y = npc.get("y", 0)
		if x >= 0 and x < grid_state.width and y >= 0 and y < grid_state.height:
			grid_state.set_unit(npc_id, npc.get("name", "Житель"), "npc", x, y)
			# NPC не добавляем в combat_state, они не участвуют в бою
	
	# Размещаем выходы (двери) — визуально помечаем клетки
	var exits = map_data.get("exits", [])
	if exits is Array:
		for exit_data in exits:
			if exit_data is Dictionary and exit_data.has("x") and exit_data.has("y"):
				var x = exit_data.get("x", -1)
				var y = exit_data.get("y", -1)
				if x >= 0 and x < grid_state.width and y >= 0 and y < grid_state.height:
					# Помечаем клетку как дверь
					pass
			else:
				print("Пропускаем некорректный выход: ", exit_data)
	
	# Ждём один кадр, чтобы GridManager успел получить данные
	await get_tree().process_frame
	_refresh_grid()
	
	print("Карта применена: ", map_data.get("location_name", "Неизвестная локация"))
func request_location_generation(location_context: Dictionary):
	var prompt = {
		"instruction": "Ты — мастер подземелий. Создай параметры для процедурной генерации локации.",
		"context": location_context,
		"output_format": {
			"location_name": "название",
			"description": "описание",
			"biome": "forest/dungeon/city/cave",
			"size": 16,
			"features": [
				{"type": "wall", "pattern": "perimeter", "thickness": 1},
				{"type": "room", "x": 4, "y": 4, "width": 6, "height": 6}
			],
			"enemies": [{"type": "goblin", "count": 2}],
			"npcs": [{"type": "villager", "count": 1, "dialogue": "Привет!"}],
			"exits": [{"type": "door", "description": "Дверь в таверну"}],
			"player_start": [8, 8]
		}
	}
	
	ai_client.send_request([], {}, prompt)

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
	_pending_attacks.clear()
	
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
	
	var enemies = combat_state.get_all_enemies()
	print("Врагов перед ходом врагов: ", enemies.size())
	
	if enemies.is_empty():
		game_message.emit("Все враги повержены! Вы победили!")
		return
	
	combat_state.current_turn_index = 1
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
