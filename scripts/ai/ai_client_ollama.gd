extends Node
class_name AIClientOllama

signal response_received(response: Dictionary)
signal error_occurred(error: String)

const API_URL = "http://localhost:11434/api/chat"
var model_name: String = "gemma4:e2b"
var current_request: HTTPRequest = null
var PromptTemplates = preload("res://scripts/ai/prompt_templates.gd")
var conversation_history: Array = []
var max_history: int = 10  # Храним последние 10 сообщений
var DNDRules = preload("res://data/dnd_rules/dnd_rules.gd")
# Инструменты для function calling
var tools = [
	{
		"type": "function",
		"function": {
			"name": "attack_enemy",
			"description": "Атаковать врага",
			"parameters": {
				"type": "object",
				"properties": {
					"enemy_name": {"type": "string", "description": "Имя врага"},
					"damage": {"type": "integer", "description": "Нанесённый урон"}
				},
				"required": ["enemy_name"]
			}
		}
	},
	{
		"type": "function",
		"function": {
			"name": "move_player",
			"description": "Переместить игрока",
			"parameters": {
				"type": "object",
				"properties": {
					"direction": {"type": "string", "description": "Направление: север, юг, запад, восток"},
					"steps": {"type": "integer", "description": "Количество шагов"}
				},
				"required": ["direction"]
			}
		}
	}
]

func send_request(messages: Array, game_context: Dictionary, additional_context: Dictionary = {}, request_type: String = "default"):
	cancel_current_request()
	var full_messages = conversation_history.duplicate()
	full_messages += messages
	
	var system_prompt = _build_system_prompt(game_context, additional_context, request_type)
	var ollama_messages = [{"role": "system", "content": system_prompt}] + conversation_history + messages
	
	current_request = HTTPRequest.new()
	add_child(current_request)
	current_request.request_completed.connect(_on_request_completed.bind(current_request))
	
	# ===== ВСЕ ПАРАМЕТРЫ ОПРЕДЕЛЯЕМ ЗДЕСЬ =====
	var num_predict = 100
	var ctx_size = 1024
	var temperature = 0.7
	
	if request_type == "location":
		num_predict = 6000
		ctx_size = 2048
	elif request_type == "location_text":
		num_predict = 200
		ctx_size = 2048
	elif request_type == "description":
		num_predict = 50
		ctx_size = 512
		temperature = 0.3
	elif request_type == "death":
		num_predict = 50
		ctx_size = 512
		temperature = 0.3
	elif request_type == "battle_summary":
		num_predict = 150
		ctx_size = 1024
	# =========================================
	
	var body = {
		"model": model_name,
		"messages": ollama_messages,
		"stream": false,
		"options": {
			"flash_attention": true,
			"temperature": temperature,
			"num_predict": num_predict,
			"num_ctx": ctx_size,
			"num_gpu": 999,
			"enable_thinking": false
		}
	}

	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	current_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_body)

func _build_system_prompt(context: Dictionary, additional: Dictionary, request_type: String) -> String:
	# Для текстовой генерации локации (простое описание)
	if request_type == "location_text":
		return "Ты — мастер подземелий. Опиши локацию для RPG игры. Используй 2-4 предложения. Не используй JSON. Просто опиши, что видит игрок: какие враги, какие выходы, какие особенности."
	
	# Для описаний атак
	if request_type == "description":
		var is_hit = additional.get("is_hit", false)
		var damage = additional.get("damage", 0)
		var attacker = additional.get("attacker", "")
		var defender = additional.get("defender", "")
		
		if is_hit:
			if damage <= 0:
				return "Опиши одной короткой фразой: " + attacker + " атакует, но не наносит урона. Максимум 10 слов."
			else:
				var severity = "лёгкий"
				if damage >= 6:
					severity = "тяжёлый"
				elif damage >= 4:
					severity = "средний"
				return "Опиши одной короткой фразой: " + attacker + " наносит " + str(damage) + " урона (" + severity + "). Максимум 12 слов."
		else:
			return "Опиши одной короткой фразой: " + attacker + " промахивается. Максимум 10 слов."
	
	# Для суммарного описания хода
	if request_type == "battle_summary":
		var events = additional.get("events", [])
		var player_name = additional.get("player_name", "Игрок")
		return PromptTemplates.get_battle_summary_prompt(events, player_name)
	
	# Для описания смерти
	if request_type == "death":
		var defender = additional.get("defender", "враг")
		return "Опиши одной фразой смерть " + defender + ". Максимум 15 слов."
	
	# Для генерации локации через JSON (старый способ, оставляем для совместимости)
	if request_type == "location":
		return PromptTemplates.get_location_prompt()
	
	# Для теста инструментов
	if request_type == "test_tools":
		return """
	Ты — помощник в RPG игре. Игрок пишет действие. Твоя задача — определить команду и цель.
	
	Отвечай ТОЛЬКО в формате:
	[команда:цель:параметр]
	
	Примеры:
	- "Атакую гоблина" → [attack:гоблин:0]
	- "Бегу на север" → [move:север:1]
	- "Осматриваю комнату" → [examine:комната:0]
	
	Сейчас игрок написал: """ + additional.get("input", "")
	
	# Значение по умолчанию
	return "Ты — мастер подземелий. Отвечай кратко."

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	if response_code != 200:
		error_occurred.emit("HTTP Error: " + str(response_code))
		return
	
	var response_text = body.get_string_from_utf8()
	print("Ответ Ollama получен (длина: ", response_text.length(), " символов)")
	print("Первые 1000 символов ответа:\n", response_text.substr(0, 1000))
	
	var json = JSON.new()
	var response = json.parse_string(response_text)
	if not response or not response.has("message"):
		error_occurred.emit("Invalid response format")
		return
	
	# Проверяем, есть ли tool_calls в ответе
	if response["message"].has("tool_calls"):
		print("AI вызвал инструменты!")
		var tool_calls = response["message"]["tool_calls"]
		response_received.emit({"type": "tool_calls", "data": tool_calls})
		return
	
	var content = response["message"].get("content", "")
	content = content.strip_edges()
	
	# Удаляем markdown обрамление
	if content.begins_with("```json"):
		content = content.substr(7)
	elif content.begins_with("```"):
		content = content.substr(3)
	
	if content.ends_with("```"):
		content = content.substr(0, content.length() - 3)
	content = content.strip_edges()
	
	# Исправляем двойные фигурные скобки
	if content.begins_with("{{") and content.ends_with("}}"):
		content = content.substr(1, content.length() - 2)
	
	print("Контент после очистки (первые 500 символов):\n", content.substr(0, 500))
	# Если ответ начинается не с { или [, не пытаемся парсить JSON
	if not content.begins_with("{") and not content.begins_with("["):
		print("Обычный текст, не JSON")
		response_received.emit({"type": "text", "data": content})
		return
	# ===== НОВАЯ ПРОВЕРКА: структурированная команда =====
	# Проверяем, не является ли ответ командой в формате [команда:цель:число]
	if content.begins_with("[") and content.ends_with("]"):
		print("Обнаружена команда в структурированном формате")
		response_received.emit({"type": "text", "data": content})
		return
	# ===================================================
	
	# Пробуем распарсить JSON
	var parsed = JSON.parse_string(content)
	
	if parsed is Array:
		print("Успешно распарсено как массив: ", parsed.size(), " действий")
		response_received.emit({"type": "actions", "data": parsed})
	elif parsed is Dictionary:
		print("Успешно распарсено как словарь")
		response_received.emit({"type": "text", "data": content})
	else:
		print("Не удалось распарсить JSON, передаём как текст")
		response_received.emit({"type": "text", "data": content})

func _fix_incomplete_json(content: String) -> String:
	var result = content
	var brackets = 0
	var braces = 0
	var in_string = false
	var escape = false
	
	for i in range(content.length()):
		var c = content[i]
		if escape:
			escape = false
			continue
		if c == '\\':
			escape = true
			continue
		if c == '"' and not escape:
			in_string = !in_string
			continue
		if not in_string:
			if c == '[':
				brackets += 1
			elif c == ']':
				brackets -= 1
			elif c == '{':
				braces += 1
			elif c == '}':
				braces -= 1
	
	while brackets > 0:
		result += "]"
		brackets -= 1
	while braces > 0:
		result += "}"
		braces -= 1
	
	var last_quote = content.rfind('"')
	if last_quote != -1 and last_quote == content.length() - 1:
		result += '"'
	
	if result != content:
		print("JSON восстановлен: добавлено закрывающих скобок")
	
	return result

func cancel_current_request():
	if current_request and current_request.is_inside_tree():
		current_request.cancel_request()
		current_request.queue_free()
		current_request = null
func add_to_history(role: String, content: String):
	conversation_history.append({"role": role, "content": content})
	if conversation_history.size() > max_history:
		conversation_history.pop_front()

func clear_history():
	conversation_history.clear()
