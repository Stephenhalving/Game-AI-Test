extends Node
class_name LevelManager

var current_level: int = 0
var last_score: int = 0
var has_car_key: bool = false

var level_scenes: Array[String] = [
    "res://scenes/Main.tscn",    # Stage 1 – Arena
    "res://scenes/Stage2.tscn",  # Stage 2 – Ciudad en Ruinas
    "res://scenes/Stage3.tscn",  # Stage 3 – La Casa del Poder
]

func reset() -> void:
    current_level = 0
    last_score = 0
    has_car_key = false

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
    print("🏁 GAME OVER score=", last_score)
    get_tree().paused = false
    Engine.time_scale = 1.0
    get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func win_game() -> void:
    print("🏆 WIN score=", last_score)
    get_tree().paused = false
    Engine.time_scale = 1.0
    get_tree().change_scene_to_file("res://scenes/WinScreen.tscn")



