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
