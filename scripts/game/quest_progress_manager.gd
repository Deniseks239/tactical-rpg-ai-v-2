# scripts/game/quest_progress_manager.gd
extends Node
class_name QuestProgressManager

func _ready():
	# Подключаемся к сигналам, когда узлы станут доступны
	await get_tree().process_frame
	
	# Сигнал смерти врага
	var game_controller = get_node("/root/GameControllerAuto")
	if game_controller:
		game_controller.combat_state.enemy_killed.connect(_on_enemy_killed)
	
	# Сигнал входа в локацию
	var location_manager = get_node("/root/LocationManagerAuto")
	if location_manager:
		location_manager.location_entered.connect(_on_location_entered)

func _on_enemy_killed(enemy_name: String):
	var tracker = get_node("/root/QuestTrackerAuto")
	if tracker:
		tracker.check_progress_by_type("kill_enemy", enemy_name.to_lower())

func _on_location_entered(location_id: String):
	var tracker = get_node("/root/QuestTrackerAuto")
	if tracker:
		tracker.check_progress_by_type("visit_location", location_id)
