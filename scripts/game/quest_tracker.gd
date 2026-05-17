# scripts/game/quest_tracker.gd
extends Node
class_name QuestTracker

var active_quests: Dictionary = {}
var completed_quests: Array = []

signal quest_accepted(quest_id: String, title: String)
signal quest_completed(quest_id: String, title: String)
signal quest_progress_updated(quest_id: String, progress: int, target: int)

func accept_quest(quest_id: String, title: String, description: String, objective_type: String, objective_target: String, target_count: int, reward: String):
	if active_quests.has(quest_id) or quest_id in completed_quests:
		return
	
	active_quests[quest_id] = {
		"title": title,
		"description": description,
		"objective_type": objective_type,
		"objective_target": objective_target,
		"target_count": target_count,
		"progress": 0,
		"reward": reward,
		"is_completed": false
	}
	quest_accepted.emit(quest_id, title)
	print("QuestTracker: квест принят — ", title)

func update_progress(quest_id: String, amount: int = 1):
	if not active_quests.has(quest_id):
		return
	
	var quest = active_quests[quest_id]
	if quest["is_completed"]:
		return
	
	quest["progress"] = min(quest["progress"] + amount, quest["target_count"])
	quest_progress_updated.emit(quest_id, quest["progress"], quest["target_count"])
	
	if quest["progress"] >= quest["target_count"]:
		quest["is_completed"] = true
		quest_completed.emit(quest_id, quest["title"])
		print("QuestTracker: квест завершён — ", quest["title"])

func check_progress_by_type(objective_type: String, objective_target: String):
	for quest_id in active_quests:
		var quest = active_quests[quest_id]
		if quest["is_completed"]:
			continue
		if quest["objective_type"] == objective_type and quest["objective_target"] == objective_target:
			update_progress(quest_id)

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id) and not active_quests[quest_id]["is_completed"]

func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests

func get_quest_info(quest_id: String) -> Dictionary:
	if active_quests.has(quest_id):
		return active_quests[quest_id]
	return {}
