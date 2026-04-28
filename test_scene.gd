extends Node2D

func _ready():
	print("Жду 3 секунды для загрузки модели...")
	await get_tree().create_timer(3.0).timeout
	print("Отправляю запрос...")
	$NobodyWhoModel/TestChat.system_prompt = "Ты — тестовый бот. Ответь: ОК."
	$NobodyWhoModel/TestChat.response_finished.connect(func(text): print("ОТВЕТ: ", text); get_tree().quit())
	$NobodyWhoModel/TestChat.say("Скажи ОК")
