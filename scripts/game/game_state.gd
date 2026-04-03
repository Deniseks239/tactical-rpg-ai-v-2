extends Resource
class_name GameState

var game_started: bool = false
var current_scene_name: String = "main_hall"
var gold: int = 0
var action_history: Array = []

func add_to_history(action_text: String, actor: String = "system"):
	action_history.append({
		"time": Time.get_unix_time_from_system(),
		"actor": actor,
		"action": action_text
	})
	if action_history.size() > 50:
		action_history.pop_front()

func to_dict() -> Dictionary:
	return {
		"game_started": game_started,
		"current_scene": current_scene_name,
		"gold": gold,
		"recent_actions": action_history.slice(-20)
	}
