# scripts/ai/dnd_rules.gd
extends Node
class_name DNDRules

# Основные правила (краткая версия)
static func get_combat_rules() -> String:
	return """
ПРАВИЛА БОЯ D&D:
- Каждый ход: ДЕЙСТВИЕ (атака, заклинание) + ПЕРЕМЕЩЕНИЕ (до 3 клеток)
- Атака: бросок d20 + бонус атаки >= Класс Доспеха (AC) цели → попадание
- Урон: 1d6+2 (меч), 1d8+3 (двуручный меч)
- Критическое попадание: при броске 20 → двойной урон
- Критический промах: при броске 1 → автоматом промах
"""

static func get_enemy_info(enemy_type: String) -> String:
	var enemies = {
		"goblin": "Гоблин: AC 10, HP 8, атака +2, урон 1d6+1",
		"skeleton": "Скелет: AC 12, HP 10, атака +3, урон 1d6+2",
		"orc": "Орк: AC 14, HP 15, атака +5, урон 1d8+3",
	}
	return enemies.get(enemy_type, "Неизвестный враг")

static func get_class_abilities(class_name: String) -> String:
	var abilities = {
		"warrior": "Воин: может использовать 'Яростный удар' (доп. +2 к урону)",
		"mage": "Маг: может использовать 'Магическую стрелу' (дистанционная атака)",
		"rogue": "Разбойник: может использовать 'Скрытность' (+5 к уклонению)",
	}
	return abilities.get(class_name, "Неизвестный класс")
