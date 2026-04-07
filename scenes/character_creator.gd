extends Control

var CharacterData = preload("res://scripts/characters/character_data.gd")

@onready var name_input = $MainPanel/MainVBox/NameRow/NameInput
@onready var class_select = $MainPanel/MainVBox/ClassRow/ClassSelect
@onready var race_select = $MainPanel/MainVBox/RaceRow/RaceSelect
@onready var create_button = $MainPanel/MainVBox/CreateButton
@onready var start_button = $MainPanel/MainVBox/StartButton

var current_character: CharacterData = null

func _ready():
	# Центрирование панели
	var panel = $MainPanel
	if panel:
		var screen_size = get_viewport().get_visible_rect().size
		var panel_size = panel.size
		panel.position = (screen_size - panel_size) / 2
		print("Панель центрирована на ", panel.position)
	
	# Размеры элементов
	name_input.size.x = 200
	class_select.size.x = 200
	race_select.size.x = 200
	
	# Заполняем список классов
	class_select.clear()
	for class_key in CharacterClassesAuto.classes.keys():
		var class_display_name = CharacterClassesAuto.classes[class_key]["name"]
		class_select.add_item(class_display_name)
	
	# Заполняем список рас
	race_select.clear()
	for race_key in CharacterClassesAuto.races.keys():
		var race_name = CharacterClassesAuto.races[race_key]["name"]
		race_select.add_item(race_name)
	
	# Отладка
	print("Классы в OptionButton: ", class_select.item_count)
	print("Расы в OptionButton: ", race_select.item_count)
	
	# Подключаем сигналы
	create_button.pressed.connect(_create_character)
	start_button.pressed.connect(_start_game)
	
	# Начальное состояние
	start_button.disabled = true
	
	print("Character Creator готов")

func _create_character():
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Арагорн"
	
	var class_index = class_select.get_selected_index()
	var race_index = race_select.get_selected_index()
	
	var class_key = CharacterClassesAuto.classes.keys()[class_index]
	var race_key = CharacterClassesAuto.races.keys()[race_index]
	
	var class_info = CharacterClassesAuto.get_class_info(class_key)
	var race_info = CharacterClassesAuto.get_race_info(race_key)
	
	current_character = CharacterData.new()
	current_character.id = "player_" + str(randi())
	current_character.character_name = player_name
	current_character.class_type = class_key
	current_character.race = race_key
	current_character.hp = class_info["base_hp"]
	current_character.max_hp = class_info["base_hp"]
	current_character.ac = class_info["base_ac"]
	current_character.inventory = class_info["starting_items"]
	
	# Применяем бонусы расы
	current_character.strength = class_info.get("base_strength", 10) + race_info.get("bonus_strength", 0)
	current_character.dexterity = class_info.get("base_dexterity", 10) + race_info.get("bonus_dexterity", 0)
	current_character.constitution = class_info.get("base_constitution", 10) + race_info.get("bonus_constitution", 0)
	
	current_character.save()
	
	create_button.text = "✓ Создано!"
	create_button.disabled = true
	start_button.disabled = false
	
	print("Создан персонаж: ", current_character.character_name, " (", class_info["name"], ", ", race_info["name"], ")")

func _start_game():
	if current_character:
		var game_controller = get_node("/root/GameControllerAuto")
		if game_controller:
			game_controller.start_with_character(current_character)
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		else:
			print("GameController не найден!")
