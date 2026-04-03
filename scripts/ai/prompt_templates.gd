static func get_location_prompt() -> String:
	return """Верни ТОЛЬКО JSON. Формат:
{"action": "generate_location", "parameters": {"location_name": "название", "description": "описание", "biome": "dungeon", "size": 8, "enemies": [{"type": "goblin", "count": 2}], "exits": [{"x": 1, "y": 1, "description": "Дверь"}], "player_start": [4, 4]}}
Важно: exits должен быть массивом словарей с полями x, y и description. Не используй ["north"].
Создай простую локацию. Размер 8x8. Используй не более 2 типов врагов."""
