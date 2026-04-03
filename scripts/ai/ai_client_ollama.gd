extends Node
class_name AIClientOllama

signal response_received(response: Dictionary)
signal error_occurred(error: String)

const API_URL = "http://localhost:11434/api/chat"
var model_name: String = "gemma3:4b"

func send_request(messages: Array, game_context: Dictionary, additional_context: Dictionary = {}, request_type: String = "default"):
	cancel_current_request()  # Отменяем предыдущий запрос
	current_request = HTTPRequest.new()
	add_child(current_request)
	current_request.request_completed.connect(_on_request_completed.bind(current_request))
	var system_prompt = _build_system_prompt(game_context, additional_context, request_type)
	var ollama_messages = [{"role": "system", "content": system_prompt}] + messages
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed.bind(http))
	
	var num_predict = 200  # очень короткие описания
	if request_type == "location":
		num_predict = 6000
	elif request_type == "death":
		num_predict = 100
	
	var body = {
		"model": model_name,
		"messages": ollama_messages,
		"stream": false,
		"options": {
			"temperature": 0.7,
			"num_predict": num_predict
		}
	}
	
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	http.request(API_URL, headers, HTTPClient.METHOD_POST, json_body)

func _build_system_prompt(context: Dictionary, additional: Dictionary, request_type: String) -> String:
	if request_type == "description":
		# Переменные нужно брать из additional, а не из context
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
	
	elif request_type == "death":
		var defender = additional.get("defender", "враг")
		return "Опиши одной фразой смерть " + defender + ". Максимум 15 слов."
	
	elif request_type == "location"::
		return PromptTemplates.get_location_prompt()
		# Длинный промпт для генерации локации
		var grid_str = ""
		var grid = context.get("grid", [])
		for row in grid:
			for cell in row:
				grid_str += str(cell) + " "
			grid_str += "\n"
	
		var base = "Ты — мастер подземелий. Создай параметры для локации в формате JSON.\n"
		base += "Верни ТОЛЬКО JSON. БЕЗ лишнего текста.\n"
		base += "Формат: {\"action\": \"generate_location\", \"parameters\": {...}}\n"
		base += "Будь краток. Не используй много врагов. 2-3 типа врагов максимум.\n"
		base += additional.get("instruction", "")
		return base
	
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
	
	# Добавляем недостающие закрывающие скобки
	while brackets > 0:
		result += "]"
		brackets -= 1
	while braces > 0:
		result += "}"
		braces -= 1
	
	# Проверяем, не обрезана ли строка
	var last_quote = content.rfind('"')
	if last_quote != -1 and last_quote == content.length() - 1:
		# Если строка обрезана, закрываем её
		result += '"'
	
	if result != content:
		print("JSON восстановлен: добавлено закрывающих скобок")
	
	return result
var current_request: HTTPRequest = null

func cancel_current_request():
	if current_request and current_request.is_inside_tree():
		current_request.cancel_request()
		current_request.queue_free()
		current_request = null
