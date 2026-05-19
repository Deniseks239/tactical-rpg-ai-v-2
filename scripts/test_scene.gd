extends Node2D

var game_controller: GameController
var grid_state: GridState
var combat_state: CombatState
var grid_manager: GridManager

func _ready():
	game_controller = get_node("/root/GameControllerAuto")
	grid_state = game_controller.grid_state
	combat_state = game_controller.combat_state
	
	# Создаём GridManager и добавляем его на сцену
	grid_manager = GridManager.new()
	add_child(grid_manager)
	
	# Добавляем камеру, чтобы контекстное меню работало
	# Добавляем камеру с правильным масштабом и позицией
	var camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	
	# Настраиваем масштаб как в основной игре
	var viewport_size = get_viewport().get_visible_rect().size
	var map_width = grid_state.width * grid_state.cell_size
	var map_height = grid_state.height * grid_state.cell_size
	var zoom_x = viewport_size.x / map_width
	var zoom_y = viewport_size.y / map_height
	var zoom = min(zoom_x, zoom_y) * 0.9
	camera.zoom = Vector2(zoom, zoom)
	
	# Центрируем камеру на карте
	camera.global_position = Vector2(map_width / 2, map_height / 2)
	
	# Заполняем сетку тестовыми данными
	_setup_test_grid()
	
	# Спавним тестового NPC с квестом
	_spawn_test_npc()
	
	# Спавним врага
	_spawn_test_enemy()
	
	# Спавним предмет
	_spawn_test_item()
	
	# Отрисовываем сетку
	grid_manager.refresh_grid()

func _setup_test_grid():
	grid_state.width = 8
	grid_state.height = 8
	grid_state.initialize()
	for x in range(8):
		for y in range(8):
			grid_state.tiles[x][y]["type"] = GridState.TileType.FLOOR
	grid_state.set_unit("player_1", "Тестер", "player", 4, 4)

func _spawn_test_npc():
	grid_state.set_unit("npc_test", "Тестовый Житель", "npc", 2, 2)
	var pos_key = "2_2"
	grid_state.units[pos_key]["npc_id"] = "npc_test_1"
	grid_state.units[pos_key]["npc_type"] = "guard"
	var campaign_mgr = get_node_or_null("/root/CampaignManagerAuto")
	if campaign_mgr:
		if not campaign_mgr.campaign_data.has("npcs"):
			campaign_mgr.campaign_data["npcs"] = []
		campaign_mgr.campaign_data["npcs"].append({
			"id": "npc_test_1",
			"name": "Тестовый Житель",
			"role": "стражник",
			"personality": "суровый",
			"knowledge": ["знает про квест"],
			"quests": [
				{
					"title": "Тестовый квест",
					"description": "Убей тестового врага",
					"reward": "100 золота"
				}
			]
		})

func _spawn_test_enemy():
	grid_state.set_unit("enemy_test", "Тестовый Враг", "enemy", 5, 5)
	combat_state.add_unit("enemy_test", {
		"name": "Тестовый Враг",
		"type": "enemy",
		"hp": 10,
		"max_hp": 10,
		"ac": 10,
		"attack_bonus": 2
	})

func _spawn_test_item():
	grid_state.objects["3_3"] = {"type": "chest", "name": "Сундук"}
	grid_state.tiles[3][3]["type"] = GridState.TileType.CHEST
