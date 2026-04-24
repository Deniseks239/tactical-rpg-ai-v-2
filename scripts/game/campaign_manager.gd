# scripts/game/campaign_manager.gd
extends Node
class_name CampaignManager

signal campaign_loaded(campaign_data: Dictionary)
signal campaign_error(error: String)
signal npc_dialogue_received(text: String)
signal quest_updated(quest_id: String, stage: int)

const SAVE_PATH = "user://campaign_state.json"

var ai_client: AIClientOllama
var campaign_data: Dictionary = {}
var current_dialogue_npc: Dictionary = {}

func _ready():
	# ai_client будет установлен из GameController
	pass

func initialize(p_ai_client: AIClientOllama):
	ai_client = p_ai_client
	ai_client.response_received.connect(_on_campaign_response)
	print("CampaignManager: инициализирован")

# === ГЕНЕРАЦИЯ СТРУКТУРЫ КАМПАНИИ ===

func request_campaign_structure(story_intro: String, character: CharacterData):
	print("CampaignManager: запрос структуры кампании...")
	
	var prompt = _build_campaign_prompt(story_intro, character)
	ai_client.model_name = "dnd-master-nothink"
	# Используем стандартный метод, но с типом "story" для длинного контекста
	ai_client.send_request(
		[{"role": "user", "content": prompt}],
		{}, 
		{}, 
		"story"
	)

func _build_campaign_prompt(story_intro: String, character: CharacterData) -> String:
	return """
Ты — Мастер Подземелий в RPG. На основе истории создай СТРУКТУРУ КАМПАНИИ в формате JSON.

История: %s

Герой: %s (уровень %d)

Создай JSON строго по шаблону:
{
  "campaign_name": "название кампании",
  "main_quest": {
    "title": "название главного квеста",
    "description": "краткое описание",
    "stages": [
      {"id": "stage_1", "description": "что нужно сделать", "location_hint": "где это может быть"},
      {"id": "stage_2", "description": "следующий этап", "location_hint": "где искать"}
    ]
  },
  "npcs": [
    {
      "id": "npc_1",
      "name": "имя NPC",
      "role": "торговец/трактирщик/стражник/маг",
      "personality": "характер (1-2 фразы)",
      "location": "где находится",
      "knowledge": ["что знает 1", "что знает 2"],
      "quests": [
        {
          "title": "название побочного квеста",
          "description": "что нужно сделать",
          "reward": "награда"
        }
      ]
    }
  ],
  "world_structure": {
    "starting_location": {
      "id": "loc_tavern",
      "name": "название стартовой локации",
      "description": "краткое описание для генерации",
      "biome": "tavern/forest/dungeon/cave"
    },
    "connected_locations": [
      {
        "id": "loc_cellar",
        "name": "название",
        "description": "описание",
        "biome": "dungeon",
        "connected_from": "loc_tavern",
        "connection_description": "дверь в подвал"
      }
    ]
  }
}

ВАЖНО:
- Сделай 2-3 связанные локации
- Добавь 2-3 NPC в стартовой локации
- Каждый NPC должен знать что-то о главном квесте
- Главный квест должен иметь 3-4 этапа
- ВСЕ тексты на русском языке
- Ответь ТОЛЬКО JSON'ом, без дополнительного текста
""" % [story_intro, character.character_name, 1]

# === ОБРАБОТКА ОТВЕТА ===

func _on_campaign_response(response: Dictionary):
	if response.get("type") != "text":
		return
	
	var text = response["data"]
	print("CampaignManager: получен ответ от ИИ (длина: ", text.length(), " символов)")
	
	# Пытаемся извлечь JSON
	var json_str = _extract_json(text)
	if json_str.is_empty():
		campaign_error.emit("Не удалось извлечь JSON из ответа ИИ")
		return
	
	var json = JSON.new()
	var parse_result = json.parse_string(json_str)
	
	if parse_result is Dictionary:
		campaign_data = parse_result
		_save_campaign()
		print("CampaignManager: кампания создана — ", campaign_data.get("campaign_name", "Без названия"))
		
		# Отключаем слушатель, чтобы не мешать другим запросам
		ai_client.response_received.disconnect(_on_campaign_response)
		
		campaign_loaded.emit(campaign_data)
	else:
		campaign_error.emit("JSON повреждён: " + json.get_error_message())

func _extract_json(text: String) -> String:
	# Ищем от ```json до ```
	var json_start = text.find("```json")
	if json_start != -1:
		json_start += 7
		var json_end = text.find("```", json_start)
		if json_end != -1:
			return text.substr(json_start, json_end - json_start).strip_edges()
	
	# Ищем от { до последнего }
	json_start = text.find("{")
	var json_end = text.rfind("}")
	if json_start != -1 and json_end != -1:
		return text.substr(json_start, json_end - json_start + 1)
	
	return ""

# === РАБОТА С ЛОКАЦИЯМИ ===

func get_location_info(location_id: String) -> Dictionary:
	if not campaign_data.has("world_structure"):
		return {}
	
	var world = campaign_data["world_structure"]
	
	# Проверяем стартовую локацию
	if world.get("starting_location", {}).get("id") == location_id:
		return world["starting_location"]
	
	# Проверяем связанные локации
	for loc in world.get("connected_locations", []):
		if loc.get("id") == location_id:
			return loc
	
	return {}

func get_next_locations(current_location_id: String) -> Array:
	"""Возвращает массив ID локаций, в которые можно попасть из текущей"""
	var result = []
	
	if not campaign_data.has("world_structure"):
		return result
	
	var world = campaign_data["world_structure"]
	
	# Если это стартовая локация, добавляем все connected_locations
	if world.get("starting_location", {}).get("id") == current_location_id:
		for loc in world.get("connected_locations", []):
			result.append(loc.get("id"))
	
	# Если это одна из connected_locations, можно вернуться в стартовую
	for loc in world.get("connected_locations", []):
		if loc.get("id") == current_location_id:
			result.append(world["starting_location"].get("id"))
			break
	
	return result

# === РАБОТА С NPC ===

func get_npc(npc_id: String) -> Dictionary:
	for npc in campaign_data.get("npcs", []):
		if npc.get("id") == npc_id:
			return npc
	return {}

func get_npcs_in_location(location_id: String) -> Array:
	var result = []
	for npc in campaign_data.get("npcs", []):
		if npc.get("location_id") == location_id or npc.get("location") == location_id:
			result.append(npc)
	return result

func get_npc_by_name(name: String) -> Variant:
	"""Возвращает ID NPC по имени (или null если не найден)"""
	for npc in campaign_data.get("npcs", []):
		if npc.get("name", "").to_lower().find(name.to_lower()) != -1:
			return npc.get("id")
	return null

# === ДИАЛОГИ С NPC ===

func request_npc_dialogue(npc_id: String, player_message: String):
	var npc = get_npc(npc_id)
	if npc.is_empty():
		campaign_error.emit("NPC не найден: " + npc_id)
		return
	
	current_dialogue_npc = npc
	
	var prompt = _build_dialogue_prompt(npc, player_message)
	ai_client.model_name = "dnd-master-nothink"
	
	# Подключаем временный обработчик для диалога
	ai_client.response_received.connect(_on_dialogue_response, CONNECT_ONE_SHOT)
	
	ai_client.send_request(
		[{"role": "user", "content": prompt}],
		{},
		{},
		"description"  # короткий контекст для быстрого ответа
	)

func _build_dialogue_prompt(npc: Dictionary, player_message: String) -> String:
	var main_quest = campaign_data.get("main_quest", {})
	
	return """
Ты отыгрываешь NPC в RPG. Следуй этим правилам:

ТВОЙ ПЕРСОНАЖ:
- Имя: %s
- Роль: %s
- Характер: %s
- Что знает: %s

КОНТЕКСТ КАМПАНИИ:
- Главный квест: %s
- Текущая локация: %s

Игрок говорит тебе: "%s"

Ответь ОТ ЛИЦА ПЕРСОНАЖА, учитывая его характер и знания. 
Если игрок спрашивает о том, что персонаж знает — поделись информацией.
Если спрашивает о квесте — предложи помощь (если это в характере).
Отвечай на русском, 1-3 предложения. Не используй JSON.
""" % [
		npc.get("name", "NPC"),
		npc.get("role", "житель"),
		npc.get("personality", "обычный"),
		str(npc.get("knowledge", ["ничего особенного"])),
		main_quest.get("title", "неизвестно"),
		npc.get("location", "здесь"),
		player_message
	]

func _on_dialogue_response(response: Dictionary):
	if response.get("type") == "text":
		var text = response["data"]
		npc_dialogue_received.emit(text)
		# Добавляем в историю AI-клиента
		ai_client.add_to_history("assistant", text)

# === СОХРАНЕНИЕ / ЗАГРУЗКА ===

func _save_campaign():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(campaign_data, "\t"))
		file.close()
		print("CampaignManager: кампания сохранена в ", SAVE_PATH)
	else:
		print("CampaignManager: ошибка сохранения кампании")

func load_campaign() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("CampaignManager: файл кампании не найден")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse_string(text)
		if parse_result is Dictionary:
			campaign_data = parse_result
			print("CampaignManager: кампания загружена — ", campaign_data.get("campaign_name", "Без названия"))
			return true
	
	print("CampaignManager: ошибка загрузки кампании")
	return false

func has_campaign() -> bool:
	return not campaign_data.is_empty()
