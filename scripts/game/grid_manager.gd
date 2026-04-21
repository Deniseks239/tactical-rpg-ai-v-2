extends Node2D
class_name GridManager

var grid_state: GridState
var combat_state: CombatState
var game_controller: GameController
var selected_unit_id: String = ""
var available_moves: Array = []
var _pending_kill: String = ""
var _is_dragging: bool = false
var _drag_start: Vector2
var _camera_initialized: bool = false
var target_scale: float = 1.0

func _ready():
	print("GridManager _ready called")
	await get_tree().process_frame
	
	game_controller = get_node("/root/GameControllerAuto")
	if not game_controller:
		print("GameController not found!")
		return
	
	grid_state = game_controller.grid_state
	combat_state = game_controller.combat_state
	
	if not grid_state or not combat_state:
		print("States not found!")
		return
	
	print("States obtained")
	
	if grid_state.width == 0 or grid_state.height == 0:
		print("Ошибка: grid_state не инициализирован!")
		return
	
	# Начальный масштаб, чтобы карта помещалась
	var viewport_size = get_viewport().get_visible_rect().size
	var map_width = grid_state.width * grid_state.cell_size
	var map_height = grid_state.height * grid_state.cell_size
	var zoom_x = viewport_size.x / map_width
	var zoom_y = viewport_size.y / map_height
	target_scale = min(zoom_x, zoom_y) * 0.9
	scale = Vector2(target_scale, target_scale)
	
	# Центрируем карту
	var center_x = (map_width / 2) * target_scale
	var center_y = (map_height / 2) * target_scale
	position = Vector2(center_x, center_y)
	
	refresh_grid()
	game_controller.game_message.connect(_on_game_message)
	
	set_notify_transform(true)

func _setup_camera():
	var camera = get_viewport().get_camera_2d()
	if camera and not _camera_initialized:
		var map_width = grid_state.width * grid_state.cell_size
		var map_height = grid_state.height * grid_state.cell_size
		var map_center = Vector2(map_width / 2, map_height / 2)
		
		var viewport_size = get_viewport().get_visible_rect().size
		var zoom_x = viewport_size.x / map_width
		var zoom_y = viewport_size.y / map_height
		var zoom = min(zoom_x, zoom_y) * 0.9
		
		camera.scale = Vector2(zoom, zoom)
		camera.global_position = map_center
		_camera_initialized = true
		print("Камера настроена: scale = ", zoom, ", позиция = ", map_center)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_scale *= 0.9
			target_scale = clamp(target_scale, 0.3, 2.0)
			scale = Vector2(target_scale, target_scale)
			print("Масштаб GridManager: ", target_scale)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_scale *= 1.1
			target_scale = clamp(target_scale, 0.3, 2.0)
			scale = Vector2(target_scale, target_scale)
			print("Масштаб GridManager: ", target_scale)
		
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_dragging = true
				_drag_start = get_viewport().get_mouse_position()
				print("Start drag")
			else:
				_is_dragging = false
				print("End drag")
	
	if event is InputEventMouseMotion and _is_dragging:
		position += event.relative
		
func refresh_grid():
	if not grid_state:
		print("Ошибка: grid_state не инициализирован в refresh_grid")
		return
	
	# Пересоздаём сетку
	for child in get_children():
		child.queue_free()
	_create_grid()
	
	# Настраиваем камеру только один раз
	if not _camera_initialized:
		var camera = get_viewport().get_camera_2d()
		if camera:
			var map_width = grid_state.width * grid_state.cell_size
			var map_height = grid_state.height * grid_state.cell_size
			var viewport_size = get_viewport().get_visible_rect().size
			var zoom_x = viewport_size.x / map_width
			var zoom_y = viewport_size.y / map_height
			var zoom = min(zoom_x, zoom_y) * 0.9
			camera.scale = Vector2(zoom, zoom)
			camera.global_position = Vector2(map_width / 2, map_height / 2)
			_camera_initialized = true
			print("Камера настроена: scale = ", zoom)

func _create_grid():
	if not grid_state:
		print("Ошибка: grid_state не инициализирован в _create_grid")
		return
	
	print("Рисую сетку. Ширина:", grid_state.width, " Высота:", grid_state.height)
	
	for x in range(grid_state.width):
		for y in range(grid_state.height):
			var rect = ColorRect.new()
			rect.size = Vector2(grid_state.cell_size, grid_state.cell_size)
			rect.position = Vector2(x * grid_state.cell_size, y * grid_state.cell_size)
			var tile_type = grid_state.tiles[x][y]["type"]
			match tile_type:
				GridState.TileType.FLOOR:
					rect.color = Color(0.6, 0.6, 0.6, 1.0)
				GridState.TileType.WALL:
					rect.color = Color(0.7, 0.2, 0.2, 1.0)
				GridState.TileType.TABLE:
					rect.color = Color(0.6, 0.3, 0.1, 1.0)
				GridState.TileType.CHAIR:
					rect.color = Color(0.5, 0.2, 0.0, 1.0)
				GridState.TileType.GRASS:
					rect.color = Color(0.1, 0.8, 0.1, 1.0)
				GridState.TileType.STONE:
					rect.color = Color(0.7, 0.7, 0.7, 1.0)
				GridState.TileType.DIRT:
					rect.color = Color(0.8, 0.5, 0.2, 1.0)
				GridState.TileType.WATER:
					rect.color = Color(0.2, 0.5, 0.9, 1.0)
				_:
					rect.color = Color(0.4, 0.4, 0.4, 1.0)
				GridState.TileType.ROAD:
					rect.color = Color(0.5, 0.4, 0.3, 1.0)
				GridState.TileType.HOUSE_WALL:
					rect.color = Color(0.7, 0.5, 0.3, 1.0)
				GridState.TileType.HOUSE_DOOR:
					rect.color = Color(0.4, 0.2, 0.1, 1.0)
				GridState.TileType.SHOP_COUNTER:
					rect.color = Color(0.8, 0.6, 0.3, 1.0)
				GridState.TileType.TAVERN_BAR:
					rect.color = Color(0.6, 0.3, 0.1, 1.0)
				GridState.TileType.FORGE:
					rect.color = Color(0.9, 0.2, 0.1, 1.0)
				GridState.TileType.CASTLE_WALL:
					rect.color = Color(0.5, 0.5, 0.5, 1.0)
				GridState.TileType.CASTLE_GATE:
					rect.color = Color(0.3, 0.3, 0.3, 1.0)
				GridState.TileType.PARK:
					rect.color = Color(0.2, 0.6, 0.2, 1.0)
				GridState.TileType.FOUNTAIN:
					rect.color = Color(0.2, 0.4, 0.8, 1.0)
				GridState.TileType.STATUE:
					rect.color = Color(0.7, 0.7, 0.6, 1.0)
			add_child(rect)
			
			# Подсветка дверей из LocationManager (старый способ)
			var is_exit = false
			var location_manager = get_node("/root/LocationManagerAuto")
			if location_manager and location_manager.current_location:
				for exit_data in location_manager.current_location.exits:
					if exit_data.x == x and exit_data.y == y:
						is_exit = true
						break
			if is_exit:
				rect.color = Color(0.9, 0.8, 0.5, 1.0)  # золотистый цвет для дверей
			
			var button = Button.new()
			button.flat = true
			button.size = rect.size
			button.position = rect.position
			button.modulate = Color(1, 1, 1, 0)
			button.pressed.connect(_on_cell_pressed.bind(x, y))
			add_child(button)
			
			var pos_key = str(x) + "_" + str(y)
			if grid_state.units.has(pos_key):
				var unit = grid_state.units[pos_key]
				var unit_data = combat_state.units.get(unit["id"])
				if unit_data:
					var label = Label.new()
					label.text = unit["name"][0]
					label.position = rect.position + Vector2(20, 20)
					add_child(label)
					
					var hp_label = Label.new()
					hp_label.text = str(unit_data["hp"]) + "/" + str(unit_data["max_hp"])
					hp_label.position = rect.position + Vector2(20, 40)
					hp_label.add_theme_font_size_override("font_size", 12)
					add_child(hp_label)
	
# ===== ОТРИСОВКА ДВЕРЕЙ ИЗ grid_state.doors =====
	if "doors" in grid_state and grid_state.doors is Dictionary:
		for door_key in grid_state.doors.keys():
			var door = grid_state.doors[door_key]
			var parts = door_key.split("_")
			if parts.size() != 2:
				continue
			var x = int(parts[0])
			var y = int(parts[1])
			
			var door_rect = ColorRect.new()
			door_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			door_rect.size = Vector2(grid_state.cell_size, grid_state.cell_size)
			door_rect.position = Vector2(x * grid_state.cell_size, y * grid_state.cell_size)
			door_rect.color = Color(0.8, 0.4, 0.2, 0.9)  # коричневый, как дверь
			door_rect.z_index = 10  # <-- ВАЖНО: поверх стен и пола
			add_child(door_rect)
			
			var door_label = Label.new()
			door_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			door_label.text = "🚪"
			door_label.position = door_rect.position + Vector2(5, 5)
			door_label.z_index = 11
			add_child(door_label)
# ===========================================================

func _on_cell_pressed(x: int, y: int):
	# ===== ПРОВЕРКА НА ДВЕРЬ (ИСПРАВЛЕНО) =====
	var door_key = str(x) + "_" + str(y)
	if "doors" in grid_state and grid_state.doors.has(door_key):
		var door = grid_state.doors[door_key]
		print("Клик по двери на клетке ", x, ",", y)
	
		# Проверяем, стоит ли игрок на этой клетке
		var player_pos = grid_state.get_unit_position("player_1")
		if player_pos.x == x and player_pos.y == y:
			# Игрок стоит на двери — входим
			_enter_door({
				"x": x,
				"y": y,
				"description": door.description,
				"target_location_id": door.target_location_id,
				"target_door_id": door.target_door_id
			})
		else:
			# Игрок не на двери — пытаемся переместиться
			if selected_unit_id != "":
				_try_move_unit(selected_unit_id, x, y)
			else:
				game_controller.game_message.emit("Выберите персонажа для перемещения")
		return
# =============================================
	
	var pos_key = str(x) + "_" + str(y)
	
	if game_controller.is_waiting_for_ai:
		print("Ожидание ответа AI, действия временно заблокированы")
		game_controller.game_message.emit("Подождите, AI описывает происходящее...")
		return
	
	if game_controller.game_over:
		print("Игра окончена")
		return
	
	if not combat_state:
		print("Ошибка: combat_state не инициализирован")
		return
	
	var unit_on_cell = grid_state.units.get(pos_key)
	print("DEBUG: selected_unit_id = ", selected_unit_id)
	print("DEBUG: unit_on_cell = ", unit_on_cell)
	print("DEBUG: combat_state.action_points = ", combat_state.action_points)
	
	# Если выбран игрок
	if selected_unit_id != "":
		# Если кликнули на самого себя
		if unit_on_cell and unit_on_cell["type"] == "player" and unit_on_cell["id"] == selected_unit_id:
			# Проверяем, не стоит ли игрок на клетке с дверью (старая логика)
			var location_manager = get_node("/root/LocationManagerAuto")
			var is_on_door = false
			var door_exit = null
			if location_manager and location_manager.current_location:
				for exit_data in location_manager.current_location.exits:
					if exit_data.x == x and exit_data.y == y:
						is_on_door = true
						door_exit = exit_data
						break
			
			if is_on_door:
				print("Игрок стоит на двери, вход")
				_enter_door(door_exit)
				return
			else:
				print("Клик по самому себе, ничего не делаем")
				_update_highlight()
				return
		
		# Если на клетке враг — атакуем
		if unit_on_cell and unit_on_cell["type"] == "enemy":
			print("Попытка атаковать врага: ", unit_on_cell["name"])
			_attack(selected_unit_id, unit_on_cell["id"])
			return
		
		# Пытаемся переместиться на целевую клетку
		_try_move_unit(selected_unit_id, x, y)
		return
	
	# Если игрок не выбран, пытаемся выбрать юнита
	if unit_on_cell and unit_on_cell["type"] == "player":
		selected_unit_id = unit_on_cell["id"]
		_update_highlight()
		game_controller.game_message.emit("Выбран " + unit_on_cell["name"])
		print("Выбран игрок: ", selected_unit_id)
		return
	
	# Если нет юнита, проверяем дверь (старая логика)
	var location_manager = get_node("/root/LocationManagerAuto")
	if location_manager and location_manager.current_location:
		for exit_data in location_manager.current_location.exits:
			if exit_data.x == x and exit_data.y == y:
				# Проверяем, стоит ли игрок рядом с дверью
				var player_pos = grid_state.get_unit_position("player_1")
				var distance_to_door = abs(player_pos.x - x) + abs(player_pos.y - y)
				if distance_to_door <= 1:
					print("Вход в дверь")
					_enter_door(exit_data)
				else:
					game_controller.game_message.emit("Нужно подойти ближе к двери")
				return
	
	print("На клетке ", x, ",", y, " нет юнита и не дверь")
func _move_unit_free(unit_id: String, target_x: int, target_y: int):
	var start_pos = grid_state.get_unit_position(unit_id)
	if start_pos.x == -1:
		return
	
	if grid_state.is_walkable(target_x, target_y, unit_id):
		var unit_data = grid_state.units[str(start_pos.x) + "_" + str(start_pos.y)]
		grid_state.remove_unit(unit_id)
		grid_state.set_unit(unit_id, unit_data["name"], unit_data["type"], target_x, target_y)
		refresh_grid()
		print("Юнит свободно перемещен на ", target_x, ",", target_y)
	else:
		print("Клетка ", target_x, ",", target_y, " недоступна")

func _attack(attacker_id: String, defender_id: String):
	var attacker_pos = grid_state.get_unit_position(attacker_id)
	var defender_pos = grid_state.get_unit_position(defender_id)
	
	var distance = max(abs(attacker_pos.x - defender_pos.x), abs(attacker_pos.y - defender_pos.y))
	if distance > 1:
		var msg = "Слишком далеко для атаки! Нужно подойти ближе."
		game_controller.game_message.emit(msg)
		return
	
	var attacker = combat_state.units[attacker_id]
	var defender = combat_state.units[defender_id]
	var roll = randi() % 20 + 1
	var attack_bonus = attacker.get("attack_bonus", 5)
	var ac = defender.get("ac", 12)
	var is_hit = (roll + attack_bonus >= ac)
	
	print(attacker["name"], " атакует ", defender["name"], " (бросок ", roll, "+", attack_bonus, " vs AC ", ac, ") = ", "ПОПАДАНИЕ" if is_hit else "ПРОМАХ")
	
	# Включаем боевой режим при первой атаке
	if combat_state.mode == CombatState.GameMode.PEACEFUL:
		print("Начало боя!")
		combat_state.mode = CombatState.GameMode.COMBAT
		combat_state.phase = CombatState.Phase.COMBAT
		combat_state.initiative_order = ["player_1"]
		for enemy_id in combat_state.get_all_enemies():
			if enemy_id not in combat_state.initiative_order:
				combat_state.initiative_order.append(enemy_id)
		combat_state.current_turn_index = 0
		combat_state.reset_action_points()
	
	var damage = 0
	var was_killed = false
	
	if is_hit:
		damage = combat_state.calculate_damage(attacker.get("damage_dice", "1d6+2"))
		defender["hp"] -= damage
		was_killed = defender["hp"] <= 0
		
		if was_killed:
			print("Враг убит, удаляем: ", defender["name"])
			var killed_name = defender["name"]
			grid_state.remove_unit(defender_id)
			combat_state.remove_unit(defender_id)
			refresh_grid()
			game_controller.game_message.emit(killed_name + " повержен!")
			
			# Проверяем, остались ли ещё враги
			if combat_state.get_all_enemies().is_empty():
				game_controller.request_victory_description()
				_update_highlight()
				return
			else:
				_update_highlight()
				refresh_grid()
		else:
			refresh_grid()
	
	var event = {
		"type": "attack",
		"attacker": attacker["name"],
		"defender": defender["name"],
		"damage": damage,
		"is_hit": is_hit,
		"was_killed": was_killed
	}
	game_controller.add_event(event)
	
	combat_state.spend_action_points(1)
	print("DEBUG: action_points после атаки = ", combat_state.action_points)
	
	# ОБНОВЛЯЕМ ПОДСВЕТКУ ПОСЛЕ АТАКИ
	_update_highlight()
	refresh_grid()
	
	if combat_state.action_points <= 0:
		selected_unit_id = ""
		_update_highlight()
		refresh_grid()
		game_controller.end_player_turn()

func _try_move_unit(unit_id: String, target_x: int, target_y: int):
	var start_pos = grid_state.get_unit_position(unit_id)
	if start_pos.x == -1:
		return
	var distance = abs(target_x - start_pos.x) + abs(target_y - start_pos.y)
	
	# Проверка границ
	if target_x < 0 or target_x >= grid_state.width or target_y < 0 or target_y >= grid_state.height:
		print("Клетка за границами карты")
		return
	
	# Проверка, не стена ли это
	var tile_type = grid_state.tiles[target_x][target_y]["type"]
	if tile_type == GridState.TileType.WALL:
		print("Нельзя ходить сквозь стены")
		return
	
	# Проверка на дверь — двери проходимы
	var door_key = str(target_x) + "_" + str(target_y)
	var is_door = ("doors" in grid_state) and grid_state.doors.has(door_key)
	
	# Проверка занятости клетки другим юнитом
	var unit_key = str(target_x) + "_" + str(target_y)
	var is_occupied = grid_state.units.has(unit_key)
	
	# Клетка доступна, если она не занята (или это дверь, на которой никого нет)
	var can_walk = not is_occupied or is_door
	
	if not can_walk:
		print("Клетка занята")
		return
	
	# В мирном режиме — свободное перемещение без проверки очков действий
	if combat_state.mode == CombatState.GameMode.PEACEFUL:
		var unit_data = grid_state.units[str(start_pos.x) + "_" + str(start_pos.y)]
		grid_state.remove_unit(unit_id)
		grid_state.set_unit(unit_id, unit_data["name"], unit_data["type"], target_x, target_y)
		refresh_grid()
		_update_highlight()
		print("Юнит свободно перемещен на ", target_x, ",", target_y)
		return
	
	# Боевой режим — с очками действий
	print("DEBUG БОЙ: distance = ", distance, ", action_points = ", combat_state.action_points)
	if distance <= combat_state.action_points:
		var unit_data = grid_state.units[str(start_pos.x) + "_" + str(start_pos.y)]
		grid_state.remove_unit(unit_id)
		grid_state.set_unit(unit_id, unit_data["name"], unit_data["type"], target_x, target_y)
		combat_state.spend_action_points(distance)
		
		_update_highlight()
		refresh_grid()
		print("Юнит перемещен на ", target_x, ",", target_y)
		
		if combat_state.action_points <= 0:
			selected_unit_id = ""
			_update_highlight()
			refresh_grid()
			game_controller.end_player_turn()
	else:
		print("Слишком далеко: расстояние ", distance, " > ", combat_state.action_points)
func _highlight_available_moves(unit_id: String):
	_clear_highlight()
	var pos = grid_state.get_unit_position(unit_id)
	if pos.x == -1:
		return
	
	print("DEBUG: _highlight_available_moves вызван для ", unit_id)
	print("DEBUG: action_points = ", combat_state.action_points)
	
	# Подсвечиваем самого игрока жёлтым (поверх всего)
	var player_highlight = ColorRect.new()
	player_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_highlight.size = Vector2(grid_state.cell_size, grid_state.cell_size)
	player_highlight.position = Vector2(pos.x * grid_state.cell_size, pos.y * grid_state.cell_size)
	player_highlight.color = Color(1, 1, 0, 0.7)  # жёлтый, ярче
	player_highlight.z_index = 10  # поверх сетки
	add_child(player_highlight)
	available_moves.append(player_highlight)
	
	# Подсвечиваем доступные для хода клетки
	for dx in range(-combat_state.action_points, combat_state.action_points + 1):
		for dy in range(-combat_state.action_points, combat_state.action_points + 1):
			var nx = pos.x + dx
			var ny = pos.y + dy
			if nx >= 0 and nx < grid_state.width and ny >= 0 and ny < grid_state.height:
				var dist = abs(dx) + abs(dy)
				if dist <= combat_state.action_points and dist > 0:
					if grid_state.is_walkable(nx, ny, unit_id):
						var highlight = ColorRect.new()
						highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
						highlight.size = Vector2(grid_state.cell_size, grid_state.cell_size)
						highlight.position = Vector2(nx * grid_state.cell_size, ny * grid_state.cell_size)
						highlight.color = Color(0, 1, 0, 0.5)
						highlight.z_index = 5
						add_child(highlight)
						available_moves.append(highlight)

func _clear_highlight():
	for child in available_moves:
		if is_instance_valid(child):
			child.queue_free()
	available_moves.clear()

func _on_game_message(text: String):
	print("Сообщение: ", text)
func _refresh_grid_keep_camera():
	if not grid_state:
		return
	
	# Сохраняем позицию и масштаб камеры
	var camera = get_viewport().get_camera_2d()
	var saved_position = camera.global_position if camera else Vector2.ZERO
	var saved_scale = camera.scale if camera else Vector2.ONE
	
	# Пересоздаём сетку
	for child in get_children():
		child.queue_free()
	_create_grid()
	
	# Восстанавливаем камеру
	if camera:
		camera.global_position = saved_position
		camera.scale = saved_scale

func _enter_door(exit_data: Dictionary):
	print("Переход через дверь: ", exit_data.description)
	game_controller.pending_action = "entering_door"
	
	var location_manager = get_node("/root/LocationManagerAuto")
	if not location_manager:
		print("LocationManager не найден!")
		return
	
	# ===== ПЕРЕМЕЩАЕМ ОБЪЯВЛЕНИЕ СЮДА, В НАЧАЛО =====
	var door_x = exit_data.get("x", 0)
	var door_y = exit_data.get("y", 0)
	# =============================================
	
	# ===== ПРОВЕРКА НА СУЩЕСТВУЮЩУЮ ЛОКАЦИЮ =====
	var target_id = exit_data.get("target_location_id", "")
	if target_id != "":
		var existing_location = location_manager.load_location(target_id)
		if existing_location:
			print("Локация уже существует, загружаем: ", target_id)
			location_manager.set_current_location(existing_location, Vector2i(door_x, door_y))
			game_controller.pending_action = ""
			return
	# =============================================
	
	var current_location = location_manager.current_location
	if not current_location:
		print("Текущая локация не найдена!")
		return
	
	# Ищем свободную клетку рядом с дверью для обратной двери
	var return_pos = _find_free_adjacent_cell(door_x, door_y)
	
	# Сохраняем информацию для обратной двери в game_controller
	game_controller.pending_return_location_id = current_location.id
	game_controller.pending_return_door_x = return_pos.x
	game_controller.pending_return_door_y = return_pos.y
	game_controller.pending_previous_location = current_location.name
	
	# Генерируем новую локацию
	print("Генерация новой локации...")
	var door_info = {
		"parent_location": current_location.id,
		"previous_location": current_location.name,
		"exit_description": exit_data.description,
		"return_location_id": current_location.id,
		"return_door_x": return_pos.x,
		"return_door_y": return_pos.y
	}
	
	game_controller.request_location_generation(door_info)
func _show_all_walkable_cells(unit_id: String):
	_clear_highlight()
	var pos = grid_state.get_unit_position(unit_id)
	if pos.x == -1:
		return
	
	# Подсвечиваем самого игрока жёлтым
	var player_highlight = ColorRect.new()
	player_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_highlight.size = Vector2(grid_state.cell_size, grid_state.cell_size)
	player_highlight.position = Vector2(pos.x * grid_state.cell_size, pos.y * grid_state.cell_size)
	player_highlight.color = Color(1, 1, 0, 0.7)
	player_highlight.z_index = 10
	add_child(player_highlight)
	available_moves.append(player_highlight)
	
	# Подсвечиваем все доступные клетки на карте (слабый зелёный)
	for x in range(grid_state.width):
		for y in range(grid_state.height):
			if x == pos.x and y == pos.y:
				continue
			if grid_state.is_walkable(x, y, unit_id):
				var highlight = ColorRect.new()
				highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
				highlight.size = Vector2(grid_state.cell_size, grid_state.cell_size)
				highlight.position = Vector2(x * grid_state.cell_size, y * grid_state.cell_size)
				highlight.color = Color(0, 1, 0, 0.15)  # более прозрачный для мирного режима
				highlight.z_index = 5
				add_child(highlight)
				available_moves.append(highlight)
func _update_highlight():
	_clear_highlight()
	if selected_unit_id == "":
		return
	
	if combat_state.mode == CombatState.GameMode.PEACEFUL:
		_show_all_walkable_cells(selected_unit_id)
	else:
		# В боевом режиме показываем подсветку, даже если action_points = 0
		# (только подсветка самого игрока)
		if combat_state.action_points > 0:
			_highlight_available_moves(selected_unit_id)
		else:
			# Показываем только жёлтую подсветку игрока
			_highlight_player_only(selected_unit_id)
func _highlight_player_only(unit_id: String):
	_clear_highlight()
	var pos = grid_state.get_unit_position(unit_id)
	if pos.x == -1:
		return
	
	# Только жёлтая подсветка игрока
	var player_highlight = ColorRect.new()
	player_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_highlight.size = Vector2(grid_state.cell_size, grid_state.cell_size)
	player_highlight.position = Vector2(pos.x * grid_state.cell_size, pos.y * grid_state.cell_size)
	player_highlight.color = Color(1, 1, 0, 0.7)
	player_highlight.z_index = 10
	add_child(player_highlight)
	available_moves.append(player_highlight)
func add_door(door: DoorData) -> void:
	if not grid_state:
		print("GridManager: grid_state не инициализирован, дверь не добавлена")
		return
	
	var door_key = str(door.position.x) + "_" + str(door.position.y)
	
	# Инициализируем словарь doors, если его нет
	if not "doors" in grid_state:
		grid_state.doors = {}
	
	# Проверяем, нет ли уже двери на этой позиции
	if grid_state.doors.has(door_key):
		print("GridManager: Дверь на позиции ", door.position, " уже существует, пропускаем")
		return
	
	grid_state.doors[door_key] = door
	print("GridManager: Дверь добавлена на позицию ", door.position)
# Ищет свободную соседнюю клетку (по горизонтали/вертикали) для размещения обратной двери
func _find_free_adjacent_cell(x: int, y: int) -> Vector2i:
	var directions = [
		Vector2i(1, 0),   # вправо
		Vector2i(-1, 0),  # влево
		Vector2i(0, 1),   # вниз
		Vector2i(0, -1)   # вверх
	]
	
	for dir in directions:
		var nx = x + dir.x
		var ny = y + dir.y
		# Проверяем границы
		if nx < 0 or nx >= grid_state.width or ny < 0 or ny >= grid_state.height:
			continue
		# Проверяем, что клетка проходима и не занята
		var tile_type = grid_state.tiles[nx][ny]["type"]
		if tile_type == GridState.TileType.WALL:
			continue
		var unit_key = str(nx) + "_" + str(ny)
		if grid_state.units.has(unit_key):
			continue
		var door_key = str(nx) + "_" + str(ny)
		if "doors" in grid_state and grid_state.doors.has(door_key):
			continue
		# Нашли свободную клетку
		return Vector2i(nx, ny)
	
	# Если все соседние заняты – возвращаем исходную позицию (на худой конец)
	printerr("Не найдено свободной клетки рядом с дверью! Ставим дверь поверх.")
	return Vector2i(x, y)
