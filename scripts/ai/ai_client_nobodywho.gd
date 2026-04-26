# scripts/ai/ai_client_nobodywho.gd
extends Node
class_name AIClientNobodyWho

signal response_received(response: Dictionary)
signal error_occurred(error: String)

# Три параллельных чата (подключаются из сцены или создаются в _ready)
var master_chat: NobodyWhoChat   # Генерация кампании, структура мира
var npc_chat: NobodyWhoChat      # Диалоги с NPC
var battle_chat: NobodyWhoChat   # Описания боя, атак, смертей

var model_name: String = "game_master"  # Имя файла модели без .gguf
var PromptTemplates = preload("res://scripts/ai/prompt_templates.gd")

# Системные промпты для каждого чата
const SYSTEM_PROMPT_MASTER = """Ты — Мастер Подземелий в тактической RPG. 
Твоя задача: создавать описания локаций, генерировать структуру кампании, 
управлять миром. Отвечай кратко, на русском языке. 
Для структуры кампании используй строгий JSON."""

const SYSTEM_PROMPT_NPC = """Ты — NPC в RPG. Отвечай от лица своего персонажа, 
учитывая его характер и знания. Отвечай кратко, 1-3 предложения, на русском. 
Не используй JSON, не описывай действия от третьего лица."""

const SYSTEM_PROMPT_BATTLE = """Ты описываешь боевые действия в RPG. 
Описывай атаки, попадания, промахи, смерти — одной фразой на русском. 
Будь эпичен и краток. Не используй JSON."""

func _ready():
	# Пытаемся найти модель и чаты в сцене
	var model = get_node_or_null("NobodyWhoModel")
	if not model:
		print("AIClientNobodyWho: NobodyWhoModel не найден — создаю")
		model = NobodyWhoModel.new()
		model.name = "NobodyWhoModel"
		add_child(model)
	
	# В NobodyWho путь к модели задаётся через свойство model_path или file_path
	# Пробуем разные варианты имени свойства
	if model.has_method("set_model_file"):
		model.model_file = "res://models/" + model_name + ".gguf"
	elif "model_path" in model:
		model.model_path = "res://models/" + model_name + ".gguf"
	elif "file_path" in model:
		model.file_path = "res://models/" + model_name + ".gguf"
	else:
		# Если ничего не подошло — путь уже задан в инспекторе
		print("AIClientNobodyWho: путь к модели не задан программно, проверьте инспектор")
	
	# Создаём три чата, подключенные к одной модели
	_setup_chat("MasterChat", model, SYSTEM_PROMPT_MASTER)
	_setup_chat("NPCChat", model, SYSTEM_PROMPT_NPC)
	_setup_chat("BattleChat", model, SYSTEM_PROMPT_BATTLE)
	
	print("AIClientNobodyWho: модель и 3 чата готовы")

func _setup_chat(chat_name: String, model: NobodyWhoModel, system_prompt: String):
	var chat = get_node_or_null(chat_name)
	if not chat:
		chat = NobodyWhoChat.new()
		chat.name = chat_name
		# Связь с моделью настроим в редакторе
		add_child(chat)
	
	chat.system_prompt = system_prompt
	
	match chat_name:
		"MasterChat":
			master_chat = chat
			master_chat.response_finished.connect(_on_master_response)
		"NPCChat":
			npc_chat = chat
			npc_chat.response_finished.connect(_on_npc_response)
		"BattleChat":
			battle_chat = chat
			battle_chat.response_finished.connect(_on_battle_response)

func send_request(messages: Array, game_context: Dictionary, additional_context: Dictionary = {}, request_type: String = "default"):
	print("AIClientNobodyWho: send_request вызван с типом ", request_type)
	
	# Извлекаем текст из messages (для совместимости с текущим game_controller)
	var user_text = ""
	for msg in messages:
		if msg.get("role") == "user":
			user_text += msg.get("content", "") + "\n"
	user_text = user_text.strip_edges()
	
	if user_text.is_empty():
		user_text = "Продолжай."
	
	# Выбираем чат и настройки по типу запроса
	var chat: NobodyWhoChat
	var max_tokens = 100
	var temperature = 0.7
	
	match request_type:
		"story", "location":
			chat = master_chat
			max_tokens = 2000
			temperature = 0.3
		"location_text":
			chat = master_chat
			max_tokens = 400
			temperature = 0.7
		"description", "death", "battle_summary":
			chat = battle_chat
			max_tokens = 150
			temperature = 0.7
		"dialogue", "npc":
			chat = npc_chat
			max_tokens = 200
			temperature = 0.8
		_:
			chat = master_chat
			max_tokens = 200
	
	if not chat:
		error_occurred.emit("Чат не инициализирован")
		return
	
	# Отправляем сообщение в выбранный чат
	chat.max_tokens = max_tokens
	chat.temperature = temperature
	chat.send_message(user_text)
	
	# Сохраняем контекст для обработчика ответа
	chat.set_meta("pending_request_type", request_type)
	chat.set_meta("pending_context", additional_context)

# === ОБРАБОТЧИКИ ОТВЕТОВ (эмитируют сигнал response_received) ===

func _on_master_response(response_text: String):
	_process_response(response_text, master_chat, "master")

func _on_npc_response(response_text: String):
	_process_response(response_text, npc_chat, "npc")

func _on_battle_response(response_text: String):
	_process_response(response_text, battle_chat, "battle")

func _process_response(response_text: String, chat: NobodyWhoChat, chat_type: String):
	print("AIClientNobodyWho: ответ от ", chat_type, " чата (длина: ", response_text.length(), " символов)")
	
	# Очищаем markdown и форматирование
	var content = _clean_response(response_text)
	
	# Определяем тип ответа
	if content.begins_with("{") or content.begins_with("["):
		# Пробуем JSON
		var parsed = JSON.parse_string(content)
		if parsed is Array:
			response_received.emit({"type": "actions", "data": parsed})
			return
		elif parsed is Dictionary:
			response_received.emit({"type": "text", "data": content})
			return
		else:
			# Невалидный JSON — передаём как текст
			response_received.emit({"type": "text", "data": content})
			return
	
	# Обычный текст
	response_received.emit({"type": "text", "data": content})

func _clean_response(text: String) -> String:
	var content = text.strip_edges()
	
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
	
	return content

# === ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ (для совместимости) ===

func add_to_history(role: String, content: String):
	# NobodyWho сам хранит историю — этот метод оставлен для совместимости
	pass

func clear_history():
	# Очищаем историю всех чатов
	if master_chat:
		master_chat.clear_history()
	if npc_chat:
		npc_chat.clear_history()
	if battle_chat:
		battle_chat.clear_history()

func cancel_current_request():
	# NobodyWho сам управляет запросами
	pass

# === МЕТОД ДЛЯ БЫСТРОЙ СМЕНЫ SYSTEM PROMPT (НУЖНО ДЛЯ NPC) ===

func set_npc_context(npc_name: String, npc_role: String, npc_knowledge: Array):
	if npc_chat:
		var prompt = "Ты — " + npc_name + ", " + npc_role + ". "
		prompt += "Ты знаешь: " + str(npc_knowledge) + ". "
		prompt += "Отвечай от лица персонажа, кратко, 1-3 предложения."
		npc_chat.system_prompt = prompt
