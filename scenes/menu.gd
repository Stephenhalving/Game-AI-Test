extends Control

func _ready() -> void:
	# Resetear progreso al entrar al menú
	var lm := get_node_or_null("/root/LevelManagerAuto")
	if lm and lm.has_method("reset"):
		lm.reset()

func _on_StartBtn_pressed() -> void:
	print("▶️ START GAME")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
