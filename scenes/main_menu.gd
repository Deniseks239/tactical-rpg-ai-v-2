# scripts/ui/main_menu.gd
extends Control

@export var new_game_button: Button
@export var load_button: Button
@export var quit_button: Button
@export var status_label: Label

var server_started = false

func _ready():
	# Подключаем сигнал готовности сервера
	var gm = get_node("/root/GameControllerAuto")
	if gm:
		if gm.llama_ready:
			_on_server_ready()
		else:
			gm.llama_server_ready.connect(_on_server_ready)
		if status_label:
			status_label.text = "Ожидание ИИ-сервера..."
	else:
		if status_label:
			status_label.text = "Ошибка: GameController не найден"
	
	# Подключаем кнопки
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		load_button.disabled = true
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_server_ready():
	server_started = true
	if status_label:
		status_label.text = "Сервер готов"

func _on_new_game_pressed():
	print("Нажата кнопка Новая игра. server_started = ", server_started)
	if not server_started:
		if status_label:
			status_label.text = "Подождите, сервер ещё не готов"
		return
	print("Пытаюсь перейти к сцене: res://scenes/character_creator.tscn")
	# Переход на сцену создания персонажа
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")

func _on_load_pressed():
	pass

func _on_quit_pressed():
	get_tree().quit()
func _change_to_character_creator():
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")
