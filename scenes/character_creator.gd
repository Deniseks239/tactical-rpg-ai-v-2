# character_data.gd (ресурс)
extends Resource
class_name CharacterData

@export var name: String
@export var class_type: String  # воин, маг, лучник
@export var race: String  # человек, эльф, гном
@export var hp: int = 20
@export var max_hp: int = 20
@export var ac: int = 15
@export var attack_bonus: int = 5
@export var inventory: Array[String] = []
@export var description: String  # для AI
