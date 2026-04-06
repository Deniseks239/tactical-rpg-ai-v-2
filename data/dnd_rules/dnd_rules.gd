extends Node
class_name DNDRules

static func get_combat_rules() -> String:
	return "ПРАВИЛА БОЯ D&D: Каждый ход: ДЕЙСТВИЕ + ПЕРЕМЕЩЕНИЕ. Атака: бросок d20 + бонус атаки >= AC цели -> попадание."

static func get_enemy_info(enemy_type: String) -> String:
	var enemies = {
		"goblin": "Гоблин: AC 10, HP 8, атака +2, урон 1d6+1",
		"skeleton": "Скелет: AC 12, HP 10, атака +3, урон 1d6+2",
		"orc": "Орк: AC 14, HP 15, атака +5, урон 1d8+3"
	}
	return enemies.get(enemy_type, "Неизвестный враг")

static func get_class_abilities(class_type: String) -> String:
	var abilities = {
		"warrior": "Воин: Яростный удар (+2 к урону)",
		"mage": "Маг: Магическая стрела (дистанционная атака)",
		"rogue": "Разбойник: Скрытность (+5 к уклонению)"
	}
	return abilities.get(class_type, "Неизвестный класс")
