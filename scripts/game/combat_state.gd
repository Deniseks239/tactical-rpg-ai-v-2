extends Resource
class_name CombatState

enum Phase { EXPLORATION, COMBAT }
enum GameMode { PEACEFUL, COMBAT }
var mode: GameMode = GameMode.PEACEFUL
var phase: Phase = Phase.EXPLORATION
var initiative_order: Array = []
var current_turn_index: int = 0
var action_points: int = 3
var units: Dictionary = {}  # unit_id -> данные

func enter_combat():
	mode = GameMode.COMBAT
	phase = Phase.COMBAT
	_calculate_initiative()

func exit_combat():
	mode = GameMode.PEACEFUL
	phase = Phase.EXPLORATION

func _calculate_initiative():
	# Простейший расчёт инициативы: все юниты по порядку
	initiative_order = []
	for unit_id in units.keys():
		initiative_order.append(unit_id)
	# Можно добавить бросок кубика для каждого

func check_combat_start(player_attacked: bool, enemy_noticed_player: bool):
	if mode == GameMode.PEACEFUL:
		if player_attacked or enemy_noticed_player:
			enter_combat()
			return true
	return false
func add_unit(unit_id: String, data: Dictionary):
	units[unit_id] = data

func remove_unit(unit_id: String):
	units.erase(unit_id)
	var idx = initiative_order.find(unit_id)
	if idx != -1:
		initiative_order.remove_at(idx)

func get_current_unit() -> Dictionary:
	if initiative_order.is_empty():
		return {}
	var unit_id = initiative_order[current_turn_index]
	return units.get(unit_id, {})

func get_current_unit_id() -> String:
	if initiative_order.is_empty():
		return ""
	return initiative_order[current_turn_index]

func next_turn():
	current_turn_index += 1
	if current_turn_index >= initiative_order.size():
		current_turn_index = 0
	action_points = 3

func reset_action_points():
	action_points = 3

func spend_action_points(amount: int):
	action_points -= amount
	if action_points < 0:
		action_points = 0

func is_player_turn() -> bool:
	if initiative_order.is_empty():
		return false
	var current_id = initiative_order[current_turn_index]
	if units.has(current_id):
		return units[current_id].get("type") == "player"
	return false

func get_all_enemies() -> Array:
	var enemies = []
	for unit_id in units.keys():
		if units[unit_id].get("type") == "enemy":
			enemies.append(unit_id)
	return enemies

func calculate_damage(damage_dice: String) -> int:
	var parts = damage_dice.split("d")
	if parts.size() != 2:
		return 3
	var count = int(parts[0])
	var rest = parts[1]
	var bonus = 0
	var dice_size = 0
	
	if rest.find("+") != -1:
		var sub_parts = rest.split("+")
		dice_size = int(sub_parts[0])
		bonus = int(sub_parts[1])
	else:
		dice_size = int(rest)
	
	var total = 0
	for i in range(count):
		total += randi() % dice_size + 1
	return total + bonus

func to_dict() -> Dictionary:
	var units_data = {}
	for unit_id in units.keys():
		var u = units[unit_id]
		units_data[unit_id] = {
			"name": u.get("name", "Unknown"),
			"type": u.get("type", "enemy"),
			"hp": u.get("hp", 0),
			"max_hp": u.get("max_hp", 0),
			"ac": u.get("ac", 10),
			"attack_bonus": u.get("attack_bonus", 3),
			"damage_dice": u.get("damage_dice", "1d6+2"),
			"weapon_type": u.get("weapon_type", "melee"),
			"alive": u.get("hp", 0) > 0
		}
	return {
		"phase": "combat" if phase == Phase.COMBAT else "exploration",
		"initiative_order": initiative_order,
		"current_turn": get_current_unit().get("name", "None"),
		"action_points": action_points,
		"units": units_data
	}
