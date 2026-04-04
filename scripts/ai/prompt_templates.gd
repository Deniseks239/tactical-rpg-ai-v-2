static func get_location_prompt() -> String:
	return """Верни ТОЛЬКО JSON. Формат:
{"action": "generate_location", "parameters": {"location_name": "название", "description": "описание", "biome": "dungeon", "size": 8, "enemies": [{"type": "goblin", "count": 2}], "exits": [{"x": 1, "y": 1, "description": "Дверь"}], "player_start": [4, 4]}}
Важно: exits должен быть массивом словарей с полями x, y и description. Не используй ["north"].
Создай простую локацию. Размер 8x8. Используй не более 2 типов врагов."""
static func get_battle_summary_prompt(events: Array, player_name: String) -> String:
	var prompt = player_name + " совершил несколько действий за ход:\n"
	for event in events:
		if event["type"] == "attack":
			if event["is_hit"]:
				prompt += "- Атаковал " + event["defender"] + ", нанеся " + str(event["damage"]) + " урона"
				if event["was_killed"]:
					prompt += " и убил его"
				prompt += "\n"
			else:
				prompt += "- Промахнулся по " + event["defender"] + "\n"
	
	prompt += "\nОпиши результаты этих действий одной эпичной фразой на русском языке. Не задавай вопросов. Просто опиши, что произошло."
	return prompt
		
