# scripts/ui/main_menu.gd
extends Control

# Назначаются в редакторе
@export var new_game_button: Button
@export var load_button: Button
@export var quit_button: Button
@export var status_label: Label

var server_started = false

func _ready():
	# Сразу запускаем сервер в фоне
	_start_llama_server()
	
	# Подключаем сигналы кнопок (только если кнопки назначены)
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		load_button.disabled = true  # Пока нет сохранений
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _start_llama_server():
	if status_label:
		status_label.text = "Запуск ИИ-сервера..."
	var gm = get_node("/root/GameControllerAuto")
	if gm:
		gm._start_llama_server()
		# Ждём готовности сервера
		while not gm.llama_ready:
			await get_tree().create_timer(0.5).timeout
		if status_label:
			status_label.text = "Сервер готов"
		server_started = true
	else:
		if status_label:
			status_label.text = "Ошибка: GameController не найден"

func _on_new_game_pressed():
	if not server_started:
		if status_label:
			status_label.text = "Подождите, сервер ещё не готов"
		return
	# Переход на сцену создания персонажа
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")

func _on_load_pressed():
	# Заглушка для будущей загрузки сохранения
	pass

func _on_quit_pressed():
	get_tree().quit()
