# scripts/test_scene.gd
extends Node2D

var game_controller: GameController
var grid_state: GridState
var combat_state: CombatState

func _ready():
	game_controller = get_node("/root/GameControllerAuto")
	grid_state = game_controller.grid_state
	combat_state = game_controller.combat_state
	
	# Заполняем сетку тестовыми данными
	_setup_test_grid()
	
	# Спавним тестового NPC с квестом
	_spawn_test_npc()
	
	# Спавним врага
	_spawn_test_enemy()
	
	# Спавним предмет
	_spawn_test_item()

func _setup_test_grid():
	grid_state.width = 8
	grid_state.height = 8
	grid_state.initialize()
	# Заполним полом и поставим игрока
	for x in range(8):
		for y in range(8):
			grid_state.tiles[x][y]["type"] = GridState.TileType.FLOOR
	grid_state.set_unit("player_1", "Тестер", "player", 4, 4)

func _spawn_test_npc():
	grid_state.set_unit("npc_test", "Тестовый Житель", "npc", 2, 2)
	var pos_key = "2_2"
	grid_state.units[pos_key]["npc_id"] = "npc_test_1"
	grid_state.units[pos_key]["npc_type"] = "guard"  # тип для диалога
	# Регистрируем в кампании (чтобы диалог работал)
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
					"objective_type": "kill_enemy",
					"objective_target": "тестовый враг",
					"target_count": 1,
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
	# Просто ставим сундук на карте
	grid_state.objects["3_3"] = {"type": "chest", "name": "Сундук"}
	grid_state.tiles[3][3]["type"] = GridState.TileType.CHEST
