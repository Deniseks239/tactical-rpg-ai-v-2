# scripts/ui/dialog_window.gd
extends Control

@onready var history_label: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/HistoryLabel
@onready var input_field: LineEdit = $Panel/VBoxContainer/HBoxContainer/InputField
@onready var send_button: Button = $Panel/VBoxContainer/HBoxContainer/SendButton

var npc_name: String = ""
var npc_id: String = ""
var grid_manager = null

func _ready():
	send_button.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(_on_send_pressed)
	hide()  # скрыто до вызова setup

func setup(n_name: String, n_id: String, grid_mgr):
	npc_name = n_name
	npc_id = n_id
	grid_manager = grid_mgr
	history_label.clear()
	history_label.append_text("[color=yellow]Вы обращаетесь к %s[/color]\n" % npc_name)
	input_field.text = ""
	input_field.grab_focus()
	show()

func _on_send_pressed(text: String = ""):
	var message = text if text != "" else input_field.text
	if message.strip_edges().is_empty():
		return
	
	history_label.append_text("[color=cyan]Вы:[/color] %s\n" % message)
	input_field.clear()
	input_field.editable = false  # ждём ответа
	send_button.disabled = true
	
	if grid_manager:
		grid_manager.send_dialogue_message(message, npc_name)

func append_npc_response(text: String):
	history_label.append_text("[color=green]%s:[/color] %s\n" % [npc_name, text])
	# Снова разрешаем ввод
	input_field.editable = true
	send_button.disabled = false
	input_field.grab_focus()
