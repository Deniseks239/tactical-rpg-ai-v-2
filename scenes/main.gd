extends Control

@onready var game_controller = get_node("/root/GameControllerAuto")

@onready var chat_display = $UIPanel/VBoxContainer/ChatDisplay
@onready var input_field = $UIPanel/VBoxContainer/HBoxContainer/InputField
@onready var send_button = $UIPanel/VBoxContainer/HBoxContainer/SendButton

# Кнопки камеры
@onready var zoom_in_button = $ZoomIn if has_node("ZoomIn") else null
@onready var zoom_out_button = $ZoomOut if has_node("ZoomOut") else null
@onready var center_button = $CenterCamera if has_node("CenterCamera") else null
@onready var skip_turn_button = $SkipTurnButton if has_node("SkipTurnButton") else null

func _ready():
	# Подключаем кнопки чата
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
		print("SendButton подключена")
	if input_field:
		input_field.text_submitted.connect(_on_send_pressed)
		print("InputField подключен")
	
	# Подключаем кнопки камеры
	if zoom_in_button:
		zoom_in_button.pressed.connect(_zoom_in)
		print("ZoomIn подключена")
	if zoom_out_button:
		zoom_out_button.pressed.connect(_zoom_out)
		print("ZoomOut подключена")
	if center_button:
		center_button.pressed.connect(_center_camera)
		print("CenterCamera подключена")
	if skip_turn_button:
		skip_turn_button.pressed.connect(_skip_turn)
		print("SkipTurnButton подключена")

func _zoom_in():
	print("ZoomIn нажата!")
	var grid_manager = $GridContainer/GridManager
	if grid_manager:
		grid_manager.target_scale *= 0.9
		grid_manager.target_scale = clamp(grid_manager.target_scale, 0.3, 2.0)
		grid_manager.scale = Vector2(grid_manager.target_scale, grid_manager.target_scale)

func _zoom_out():
	print("ZoomOut нажата!")
	var grid_manager = $GridContainer/GridManager
	if grid_manager:
		grid_manager.target_scale *= 1.1
		grid_manager.target_scale = clamp(grid_manager.target_scale, 0.3, 2.0)
		grid_manager.scale = Vector2(grid_manager.target_scale, grid_manager.target_scale)

func _center_camera():
	print("CenterCamera нажата!")
	var grid_manager = $GridContainer/GridManager
	if grid_manager and grid_manager.grid_state:
		var map_width = grid_manager.grid_state.width * grid_manager.grid_state.cell_size
		var map_height = grid_manager.grid_state.height * grid_manager.grid_state.cell_size
		var zoom = grid_manager.target_scale
		var center_x = (map_width / 2) * zoom
		var center_y = (map_height / 2) * zoom
		grid_manager.position = Vector2(center_x, center_y)

func skip_turn():
	print("=== skip_turn вызван ===")
	if game_over:
		return
	
	# Если бой идёт и это ход игрока
	if combat_state.mode == CombatState.GameMode.COMBAT and combat_state.is_player_turn():
		print("Пропуск хода игрока в бою")
		combat_state.action_points = 0
		end_player_turn()
	elif combat_state.mode == CombatState.GameMode.PEACEFUL:
		print("Сейчас мирный режим, пропуск хода не нужен")
		game_message.emit("Вы не в бою")
	else:
		print("Сейчас ход врагов")
		game_message.emit("Сейчас ход врагов, подождите")

func _on_send_pressed(text: String = ""):
	print("SendButton нажата! Текст: ", input_field.text)
	var message = text if text != "" else input_field.text
	if message.is_empty():
		print("Пустое сообщение")
		return
	add_message("Вы: " + message)
	input_field.clear()
	if game_controller:
		game_controller.process_player_action(message)
	else:
		print("GameController не найден!")

func add_message(msg: String):
	if chat_display:
		chat_display.add_text(msg + "\n")
		chat_display.scroll_to_line(chat_display.get_line_count() - 1)
