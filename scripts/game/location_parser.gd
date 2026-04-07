# scripts/game/location_parser.gd
extends Node
class_name LocationParser

# Главная функция, которую будет вызывать LocationManager
static func parse_location_description(description: String) -> Dictionary:
	var params = {
		"location_name": "Неизвестная локация",
		"biome": "dungeon",
		"size": 8,
		"enemies": [],
		"npcs": [],
		"exits": [],
		"player_start": [4, 4],
		"description": description # Сохраняем и оригинальный текст для истории
	}
	
	var lower_desc = description.to_lower()
	
	# 1. Парсим название (первое предложение или фраза "Это ...")
	var name_match = _extract_name(description)
	if name_match:
		params["location_name"] = name_match
	
	# 2. Парсим биом (ландшафт)
	if "пещер" in lower_desc or "подземель" in lower_desc or "грот" in lower_desc:
		params["biome"] = "cave" if "пещер" in lower_desc else "dungeon"
	elif "лес" in lower_desc or "рощ" in lower_desc:
		params["biome"] = "forest"
	elif "гор" in lower_desc or "скал" in lower_desc:
		params["biome"] = "mountain"
	
	# 3. Парсим врагов
	var enemies_list = ["гоблин", "орк", "скелет", "паук", "крыса", "зомби"]
	for enemy in enemies_list:
		if enemy in lower_desc:
			# Определяем количество (можно улучшить для поиска чисел)
			var count = _extract_number_before(lower_desc, enemy)
			params["enemies"].append({"type": enemy, "count": max(count, 1)})
	
	# 4. Парсим NPC (мирных жителей)
	var npc_list = ["крестьян", "торговец", "житель", "стражник"]
	for npc in npc_list:
		if npc in lower_desc:
			params["npcs"].append({"type": npc, "count": 1})
	
	# 5. Парсим выходы (двери)
	if "дверь" in lower_desc or "выход" in lower_desc or "проход" in lower_desc:
		# Добавим стандартный выход, если не указано иное
		params["exits"].append({"x": 7, "y": 4, "description": "Тускло освещённый проход"})
	
	# 6. Парсим особенности (можно расширять)
	if "сундук" in lower_desc:
		params["objects"] = params.get("objects", [])
		params["objects"].append({"type": "chest", "count": 1})
	
	if "колодец" in lower_desc:
		params["features"] = params.get("features", [])
		params["features"].append({"type": "water", "radius": 1})
	
	# ВАЖНО: Логируем результат, чтобы видеть, что напарсили
	print("LocationParser: Извлечены параметры -> ", params)
	return params

# Вспомогательные функции-парсеры

static func _extract_name(text: String) -> String:
	# Пытаемся найти текст между кавычками, если есть
	var quote_start = text.find("\"")
	if quote_start != -1:
		var quote_end = text.find("\"", quote_start + 1)
		if quote_end != -1:
			return text.substr(quote_start + 1, quote_end - quote_start - 1)
	
	# Иначе пробуем взять первое предложение как название
	var sentences = text.split(".")
	if sentences.size() > 0:
		var first_sentence = sentences[0].strip_edges()
		if first_sentence.length() < 40:
			return first_sentence
	
	return "Неизвестная локация"

static func _extract_number_before(text: String, keyword: String) -> int:
	# Ищем число перед ключевым словом
	var keyword_pos = text.find(keyword)
	if keyword_pos == -1:
		return 1
	
	# Ищем цифры перед позицией ключевого слова
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
