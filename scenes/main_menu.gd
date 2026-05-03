extends Control

@export var new_game_button: Button
@export var load_button: Button
@export var quit_button: Button
@export var status_label: Label

var server_started: bool = false
var _poll_timer: Timer

func _ready():
	print("MainMenu: инициализация")
	
	# Подключаем кнопки
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		load_button.disabled = true
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# Запускаем таймер опроса состояния сервера
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.timeout.connect(_poll_server_status)
	add_child(_poll_timer)
	_poll_timer.start()
	
	_poll_server_status()

func _poll_server_status():
	var gm = get_node("/root/GameControllerAuto")
	if gm and gm.llama_ready:
		if not server_started:
			server_started = true
			if status_label:
				status_label.text = "Сервер готов"
			_poll_timer.stop()
	elif status_label:
		status_label.text = "Ожидание ИИ-сервера..."

func _on_new_game_pressed():
	print("MainMenu: нажата Новая игра, server_started = ", server_started)
	if not server_started:
		if status_label:
			status_label.text = "Подождите, сервер ещё не готов"
		return
	
	print("MainMenu: переход на создание персонажа")
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")

func _on_load_pressed():
	pass

func _on_quit_pressed():
	get_tree().quit()
