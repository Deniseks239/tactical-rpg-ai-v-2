# scripts/ai/ai_client_nobodywho.gd
extends Node
class_name AIClientNobodyWho

signal response_received(response: Dictionary)
signal error_occurred(error: String)

const API_URL = "http://127.0.0.1:8080/v1/chat/completions"
var model_name: String = "game_master"
var current_request: HTTPRequest = null
var conversation_history: Array = []
var max_history: int = 10

func _ready():
	print("AIClientLlamaServer: готов. Сервер: ", API_URL)

func send_request(messages: Array, game_context: Dictionary, additional_context: Dictionary = {}, request_type: String = "default"):
	print("AIClient: send_request вызван с типом ", request_type)
	cancel_current_request()
	
	var full_messages = _build_messages(messages, request_type)
	
	current_request = HTTPRequest.new()
	add_child(current_request)
	current_request.request_completed.connect(_on_request_completed.bind(current_request))
	
	# Настройки для разных типов запросов
	var max_tokens = 150
	var temperature = 0.7
	
	match request_type:
		"story":
			max_tokens = 2000
			temperature = 0.3
		"location_text":
			max_tokens = 400
			temperature = 0.7
		"description", "death":
			max_tokens = 100
			temperature = 0.7
		"battle_summary":
			max_tokens = 200
			temperature = 0.7
	
	var body = {
		"model": model_name,
		"messages": full_messages,
		"max_tokens": max_tokens,
		"temperature": temperature,
		"stream": false,
		"enable_thinking": false
	}
	
	var json_body = JSON.stringify(body)
	var headers = ["Content-Type: application/json"]
	var error = current_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		error_occurred.emit("HTTP Request failed: " + str(error))
		return
	
	print("AIClient: запрос отправлен к ", API_URL)

func _build_messages(messages: Array, request_type: String) -> Array:
	var system_prompt = ""
	
	match request_type:
		"story", "location_text", "location":
			system_prompt = "Ты — Мастер Подземелий в тактической RPG. Создавай описания локаций и сюжета. Отвечай на русском языке."
		"description", "death", "battle_summary":
			system_prompt = "Ты описываешь боевые действия в RPG. Отвечай одной эпичной фразой на русском."
		_:
			system_prompt = "Ты — Мастер Подземелий. Отвечай кратко на русском."
	
	var result = [{"role": "system", "content": system_prompt}]
	# Для боевых описаний не добавляем историю — только текущий запрос
	if request_type in ["battle_summary", "description", "death"]:
		result += messages
	else:
		result += conversation_history
		result += messages
	return result

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	print("AIClient: ЗАПРОС ЗАВЕРШЁН, response_code = ", response_code)
	http.queue_free()
	
	if response_code != 200:
		var response_text = body.get_string_from_utf8()
		print("AIClient: ОШИБКА ответа: ", response_text)
		error_occurred.emit("HTTP Error " + str(response_code) + ": " + response_text)
		return
	
	var response_text = body.get_string_from_utf8()
	print("AIClient: Ответ получен (длина: ", response_text.length(), " символов)")
	print("AIClient: Первые 300 символов ответа:\n", response_text.substr(0, min(300, response_text.length())))
	
	# Парсим ответ в формате OpenAI API
	var json = JSON.new()
	var response = json.parse_string(response_text)
	
	if not response or not response.has("choices"):
		error_occurred.emit("Invalid response format")
		return
	
	var content = response["choices"][0]["message"]["content"]
	
	# Удаляем markdown обрамление
	if content.begins_with("```json"):
		content = content.substr(7)
	elif content.begins_with("```"):
		content = content.substr(3)
	
	if content.ends_with("```"):
		content = content.substr(0, content.length() - 3)
	content = content.strip_edges()
	
	# Добавляем в историю
	add_to_history("assistant", content)
	
	print("AIClient: Контент после очистки (первые 300 символов):\n", content.substr(0, min(300, content.length())))
	
	# Определяем тип ответа
	var parsed = JSON.parse_string(content)
	if parsed == null:
		# JSON повреждён — пробуем исправить
		var fixed = _fix_incomplete_json(content)
		if fixed != content:
			print("AIClient: JSON повреждён, попытка исправления...")
			content = fixed
			parsed = JSON.parse_string(content)
	
	if parsed is Array:
		print("Успешно распарсено как массив: ", parsed.size(), " действий")
		response_received.emit({"type": "actions", "data": parsed})
	elif parsed is Dictionary:
		print("Успешно распарсено как словарь")
		response_received.emit({"type": "text", "data": content})
	else:
		print("Не удалось распарсить JSON, передаём как текст")
		response_received.emit({"type": "text", "data": content})

func add_to_history(role: String, content: String):
	conversation_history.append({"role": role, "content": content})
	if conversation_history.size() > max_history:
		conversation_history.pop_front()

func clear_history():
	conversation_history.clear()

func cancel_current_request():
	if current_request and current_request.is_inside_tree():
		current_request.cancel_request()
		current_request.queue_free()
		current_request = null

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
