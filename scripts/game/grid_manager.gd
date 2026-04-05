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
					rect.color = Color(0.3, 0.3, 0.3, 1.0)
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
			add_child(rect)
			var is_exit = false
			var location_manager = get_node("/root/LocationManagerAuto")
			if location_manager and location_manager.current_location:
				for exit_data in location_manager.current_location.exits:
					if exit_data.x == x and exit_data.y == y:
						is_exit = true
						break
			if is_exit:
				# Делаем клетку другого цвета или добавляем рамку
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

func _on_cell_pressed(x: int, y: int):
	print("Клик по клетке ", x, ",", y)
	
	if game_controller.is_waiting_for_ai:
		game_controller.game_message.emit("Подождите, AI описывает происходящее...")
		return
	
	if game_controller.game_over:
		print("Игра окончена")
		return
	
	# Проверка на выход (дверь)
	if selected_unit_id == "player_1" or selected_unit_id == "":
		var location_manager = get_node("/root/LocationManagerAuto")
		if location_manager and location_manager.current_location:
			for exit_data in location_manager.current_location.exits:
				if exit_data.x == x and exit_data.y == y:
					_enter_door(exit_data)
					return
	
	# РАЗЛИЧИЕ: Мирный vs Боевой режим
	if combat_state.mode == CombatState.GameMode.PEACEFUL:
		# Мирный режим: свободное перемещение
		if selected_unit_id != "":
			_move_unit_free(selected_unit_id, x, y)
		else:
			var pos_key = str(x) + "_" + str(y)
			if grid_state.units.has(pos_key):
				var unit = grid_state.units[pos_key]
				if unit["type"] == "player":
					selected_unit_id = unit["id"]
					print("Выбран игрок: ", selected_unit_id)
		return
	
	# Боевой режим: с очками действий
	print("is_player_turn = ", combat_state.is_player_turn())
	if not combat_state.is_player_turn():
		print("Сейчас ход врагов, подождите")
		return
	
	game_controller.game_message.emit("🖱️ Обработка действия...")
	
	if selected_unit_id != "":
		print("Попытка атаковать/переместить юнита: ", selected_unit_id)
		var target_key = str(x) + "_" + str(y)
		if grid_state.units.has(target_key):
			var target = grid_state.units[target_key]
			if target["type"] == "enemy":
				_attack(selected_unit_id, target["id"])
				return
		_try_move_unit(selected_unit_id, x, y)
	else:
		var pos_key = str(x) + "_" + str(y)
		if grid_state.units.has(pos_key):
			var unit = grid_state.units[pos_key]
			if unit["type"] == "player":
				selected_unit_id = unit["id"]
				_highlight_available_moves(selected_unit_id)
				print("Выбран игрок: ", selected_unit_id)

# Новая функция для мирного перемещения (без ограничений)
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
	
	# Объявляем переменную damage здесь
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
		else:
			refresh_grid()
	
	# Добавляем событие в очередь
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
	
	if combat_state.action_points <= 0:
		selected_unit_id = ""
		_clear_highlight()
		refresh_grid()
		game_controller.end_player_turn()

func _try_move_unit(unit_id: String, target_x: int, target_y: int):
	var start_pos = grid_state.get_unit_position(unit_id)
	if start_pos.x == -1:
		return
	var distance = abs(target_x - start_pos.x) + abs(target_y - start_pos.y)
	if distance <= combat_state.action_points:
		if grid_state.is_walkable(target_x, target_y, unit_id):
			var unit_data = grid_state.units[str(start_pos.x) + "_" + str(start_pos.y)]
			grid_state.remove_unit(unit_id)
			grid_state.set_unit(unit_id, unit_data["name"], unit_data["type"], target_x, target_y)
			combat_state.spend_action_points(distance)
			selected_unit_id = ""
			_clear_highlight()
			refresh_grid()
			print("Юнит перемещен на ", target_x, ",", target_y)
			
			if combat_state.action_points <= 0:
				game_controller.end_player_turn()
		else:
			print("Клетка ", target_x, ",", target_y, " недоступна")
	else:
		print("Слишком далеко")

func _highlight_available_moves(unit_id: String):
	_clear_highlight()
	var pos = grid_state.get_unit_position(unit_id)
	if pos.x == -1:
		return
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
						highlight.color = Color(0, 1, 0, 0.3)
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
	
	var location_manager = get_node("/root/LocationManagerAuto")
	if not location_manager:
		print("LocationManagerAuto не найден!")
		return
	
	var target_id = exit_data.get("target_location_id", "")
	
	if target_id != "":
		# Загружаем существующую локацию
		var target_location = location_manager.load_location(target_id)
		if target_location:
			location_manager.set_current_location(target_location)
			return
	
	# Генерируем новую локацию
	print("Генерация новой локации...")
	game_controller.request_location_generation({
		"parent_location": location_manager.current_location.id if location_manager.current_location else "",
		"door_id": exit_data.get("target_door_id", ""),
		"previous_location": location_manager.current_location.name if location_manager.current_location else "Неизвестно",
		"exit_description": exit_data.description
	})
