extends Control

@onready var chat_display = $UIPanel/VBoxContainer/ChatDisplay
@onready var input_field = $UIPanel/VBoxContainer/HBoxContainer/InputField
@onready var send_button = $UIPanel/VBoxContainer/HBoxContainer/SendButton

# Кнопки камеры (если есть)
@onready var zoom_in_button = $UIPanel/ZoomIn if has_node("UIPanel/ZoomIn") else null
@onready var zoom_out_button = $UIPanel/ZoomOut if has_node("UIPanel/ZoomOut") else null
@onready var center_button = $UIPanel/CenterCamera if has_node("UIPanel/CenterCamera") else null

func _ready():
	# Подключаем чат
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_send_pressed)
	
	# Подключаем камеру
	_setup_camera_buttons()

func _setup_camera_buttons():
	if zoom_in_button:
		zoom_in_button.pressed.connect(_zoom_in)
	if zoom_out_button:
		zoom_out_button.pressed.connect(_zoom_out)
	if center_button:
		center_button.pressed.connect(_center_camera)

func _zoom_in():
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.scale *= 0.9

func _zoom_out():
	var camera = get_viewport().get_camera_2d()
	if camera:
		camera.scale *= 1.1

func _center_camera():
	var camera = get_viewport().get_camera_2d()
	if camera:
		# Находим GridManager
		var grid_manager = $GridContainer/GridManager if has_node("GridContainer/GridManager") else null
		if not grid_manager:
			grid_manager = $GridManager if has_node("GridManager") else null
		
		if grid_manager and grid_manager.grid_state:
			var map_width = grid_manager.grid_state.width * grid_manager.grid_state.cell_size
			var map_height = grid_manager.grid_state.height * grid_manager.grid_state.cell_size
			camera.global_position = Vector2(map_width / 2, map_height / 2)

func _on_send_pressed(text: String = ""):
	print("SendButton нажата! Текст: ", input_field.text)
	var message = text if text != "" else input_field.text
	if message.is_empty():
		print("Пустое сообщение")
		return
	add_message("Вы: " + message)
	input_field.clear()
	game_controller.process_player_action(message)

func add_message(msg: String):
	chat_display.add_text(msg + "\n")
	chat_display.scroll_to_line(chat_display.get_line_count() - 1)
