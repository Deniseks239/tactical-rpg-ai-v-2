# scripts/ui/dialog_window.gd
extends Control

@onready var history_label: RichTextLabel = $Panel/HistoryLabel
@onready var input_field: LineEdit = $Panel/InputField
@onready var send_button: Button = $Panel/SendButton

var npc_name: String = ""
var npc_id: String = ""
var game_controller: GameController

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_send_pressed)
	game_controller = get_node("/root/GameControllerAuto")

func setup(n_name: String, n_id: String):
	npc_name = n_name
	npc_id = n_id
	history_label.clear()
	history_label.append_text("[color=yellow]Вы обращаетесь к %s[/color]\n" % npc_name)
	input_field.grab_focus()

func _on_send_pressed(text: String = ""):
	var message = text if text != "" else input_field.text
	if message.strip_edges().is_empty():
		return
	
	# Показываем реплику игрока
	history_label.append_text("[color=cyan]Вы:[/color] %s\n" % message)
	input_field.clear()
	
	# Отправляем NPC
	var campaign_mgr = get_node_or_null("/root/CampaignManagerAuto")
	var grid_mgr = get_node_or_null("/root/GridManager")  # нужно будет найти
	if campaign_mgr and npc_id != "":
		campaign_mgr.npc_dialogue_received.connect(_on_npc_response, CONNECT_ONE_SHOT)
		campaign_mgr.request_npc_dialogue(npc_id, message)
	elif grid_mgr:
		# Для обычных жителей
		grid_mgr._send_dialogue_message(message, npc_name)

func _on_npc_response(text: String):
	history_label.append_text("[color=green]%s:[/color] %s\n" % [npc_name, text])
