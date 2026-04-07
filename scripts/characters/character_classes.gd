extends Node
class_name CharacterClasses

static var classes = {
	"warrior": {
		"name": "Воин",
		"description": "Мастер ближнего боя, сильный и выносливый",
		"base_hp": 12,
		"base_ac": 16,
		"base_strength": 16,
		"base_dexterity": 12,
		"base_constitution": 14,
		"starting_items": ["меч", "щит", "кожаный доспех"]
	},
	"mage": {
		"name": "Маг",
		"description": "Повелитель магии, хрупкий но опасный",
		"base_hp": 8,
		"base_ac": 12,
		"base_intelligence": 16,
		"base_wisdom": 14,
		"base_charisma": 12,
		"starting_items": ["посох", "книга заклинаний", "мантия"]
	},
	"rogue": {
		"name": "Разбойник",
		"description": "Скрытный и ловкий мастер уклонения",
		"base_hp": 10,
		"base_ac": 14,
		"base_dexterity": 16,
		"base_intelligence": 14,
		"base_charisma": 12,
		"starting_items": ["кинжал", "кожаный доспех", "отмычки"]
	},
	"cleric": {
		"name": "Жрец",
		"description": "Священный воин, лечит и защищает",
		"base_hp": 10,
		"base_ac": 16,
		"base_strength": 14,
		"base_wisdom": 16,
		"base_charisma": 12,
		"starting_items": ["булава", "щит", "символ веры"]
	}
}

static var races = {
	"human": {"name": "Человек", "bonus_strength": 1, "bonus_dexterity": 1, "bonus_constitution": 1},
	"elf": {"name": "Эльф", "bonus_dexterity": 2, "bonus_intelligence": 1},
	"dwarf": {"name": "Дворф", "bonus_strength": 2, "bonus_constitution": 1},
	"halfling": {"name": "Полурослик", "bonus_dexterity": 2, "bonus_charisma": 1}
}

static func get_class_info(class_type: String) -> Dictionary:
	return classes.get(class_type, classes["warrior"])

static func get_race_info(race_type: String) -> Dictionary:
	return races.get(race_type, races["human"])
