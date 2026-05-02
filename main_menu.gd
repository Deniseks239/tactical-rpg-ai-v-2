# scripts/ui/main_menu.gd
extends Control

# Ссылки на кнопки (назначьте их в редакторе)
@onready var new_game_button: Button = $Panel/VBoxContainer/NewGameButton
@onready var load_button: Button = $Panel/VBoxContainer/LoadButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton
@onready var status_label: Label = $Panel/StatusLabel

var server_started = false

func _ready():
	# Сразу запускаем сервер в фоне
	_start_llama_server()
	
	# Подключаем сигналы кнопок
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Кнопка загрузки пока неактивна (нет сохранений)
	load_button.disabled = true

func _start_llama_server():
	status_label.text = "Запуск ИИ-сервера..."
	var gm = get_node("/root/GameControllerAuto")
	if gm:
		gm._start_llama_server()
		# Ждём готовности сервера
		while not gm.llama_ready:
			await get_tree().create_timer(0.5).timeout
		status_label.text = "Сервер готов"
		server_started = true
	else:
		status_label.text = "Ошибка: GameController не найден"

func _on_new_game_pressed():
	if not server_started:
		status_label.text = "Подождите, сервер ещё не готов"
		return
	# Переход на сцену создания персонажа
	get_tree().change_scene_to_file("res://scenes/character_creator.tscn")

func _on_load_pressed():
	# Заглушка для будущей загрузки сохранения
	pass

func _on_quit_pressed():
	get_tree().quit()
