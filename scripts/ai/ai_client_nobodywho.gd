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
	# Ищем модель и чаты из автозагрузки AIManagerAuto
	var aimgr = get_node_or_null("/root/AIManagerAuto")
	
	if aimgr:
		# Берём существующие узлы из сцены
		master_chat = aimgr.get_node_or_null("MasterChat")
		npc_chat = aimgr.get_node_or_null("NPCChat")
		battle_chat = aimgr.get_node_or_null("BattleChat")
		
		if master_chat:
			master_chat.response_finished.connect(_on_master_response)
		if npc_chat:
			npc_chat.response_finished.connect(_on_npc_response)
		if battle_chat:
			battle_chat.response_finished.connect(_on_battle_response)
		
		print("AIClientNobodyWho: использованы чаты из AIManagerAuto")
	else:
		print("AIClientNobodyWho: AIManagerAuto не найден!")

func send_request(messages: Array, game_context: Dictionary, additional_context: Dictionary = {}, request_type: String = "default"):
	print("AIClientNobodyWho: send_request вызван с типом ", request_type)
	
	# Извлекаем текст из messages
	var user_text = ""
	for msg in messages:
		if msg.get("role") == "user":
			user_text += msg.get("content", "") + "\n"
	user_text = user_text.strip_edges()
	
	if user_text.is_empty():
		user_text = "Продолжай."
	
	print("AIClientNobodyWho: текст запроса (первые 200 символов): ", user_text.substr(0, min(200, user_text.length())))
	
	# Выбираем чат по типу запроса
	var chat: NobodyWhoChat
	
	match request_type:
		"story", "location", "location_text":
			chat = master_chat
		"description", "death", "battle_summary":
			chat = battle_chat
		"dialogue", "npc":
			chat = npc_chat
		_:
			chat = master_chat
	
	if not chat:
		print("AIClientNobodyWho: ОШИБКА — чат не инициализирован!")
		error_occurred.emit("Чат не инициализирован")
		return
	
	print("AIClientNobodyWho: выбран чат ", chat.name, ", отправляю запрос...")
	
	# Отправляем сообщение
		# Отправляем сообщение
	chat.say(user_text)
	print("AIClientNobodyWho: запрос отправлен успешно, ожидаю ответ...")
	
	# Сохраняем контекст для обработчика ответа
	chat.set_meta("pending_request_type", request_type)
	chat.set_meta("pending_context", additional_context)

func _on_master_response(response_text: String):
	_process_response(response_text, master_chat, "master")

func _on_npc_response(response_text: String):
	_process_response(response_text, npc_chat, "npc")

func _on_battle_response(response_text: String):
	_process_response(response_text, battle_chat, "battle")

func _process_response(response_text: String, chat: NobodyWhoChat, chat_type: String):
	if response_text.is_empty():
		print("AIClientNobodyWho: ПУСТОЙ ОТВЕТ от ", chat_type, " чата!")
		error_occurred.emit("Пустой ответ от модели")
		return
	
	print("AIClientNobodyWho: ответ от ", chat_type, " чата (длина: ", response_text.length(), " символов)")
	print("Первые 300 символов: ", response_text.substr(0, min(300, response_text.length())))
	
	# Очищаем markdown и форматирование
	var content = _clean_response(response_text)
	
	# Определяем тип ответа
	if content.begins_with("{") or content.begins_with("["):
		var parsed = JSON.parse_string(content)
		if parsed is Array:
			response_received.emit({"type": "actions", "data": parsed})
			return
		elif parsed is Dictionary:
			response_received.emit({"type": "text", "data": content})
			return
		else:
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
