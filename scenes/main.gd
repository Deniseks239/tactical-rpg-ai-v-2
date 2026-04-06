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

	if skip_turn_button:
		skip_turn_button.pressed.connect(_skip_turn)
		print("SkipTurnButton подключена")

func _skip_turn():
	print("SkipTurnButton нажата!")
	if game_controller:
		game_controller.skip_turn()

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
