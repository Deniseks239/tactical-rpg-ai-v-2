extends Node
class_name NPC_Types

static func get_npc_type_info(npc_type: String) -> Dictionary:
	var types = {
		"commoner": {
			"personality": "обычный житель, немного напуганный",
			"knowledge": ["местные слухи", "где находится таверна"],
			"max_memory": 2
		},
		"guard": {
			"personality": "суровый стражник порядка",
			"knowledge": ["правила города", "преступления в округе"],
			"max_memory": 3
		},
		"trader": {
			"personality": "хитрый торговец, ищущий выгоду",
			"knowledge": ["цены на товары", "где достать редкие вещи"],
			"max_memory": 4
		},
		"child": {
			"personality": "любопытный ребёнок",
			"knowledge": ["сплетни", "где можно спрятаться"],
			"max_memory": 1
		}
	}
	return types.get(npc_type, types["commoner"])
