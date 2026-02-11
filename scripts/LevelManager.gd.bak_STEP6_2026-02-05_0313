extends Node
class_name LevelManager

var current_level: int = 0

# Por ahora, Level 1 y Level 2 apuntan al mismo Main.
var level_scenes: Array[String] = [
	"res://scenes/Main.tscn",
	"res://scenes/Main.tscn",
]

func reset() -> void:
	current_level = 0

func start_game() -> void:
	reset()
	goto_level(1)

func goto_level(level: int) -> void:
	current_level = level
	if current_level <= 0 or current_level > level_scenes.size():
		game_over()
		return

	var path := level_scenes[current_level - 1]
	print("➡️ LOADING LEVEL ", current_level, " -> ", path)
	get_tree().change_scene_to_file(path)

func next_level() -> void:
	goto_level(current_level + 1)

func game_over() -> void:
	print("🏁 GAME OVER / GAME COMPLETE")
	if ResourceLoader.exists("res://scenes/Menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	else:
		get_tree().quit()



