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
