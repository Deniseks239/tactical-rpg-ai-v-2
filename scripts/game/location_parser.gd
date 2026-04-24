# scripts/game/location_parser.gd
extends Node
class_name LocationParser

# Главная функция парсинга
static func parse_location_description(description: String) -> Dictionary:
	var params = {
		"location_name": "Неизвестная локация",
		"biome": "dungeon",
		"size": 8,
		"enemies": [],
		"npcs": [],
		"exits": [],
		"player_start": [4, 4],
		"description": description,
		"location_type": "default",
		"generator": "default"
	}
	
	var lower_desc = description.to_lower()
	
	var location_info = _determine_location_type(lower_desc)
	params["location_type"] = location_info["type"]
	params["generator"] = location_info["generator"]
	
	if params["location_type"] == "city":
		params["size"] = 48
		params["width"] = 48
		params["height"] = 48
	
	var name_match = _extract_name(description)
	if name_match:
		params["location_name"] = name_match
	
	# 3. Парсим биом
	if "пещер" in lower_desc or "подземель" in lower_desc or "грот" in lower_desc:
		params["biome"] = "cave" if "пещер" in lower_desc else "dungeon"
	elif "лес" in lower_desc or "рощ" in lower_desc or "опушк" in lower_desc:
		params["biome"] = "forest"
	elif "гор" in lower_desc or "скал" in lower_desc:
		params["biome"] = "mountain"
	elif "таверн" in lower_desc or "трактир" in lower_desc or "бар" in lower_desc:
		params["biome"] = "dungeon"  # таверна — это помещение
	
	# 4. Парсим врагов
	var enemies_list = ["гоблин", "орк", "скелет", "паук", "крыса", "зомби", "охотник", "воин"]
	for enemy in enemies_list:
		if enemy in lower_desc:
			var count = _extract_number_before(lower_desc, enemy)
			params["enemies"].append({"type": enemy, "count": max(count, 1)})
	
	# 5. Парсим NPC
	var npc_list = ["крестьян", "торговец", "житель", "стражник", "трактирщик", "посетител"]
	for npc in npc_list:
		if npc in lower_desc:
			params["npcs"].append({"type": npc, "count": 1})
	
	# 6. Парсим выходы
	if "дверь" in lower_desc or "выход" in lower_desc or "проход" in lower_desc or "троп" in lower_desc:
		if params["location_type"] != "city":
			params["exits"].append({"x": 7, "y": 4, "description": "Тускло освещённый проход"})
	
	# 7. Объекты
	if "сундук" in lower_desc:
		params["objects"] = params.get("objects", [])
		params["objects"].append({"type": "chest", "count": 1})
	
	print("LocationParser: Извлечены параметры -> ", params)
	
	if params["exits"].is_empty() and params["location_type"] != "city":
		var size = params.get("size", 8)
		params["exits"].append({"x": size - 1, "y": size / 2, "description": "Тёмный проход"})
		print("LocationParser: Добавлен выход по умолчанию")
	
	return params
static func _determine_location_type(text: String) -> Dictionary:
	if "город" in text or "столиц" in text or "посел" in text or "деревн" in text:
		return {"type": "city", "generator": "city"}
	elif "таверн" in text or "трактир" in text or "пивн" in text or "бар" in text:
		return {"type": "tavern", "generator": "tavern"}
	elif "лагер" in text or "стоянк" in text or "привал" in text or "кост" in text:
		return {"type": "camp", "generator": "camp"}
	elif "дом" in text or "хижин" in text or "изб" in text or "комнат" in text:
		return {"type": "house", "generator": "house"}
	elif "лес" in text and ("опушк" in text or "полян" in text):
		return {"type": "forest_clearing", "generator": "forest_clearing"}
	else:
		return {"type": "default", "generator": "default"}

# Остальные вспомогательные функции без изменений...
static func _extract_name(text: String) -> String:
	var quote_start = text.find("\"")
	if quote_start != -1:
		var quote_end = text.find("\"", quote_start + 1)
		if quote_end != -1:
			return text.substr(quote_start + 1, quote_end - quote_start - 1)
	
	var sentences = text.split(".")
	if sentences.size() > 0:
		var first_sentence = sentences[0].strip_edges()
		if first_sentence.length() < 40:
			return first_sentence
	
	return "Неизвестная локация"

static func _extract_number_before(text: String, keyword: String) -> int:
	var keyword_pos = text.find(keyword)
	if keyword_pos == -1:
		return 1
	
	var num_str = ""
	for i in range(keyword_pos - 1, -1, -1):
		var c = text[i]
		if c.is_valid_int():
			num_str = c + num_str
		elif num_str != "":
			break
	
	if num_str != "":
		return num_str.to_int()
	return 1
