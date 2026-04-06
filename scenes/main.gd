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
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.scale *= 0.9

func _zoom_out():
	print("ZoomOut нажата!")
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.scale *= 1.1

func _center_camera():
	print("CenterCamera нажата!")
	var camera = get_viewport().get_camera_2d()
	if camera:
		var grid_manager = $GridContainer/GridManager if has_node("GridContainer/GridManager") else null
		if not grid_manager:
			grid_manager = $GridManager if has_node("GridManager") else null
		if grid_manager and grid_manager.grid_state:
			var map_width = grid_manager.grid_state.width * grid_manager.grid_state.cell_size
			var map_height = grid_manager.grid_state.height * grid_manager.grid_state.cell_size
			camera.global_position = Vector2(map_width / 2, map_height / 2)

func _skip_turn():
	print("SkipTurnButton нажата!")
	if game_controller:
		game_controller.skip_turn()
	else:
		print("GameController не найден!")

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
