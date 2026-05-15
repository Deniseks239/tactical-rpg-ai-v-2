# scripts/ai/prompt_templates.gd
extends Node
class_name PromptTemplates

static func get_start_location_prompt() -> String:
	return """
Ты — мастер подземелий. Опиши первую локацию для начала приключения.
Это может быть таверна, лесная опушка, деревенский дом или пещера.
Опиши её в 2-3 предложениях.
Упомяни, что там есть: например, каких врагов или NPC, и есть ли выход.
Не используй JSON, просто текст.
"""

static func get_location_prompt_with_context(context: String) -> String:
	return """
Ты — мастер подземелий в настольной ролевой игре.
Опиши локацию, в которой оказался персонаж, учитывая контекст.

Контекст: %s

Опиши локацию в 2-4 предложениях на русском языке. Обязательно упомяни:
- Что это за место (таверна, пещера, лесной лагерь, дом и т.д.)
- Кто или что находится рядом (враги, NPC, предметы)
- Есть ли видимые выходы (двери, проходы, тропы)

Не используй JSON. Просто текст.
""" % context

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
static func get_campaign_structure_prompt(story_intro: String, character_name: String) -> String:
	return """
Ты — Мастер Подземелий в RPG. На основе истории создай СТРУКТУРУ КАМПАНИИ в формате JSON.

История: %s

Герой: %s (уровень 1)

Создай JSON строго по шаблону:
{
  "campaign_name": "название кампании",
  "main_quest": {
	"title": "название главного квеста",
	"description": "краткое описание (1-2 предложения)",
	"stages": [
      {
		"id": "stage_1",
		"description": "что нужно сделать на этом этапе",
		"location_hint": "пример места, где это может произойти (пещера, таверна, лес, подвал)",
		"steps": [
		  { "action": "что сделать", "location_hint": "где" },
		  { "action": "что сделать дальше", "location_hint": "где" }
        ]
      }
    ]
  },
  "npcs": [
    {
	  "id": "npc_1",
	  "name": "имя NPC",
	  "role": "торговец/трактирщик/стражник/маг",
	  "personality": "характер (1-2 фразы)",
	  "location": "где находится (стартовая локация или город)",
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
	  "id": "loc_start",
	  "name": "название стартовой локации",
	  "description": "краткое описание для генерации карты",
	  "biome": "tavern/forest/dungeon/cave/town"
    }
  }
}

ВАЖНО:
- Не создавай connected_locations — они будут генерироваться динамически по ходу игры.
- Каждый этап (stage) должен содержать 2-3 шага (steps). Это обеспечит прохождение через несколько локаций.
- Сделай 2-3 этапа главного квеста. Общее количество шагов — 6-9, что гарантирует длительную игру.
- Добавь 2-3 NPC в стартовой локации. Если стартовая локация — город, NPC могут быть в таверне, у ворот, на площади.
- Каждый NPC должен знать что-то о главном квесте или предлагать побочный квест.
- ВСЕ тексты на русском языке.
- Ответь ТОЛЬКО JSON'ом, без дополнительного текста.
""" % [story_intro, character_name]
static func get_story_intro_prompt(characters: Array) -> String:
	var chars_desc = ""
	for char in characters:
		chars_desc += "- %s (%s %s)\n" % [char.character_name, char.race, char.class_type]
	
	return """
Ты — Мастер Подземелий. Придумай начало приключения для героев.

Персонажи:
%s

Твоя задача — написать **один** текст из 3-5 предложений, который будет одновременно и завязкой сюжета, и описанием первой локации.

В этом тексте обязательно должны быть:
- Где находятся герои и что это за место (пещера, таверна, лес, дом).
- Какая опасность или загадка их ждёт (враги, ловушки, странные явления).
- Есть ли выход из этого места (дверь, тропа, портал).

Пиши сразу текст, без разделителей и заголовков.
""" % chars_desc
static func get_generic_npc_prompt(npc_name: String, npc_gender: String, location_description: String, player_name: String, player_message: String) -> String:
	return """Ты — NPC %s (%s). Локация: %s.
Игрок %s обратился к тебе.
Ответь одной короткой репликой на русском (1-2 предложения) от лица персонажа.
Не пиши "Thinking Process" или "Drafting". Сразу напиши готовую реплику.""" % [npc_name, npc_gender, location_description, player_name]

static func get_generic_npc_prompt_with_memory(npc_name: String, npc_gender: String, location_description: String, player_name: String, history_text: String, player_message: String, npc_type: String = "commoner") -> String:
	var type_info = CharacterClasses.get_npc_type_info(npc_type)
	var base = """Ты — NPC %s (%s, %s). Локация: %s.
Игрок %s сказал: "%s".
""" % [npc_name, npc_gender, type_info["personality"], location_description, player_name, player_message]
	if history_text != "":
		base += "\nПредыдущие реплики:\n" + history_text + "\n"
	base += "Твои знания: " + str(type_info["knowledge"]) + ". Если спросят о другом, вежливо откажись отвечать.\n"
	base += "Ответь коротко (1-2 предложения) на русском от лица персонажа."
	return base

static func get_generic_npc_prompt_with_type(npc_name: String, npc_gender: String, location_description: String, player_name: String, history_text: String, player_message: String, personality: String, knowledge: String) -> String:
	var base = """Ты — NPC %s (%s). Локация: %s. Твой характер: %s.
Твои знания: %s. Если спросят о чём-то другом, вежливо скажи, что не знаешь.
Игрок %s обратился к тебе: "%s".
""" % [npc_name, npc_gender, location_description, personality, knowledge, player_name, player_message]
	if history_text != "":
		base += "\nПредыдущие реплики:\n" + history_text + "\n"
	base += "Ответь коротко (1-2 предложения) на русском от лица персонажа."
	return base
